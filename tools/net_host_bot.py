"""Scripted network host for testing the game's guest path with a single instance.

Run the bot, then join 127.0.0.1 from the game with debug mode enabled:

    python tools/net_host_bot.py             # bot is Player 2
    python tools/net_host_bot.py --seat 1    # bot is Player 1

The game (as guest) simulates the whole match; the bot only runs the lobby,
sequences commands, and plays COMMAND_CYCLE on its own turns. It knows whose
turn it is from the debug_state summary the guest sends in debug mode.
"""

import argparse
import random
import socket
import sys
import time

from gm_net import (
    JOIN_PROTOCOL,
    MATCH_PROTOCOL,
    GameMakerConnection,
    command,
    describe_state,
    log,
)

# Sent in order, one per confirmed guest state, while the bot has priority.
COMMAND_CYCLE = [
    "containment_no_ship",
    "special_containment_no_ship",
    "advance_phase",
    "resolve_raid",
    "end_turn",
]

LEADERS = ["bsl_researcher", "adam_malkovich", "mother_brain", "quiet_robe", "raven_beak"]
SEAT_COUNT = 2


class Lobby:
    def __init__(self, name, leader, seat):
        self.participants = [{
            "participant_id": 0, "name": name, "seat": seat,
            "leader_id": leader, "ready": True, "host": True,
        }]

    def guest(self):
        return next((p for p in self.participants if not p["host"]), None)

    def add_guest(self, name, leader):
        taken = {p["seat"] for p in self.participants}
        open_seat = next((s for s in range(SEAT_COUNT) if s not in taken), -1)
        self.participants.append({
            "participant_id": 1, "name": name[:24] or "Spectator", "seat": open_seat,
            "leader_id": leader or "bsl_researcher", "ready": False, "host": False,
        })

    def apply(self, action, value):
        guest = self.guest()
        if action == "claim_seat":
            seat = int(value)
            if not 0 <= seat < SEAT_COUNT or any(
                p is not guest and p["seat"] == seat for p in self.participants
            ):
                return False
            guest["seat"], guest["ready"] = seat, False
        elif action == "spectate":
            guest["seat"], guest["ready"] = -1, False
        elif action == "toggle_ready":
            if guest["seat"] < 0:
                return False
            guest["ready"] = not guest["ready"]
        elif action == "set_leader":
            guest["leader_id"], guest["ready"] = str(value), False
        else:
            return False
        return True


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=6510)
    parser.add_argument("--name", default="HostBot")
    parser.add_argument("--leader", default="bsl_researcher", choices=LEADERS)
    parser.add_argument("--seat", type=int, choices=[1, 2], default=2, help="Player seat for the bot.")
    parser.add_argument("--seed", type=int, help="Match seed; random when omitted.")
    parser.add_argument("--breaching-mutation", action="store_true")
    parser.add_argument("--loaded-ships-exhausted", action="store_true")
    parser.add_argument("--delay", type=float, default=0.75, help="Seconds before each bot command.")
    parser.add_argument("--dump", action="store_true", help="Print raw received bytes.")
    args = parser.parse_args()

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", args.port))
    server.listen(1)
    log(f"Hosting on port {args.port}. Join 127.0.0.1 from the game (debug mode on).")
    client, address = server.accept()
    server.close()
    connection = GameMakerConnection(client, "server", args.dump)
    log(f"Game connected from {address[0]}.")

    bot_seat = args.seat - 1
    lobby = Lobby(args.name, args.leader, bot_seat)
    sequence = 0
    match_started_at = None
    state = None
    command_sent_for_sequence = -1
    stuck_logged = None
    cycle_index = 0
    next_command_at = 0.0

    def commit(packet):
        nonlocal sequence
        sequence += 1
        packet = dict(packet, type="command_commit", sequence=sequence)
        connection.send(packet)
        log(f"commit #{sequence}: {packet['input_type']} {packet['action'] or packet['kind']}")

    def broadcast_lobby():
        connection.send({"type": "lobby_state", "participants": lobby.participants})

    while True:
        for packet in connection.receive():
            kind = packet.get("type")
            if kind == "join_hello":
                if packet.get("protocol") != JOIN_PROTOCOL or match_started_at is not None:
                    connection.send({"type": "join_rejected", "reason": "Network protocol mismatch."})
                    return 1
                lobby.add_guest(str(packet.get("player_name", "")), packet.get("leader_id"))
                connection.send({
                    "type": "lobby_welcome", "participant_id": 1, "participants": lobby.participants,
                })
                broadcast_lobby()
                log(f"{lobby.guest()['name']} joined. Claim the open seat and ready up.")
            elif kind == "lobby_action" and match_started_at is None:
                if lobby.apply(packet.get("action"), packet.get("value", 0)):
                    broadcast_lobby()
                guest = lobby.guest()
                if guest["seat"] >= 0 and guest["seat"] != bot_seat and guest["ready"]:
                    seed = args.seed if args.seed is not None else random.randrange(2147483646)
                    connection.send({
                        "type": "start_match",
                        "protocol": MATCH_PROTOCOL,
                        "seed": seed,
                        "breaching_mutation": args.breaching_mutation,
                        "loaded_ships_exhausted": args.loaded_ships_exhausted,
                        "participants": lobby.participants,
                    })
                    match_started_at = time.monotonic()
                    log(f"Match started with seed {seed}; bot is Player {args.seat}.")
            elif kind == "command_request" and match_started_at is not None:
                guest_seat = lobby.guest()["seat"]
                if state is not None and state["priority_player"] != guest_seat:
                    log(f"Rejected guest {packet.get('action') or packet.get('kind')} outside priority.")
                    continue
                commit(packet)
            elif kind == "debug_state":
                state = packet
                log(f"state #{state['sequence']}: {describe_state(state)}")
            elif kind == "chat_message":
                log(f"chat: {packet.get('message')}")
            else:
                log(f"{kind}: {packet}")

        now = time.monotonic()
        if match_started_at is not None and state is None and now - match_started_at > 10:
            log("No debug_state from the game yet; enable debug mode in the game's settings.")
            match_started_at = now

        if (state is not None
                and state["priority_player"] == bot_seat
                and state["sequence"] == sequence
                and command_sent_for_sequence != sequence
                and state["phase"] != "game_over"):
            if next_command_at == 0.0:
                next_command_at = now + args.delay
            elif now >= next_command_at:
                action = COMMAND_CYCLE[cycle_index % len(COMMAND_CYCLE)]
                cycle_index += 1
                command_sent_for_sequence = sequence
                next_command_at = 0.0
                commit(command(action))
                if state["pending_kind"] and stuck_logged != state["pending_kind"]:
                    stuck_logged = state["pending_kind"]
                    log(f"Bot has a pending {stuck_logged} choice it cannot make; resolve it from the game or extend the bot.")

        time.sleep(0.05)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
    except (ConnectionError, OSError, ValueError) as error:
        log(str(error))
        sys.exit(1)

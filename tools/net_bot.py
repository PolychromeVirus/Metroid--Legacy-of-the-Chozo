"""Scripted network guest for testing direct-IP play with a single game instance.

Host a lobby in the game, then run:

    python tools/net_bot.py                  # joins as Player 2
    python tools/net_bot.py --seat 1         # takes Player 1 (spectate first in the lobby)

The bot joins, readies, and once the host starts the match it repeatedly sends
the commands in COMMAND_CYCLE. It tracks no game state: the host rejects
requests while the bot lacks priority and ignores actions that are not legal
in the current phase, so repeating the cycle is harmless.
"""

import argparse
import socket
import sys
import time

from gm_net import JOIN_PROTOCOL, MATCH_PROTOCOL, GameMakerConnection, command, log

# Sent in order, once per interval, whenever a match is running.
COMMAND_CYCLE = [
    "containment_no_ship",
    "special_containment_no_ship",
    "advance_phase",
    "resolve_raid",
    "end_turn",
]

LEADERS = ["bsl_researcher", "adam_malkovich", "mother_brain", "quiet_robe", "raven_beak"]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=6510)
    parser.add_argument("--name", default="NetBot")
    parser.add_argument("--leader", default="bsl_researcher", choices=LEADERS)
    parser.add_argument(
        "--seat", type=int, choices=[1, 2], default=2,
        help="Player seat to claim. Seat 1 must be free, so switch the host to spectator first.",
    )
    parser.add_argument("--interval", type=float, default=1.0, help="Seconds between commands.")
    parser.add_argument("--dump", action="store_true", help="Print raw received bytes.")
    args = parser.parse_args()

    connection = GameMakerConnection(socket.create_connection((args.host, args.port)), "client", args.dump)
    log(f"Connected to {args.host}:{args.port}.")
    connection.send({
        "type": "join_hello",
        "protocol": JOIN_PROTOCOL,
        "player_name": args.name,
        "leader_id": args.leader,
    })

    participant_id = None
    seat_requested = False
    readied = False
    match_running = False
    next_command_at = 0.0
    cycle_index = 0

    while True:
        for packet in connection.receive():
            kind = packet.get("type")
            if kind == "lobby_welcome":
                participant_id = packet["participant_id"]
                log(f"Joined lobby as participant {participant_id}.")
            elif kind == "lobby_state":
                me = next(
                    (p for p in packet["participants"] if p.get("participant_id") == participant_id),
                    None,
                )
                if me is None:
                    continue
                target_seat = args.seat - 1
                if me["seat"] != target_seat:
                    # Claiming an occupied seat is ignored by the host, so retry on each lobby update.
                    connection.send({"type": "lobby_action", "action": "claim_seat", "value": target_seat})
                    if not seat_requested:
                        log(f"Requesting Player {args.seat}; free that seat in the lobby if it is taken.")
                        seat_requested = True
                    readied = False
                elif not me["ready"] and not readied:
                    connection.send({"type": "lobby_action", "action": "toggle_ready", "value": 0})
                    readied = True
                    log(f"Seated as Player {args.seat}; ready. Start the match from the host.")
            elif kind == "start_match":
                if packet.get("protocol") != MATCH_PROTOCOL:
                    log(f"Match protocol {packet.get('protocol')} != {MATCH_PROTOCOL}; update the bot.")
                    return 1
                match_running = True
                log(f"Match started with seed {packet.get('seed')}.")
            elif kind == "command_commit":
                log(
                    f"commit #{packet.get('sequence')}: {packet.get('input_type')} "
                    f"{packet.get('action') or packet.get('kind')} "
                    f"(selected {packet.get('selected_kind')}:{packet.get('selected_index')})"
                )
            elif kind == "join_rejected":
                log(f"Join rejected: {packet.get('reason')}")
                return 1
            elif kind == "chat_message":
                log(f"chat: {packet.get('message')}")
            else:
                log(f"{kind}: {packet}")

        now = time.monotonic()
        if match_running and now >= next_command_at:
            action = COMMAND_CYCLE[cycle_index % len(COMMAND_CYCLE)]
            connection.send(command(action))
            cycle_index += 1
            next_command_at = now + args.interval
        time.sleep(0.05)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
    except (ConnectionError, OSError, ValueError) as error:
        log(str(error))
        sys.exit(1)

"""GameMaker TCP packet framing shared by the scripted network bots."""

import json
import struct
import time

# GameMaker's non-raw TCP functions prefix each packet with this header.
GM_MAGIC = 0xDEADC0DE
GM_HEADER = struct.Struct("<III")

# Connection handshake that precedes any packets: server hello, client signature,
# server acknowledgement.
GM_HELLO = b"GM:Studio-Connect\0"
GM_CLIENT_SIGNATURE = struct.Struct("<IIII")
GM_SERVER_ACK = struct.Struct("<III")

JOIN_PROTOCOL = 2
MATCH_PROTOCOL = 3


def log(message):
    print(f"[{time.strftime('%H:%M:%S')}] {message}", flush=True)


def _read_exact(sock, size):
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise ConnectionError("Connection closed during the GameMaker handshake.")
        data += chunk
    return data


def _check(received, expected, stage):
    if received != expected:
        raise ValueError(f"Handshake {stage} mismatch: got {received.hex(' ')}, expected {expected.hex(' ')}.")


class GameMakerConnection:
    def __init__(self, sock, role, dump=False):
        sock.settimeout(10)
        if role == "server":
            sock.sendall(GM_HELLO)
            signature = _read_exact(sock, GM_CLIENT_SIGNATURE.size)
            _check(signature[:12], GM_CLIENT_SIGNATURE.pack(0xCAFEBABE, 0xDEADB00B, 16, 0)[:12], "client signature")
            sock.sendall(GM_SERVER_ACK.pack(0xDEAFBEAD, 0xF00DBEEB, 12))
        else:
            _check(_read_exact(sock, len(GM_HELLO)), GM_HELLO, "server hello")
            sock.sendall(GM_CLIENT_SIGNATURE.pack(0xCAFEBABE, 0xDEADB00B, 16, 0))
            _check(_read_exact(sock, GM_SERVER_ACK.size), GM_SERVER_ACK.pack(0xDEAFBEAD, 0xF00DBEEB, 12), "server ack")
        self.sock = sock
        self.sock.setblocking(False)
        self.buffer = b""
        self.dump = dump

    def send(self, message):
        payload = json.dumps(message, separators=(",", ":")).encode("utf-8") + b"\0"
        self.sock.sendall(GM_HEADER.pack(GM_MAGIC, GM_HEADER.size, len(payload)) + payload)

    def receive(self):
        try:
            chunk = self.sock.recv(65536)
        except BlockingIOError:
            return []
        if not chunk:
            raise ConnectionError("Connection closed by the game.")
        if self.dump:
            log(f"raw {len(chunk)} bytes: {chunk[:48].hex(' ')}")
        self.buffer += chunk
        packets = []
        while len(self.buffer) >= GM_HEADER.size:
            magic, header_size, payload_size = GM_HEADER.unpack_from(self.buffer)
            if magic != GM_MAGIC:
                raise ValueError(
                    "Unexpected packet header "
                    f"{self.buffer[:GM_HEADER.size].hex(' ')}; rerun with --dump and "
                    "update GM_HEADER in tools/gm_net.py to match."
                )
            if len(self.buffer) < header_size + payload_size:
                break
            payload = self.buffer[header_size:header_size + payload_size]
            self.buffer = self.buffer[header_size + payload_size:]
            packets.append(json.loads(payload.split(b"\0", 1)[0].decode("utf-8")))
        return packets


def command(action):
    return {
        "type": "command_request",
        "input_type": "action",
        "action": action,
        "kind": "",
        "index": -1,
        "selected_kind": "",
        "selected_index": -1,
    }


def describe_state(state):
    players = " | ".join(
        f"P{index + 1} cp {p['command_points']} hand {p['hand']} deck {p['deck']} "
        f"discard {p['discard']} board {p['board']} lab {p['lab']}"
        for index, p in enumerate(state["players"])
    )
    pending = f" pending {state['pending_kind']}" if state["pending_kind"] else ""
    return (
        f"turn {state['turn']} {state['phase']} active P{state['active_player'] + 1} "
        f"priority P{state['priority_player'] + 1}{pending} | {players}"
    )

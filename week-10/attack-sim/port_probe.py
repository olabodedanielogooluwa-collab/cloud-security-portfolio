"""Probe TCP ports on one host you own: open, refused or filtered."""
import socket
import sys

host = sys.argv[1]
for port in map(int, sys.argv[2:] or [22, 80, 443, 8080, 3306]):
    s = socket.socket()
    s.settimeout(3)
    try:
        s.connect((host, port))
        result = "open"
    except ConnectionRefusedError:
        result = "refused"
    except (socket.timeout, TimeoutError):
        result = "filtered"
    except OSError as e:
        result = f"error ({e.errno})"
    finally:
        s.close()
    print(f"{port:>5}  {result}")

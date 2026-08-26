#!/bin/bash
# port_scanner.sh
# Checks a list of common ports on localhost using bash's built-in
# /dev/tcp pseudo-device, no external tools required.

HOST="localhost"
PORTS=(22 80 443 3306 8080)

for port in "${PORTS[@]}"; do
  if timeout 1 bash -c "echo > /dev/tcp/$HOST/$port" 2>/dev/null; then
    echo "Port $port: OPEN"
  else
    echo "Port $port: closed"
  fi
done

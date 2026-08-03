#!/bin/bash
HOST="localhost"
PORTS=(22 80 443 3306 8080)

echo "Scanning $HOST for open ports..."

for port in "${PORTS[@]}"; do
    timeout 1 bash -c "echo > /dev/tcp/$HOST/$port" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "Port $port: OPEN"
    else
        echo "Port $port: closed"
    fi
done

#!/bin/bash
LOGFILE="/var/log/apache2/access.log"
echo "Checking Apache access log for errors and suspicious activity..."

if [ -f "$LOGFILE" ]; then
    echo "--- Last 10 entries ---"
    tail -n 10 "$LOGFILE"
    echo "--- 404 errors found ---"
    grep " 404 " "$LOGFILE" | wc -l
    echo "--- 500 errors found ---"
    grep " 500 " "$LOGFILE" | wc -l
else
    echo "Log file not found at $LOGFILE"
fi

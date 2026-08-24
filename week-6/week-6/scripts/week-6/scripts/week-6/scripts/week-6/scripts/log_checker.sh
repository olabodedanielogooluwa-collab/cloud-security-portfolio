#!/bin/bash
# log_checker.sh
# Prints the last 10 entries of Apache's access log and counts
# 404 / 500 response codes.

LOG_FILE="/var/log/apache2/access.log"

if [ ! -f "$LOG_FILE" ]; then
  echo "Log file not found at $LOG_FILE"
  exit 1
fi

echo "Last 10 log entries:"
tail -n 10 "$LOG_FILE"

echo ""
echo "404 (Not Found) count:"
grep -c '" 404 ' "$LOG_FILE"

echo "500 (Server Error) count:"
grep -c '" 500 ' "$LOG_FILE"

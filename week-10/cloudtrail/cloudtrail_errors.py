"""List failed CloudTrail events for the last 24 hours in one region."""
import json
import sys
from datetime import datetime, timedelta, timezone

import boto3

region = sys.argv[1] if len(sys.argv) > 1 else "us-east-1"
ct = boto3.client("cloudtrail", region_name=region)
start = datetime.now(timezone.utc) - timedelta(hours=24)
for page in ct.get_paginator("lookup_events").paginate(StartTime=start):
    for item in page["Events"]:
        e = json.loads(item["CloudTrailEvent"])
        if e.get("errorCode"):
            print(e["sourceIPAddress"], e["eventName"], e["errorCode"])

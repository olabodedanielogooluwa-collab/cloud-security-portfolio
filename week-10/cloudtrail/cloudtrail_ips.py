"""Group CloudTrail management events by source IP for the last 24 hours."""
import json
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

import boto3

hours = int(sys.argv[1]) if len(sys.argv) > 1 else 24
region = sys.argv[2] if len(sys.argv) > 2 else "us-east-1"
ct = boto3.client("cloudtrail", region_name=region)
start = datetime.now(timezone.utc) - timedelta(hours=hours)

sources = defaultdict(lambda: {"count": 0, "users": set(), "events": set(), "errors": 0})
pages = ct.get_paginator("lookup_events").paginate(StartTime=start)
for page in pages:
    for item in page["Events"]:
        e = json.loads(item["CloudTrailEvent"])
        s = sources[e.get("sourceIPAddress", "unknown")]
        s["count"] += 1
        s["users"].add(e.get("userIdentity", {}).get("arn", "unknown").split("/")[-1])
        s["events"].add(e["eventName"])
        s["errors"] += 1 if e.get("errorCode") else 0

for ip, s in sorted(sources.items(), key=lambda kv: -kv[1]["count"]):
    print(f"{ip:<28} events={s['count']:<4} errors={s['errors']:<3} users={sorted(s['users'])[:3]}")
    print(f"    sample: {sorted(s['events'])[:5]}")

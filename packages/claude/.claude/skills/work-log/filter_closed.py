import datetime
import json
import sys

lo, hi, day_start = sys.argv[1], sys.argv[2], int(sys.argv[3])
for r in json.load(sys.stdin):
    t = datetime.datetime.fromisoformat(r["closedAt"].replace("Z", "+00:00")).astimezone()
    # A PR closed after midnight still belongs to the work day that was running.
    owner = (t - datetime.timedelta(hours=day_start)).strftime("%Y-%m-%d")
    if lo <= owner <= hi:
        print("  {}#{} [{}] {:%H:%M} {}".format(
            r["repository"]["nameWithOwner"], r["number"], r["state"], t, r["title"]))

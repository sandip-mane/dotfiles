"""Render one repo's `%h|%S|%at|%P|%s` git log: commits first, then merges."""

import datetime
import sys

mode, day_start = sys.argv[1], int(sys.argv[2])
commits, merges = [], []

for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    sha, ref, ts, parents, subject = line.split("|", 4)
    if " " in parents:
        merges.append("  MERGE  {:<10} ref={:<46} {}".format(sha, ref, subject))
        continue
    t = datetime.datetime.fromtimestamp(int(ts)).astimezone()
    if mode == "range":
        # Stamp the work day the commit belongs to, but keep its real clock time.
        owner = (t - datetime.timedelta(hours=day_start)).strftime("%d-%m-%Y")
        stamp = "{} {:%H:%M}".format(owner, t)
    else:
        stamp = "{:%H:%M}".format(t)
    commits.append("  commit {:<10} ref={:<46} {}  {}".format(sha, ref, stamp, subject))

print("\n".join(commits + merges))

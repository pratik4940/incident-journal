# Postmortem: deleted but open file

## Summary
A running process still held a deleted log file open, so its blocks were never
freed. Truncating the file through /proc/<pid>/fd/3 freed the space without
restarting the process.

## Timeline
No clock times were recorded. Order of events:
1. Writes to /srv/applogs fail with "No space left on device".
2. df shows 100% used; du shows 20K.
3. lsof shows agent.log (deleted) held open by a python3 process.
4. /proc/pid/fd/ confirms the open descriptor.
5. File truncated through /proc/pid/fd/3; df shows the space free.

## Hypotheses
Written after the fact. I did not record hypotheses before investigating.

| Hypothesis | Test | Result |
|------------|------|--------|
| Deleted file still held open | lsof, /proc/<pid>/fd | Confirmed |

## Root cause
- Trigger: a manual rm of agent.log while the agent was writing to it.
- Cause: rm removes only the name. The kernel frees the blocks when the link
  count is 0 and no process has the file open.
- Detection gap: no alert on disk usage or on large deleted-but-open files.

du counts files reachable by name; df counts allocated blocks. The 20K was the
lost+found directory (16K) plus the root directory (4K).

## Fix
1. Compared df and du.
2. Found the holder with lsof and the descriptor under /proc/pid/fd/.
3. Truncated it: `: > /proc/<pid>/fd/3`. This is safe here because the agent
   opens the file in append mode, so its next write lands at the new end.
4. df showed the space free again.

No backup was taken first. In production, copy the data out before truncating:
`cat /proc/<pid>/fd/3 > backup`, to a filesystem that has room.

## Prevention
| Action | Type | Status |
|--------|------|--------|
| Alert at 80% usage and on predicted fill within 4h | detect | Open |
| Check large deleted-but-open files with lsof +L1 | detect | Open |
| Truncate or logrotate in-use files, never rm | prevent | Open |

## Commands that mattered
df -h, du -sh, lsof, lsof +L1, ls -l /proc/pid/fd

## What I got wrong
- Did not write hypotheses before investigating.
- Thought rm -f removes the data; it only skips prompts.
- Called the 20K "ext4 metadata"; it was lost+found plus the root directory.
- Re-ran the injection script mid-investigation, which changed the PID and the
  system under diagnosis.
- Wrote a cause ("cleanup job") that I never observed.
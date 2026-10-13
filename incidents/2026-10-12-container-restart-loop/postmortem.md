# Postmortem: container restart loop (OOM kill)

## Summary
orders-api kept restarting about every 7 seconds because its 64 MiB memory
limit was lower than the roughly 161 MiB the app uses once its cache is warm.
The kernel's cgroup OOM killer sent SIGKILL (exit 137) each time. Raising the
limit to 256 MiB with swap disabled made it stable.

## Timeline
Times are UTC, from syslog and docker inspect.
| Time | Event |
|------|-------|
| 16:48:21 | Container created and started with a 64 MiB limit |
| 16:48:28 | Kernel OOM-kills it, about 7s after start |
| later | Restart policy restarts it; a second sample shows start 17:18:08, kill 17:18:16 (same ~7s pattern) |
| not recorded | docker update applied |
| about 2 min later | docker stats flat at 161 MiB; verify.sh passes all three checks |

## Hypotheses
Recorded after I had already read app.py, which I should not have done first.

| Hypothesis | Test | Result |
|------------|------|--------|
| Container hit its own memory limit | docker inspect OOMKilled; kernel log constraint; docker stats | Confirmed: OOMKilled true, CONSTRAINT_MEMCG, memory climbing to 64 MiB and resetting |
| Host ran out of memory | Constraint in kernel OOM line | Rejected: CONSTRAINT_MEMCG (a host-wide OOM shows CONSTRAINT_NONE) |
| Application bug or crash | docker logs | Rejected: normal "ok cache=..." lines, no traceback; output just stops (SIGKILL cannot be caught or logged) |
| Manual or external kill | OOMKilled flag, kernel OOM line, identical ~7s timing | Rejected: kill reason is recorded as OOM and is deterministic |

## Root cause
- Trigger: the container was created with `--memory 64m --memory-swap 64m`.
- Cause: the app grows its cache by 8 MB per second up to 160 MB, so at about
  7 seconds it exceeded 64 MiB and the cgroup OOM killer sent SIGKILL. The
  restart policy (unless-stopped) restarted it, so docker ps showed "Up" while
  the service kept dropping out.
- Detection gap: nothing alerted on restarts or OOM kills, the limit was never
  checked against real usage, and the logs showed no error because SIGKILL
  gives the process no chance to write one.

## Fix
    docker update --memory 256m --memory-swap 256m orders-api

256 MiB because the app plateaus at about 161 MiB, which leaves around 95 MiB
of headroom without taking much of a 4 GB VM. Swap is disabled (memory-swap
equals memory) so the container fails fast instead of slowing down by
swapping. Verified: docker stats stayed flat at about 161 MiB for roughly two
minutes, and verify.sh passed.

Limit: docker update changes only the running container. The original create
command still says 64m, so a redeploy would bring the problem back.

## Prevention
| Action | Type | Status |
|--------|------|--------|
| Define the limit in the file that creates the container (Compose mem_limit, Kubernetes resources.limits.memory), kept in Git | prevent | Open |
| Size limits from measured usage (docker stats) plus headroom | prevent | Open |
| Alert on more than 3 restarts in 10 minutes (a count over a window, because restart delay grows) | detect | Open |
| Alert when the last termination reason is OOMKilled | detect | Open |
| Alert when memory stays above about 85% of the limit for several minutes | detect | Open |
| docker update as the live mitigation until the config is fixed | mitigate | Done |

## Commands that mattered
docker ps, docker logs, docker inspect (State.ExitCode, State.OOMKilled),
grep of /var/log/syslog for the container ID, docker stats, docker update,
verify.sh. RestartCount was not recorded.

## What I got wrong
- Read app.py before forming hypotheses.
- Said 137 was SIGTERM. It is SIGKILL (128+9); SIGTERM is 143. Exit 137 alone
  does not prove the kernel did it. OOMKilled and the kernel log do.
- Called the 64m limit a default. Docker has no default memory limit; it was
  set when the container was created.
- Used the wrong flag name in my notes (--swap-mem instead of --memory-swap)
  and a wrong container ID in the grep.
- Proposed alerting on "7 restarts per minute". Restart delay grows, so alert
  on a count over a window instead.
- Sized the limit from reading the code before measuring it. docker stats
  confirmed the number afterwards.
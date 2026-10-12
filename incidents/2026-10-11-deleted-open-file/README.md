# Deleted but open file: df 100%, du 20K

Date: 2026-10-11
Category: linux
Simulated fault in a VM, not a production incident.

## Problem
Writes to /srv/applogs are failing with "No space left on device".
df reports the volume 100% used, but du on the directory shows only 20K.
Someone already deleted the big log files, and the space did not come back.

## Impact
New data cannot be written to the volume.

## Task
Find out why the space is not free and release it without restarting the
agent that writes to it.

## Run
    sudo bash inject.sh    # create the problem (do not read it first)
    sudo bash verify.sh    # check the fix
    sudo bash reset.sh     # clean up

Write-up: [postmortem.md](postmortem.md)
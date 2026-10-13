# Container keeps restarting

Date: 2026-10-12
Category: docker
Simulated fault in a VM, not a production incident.

## Problem
The orders-api container shows "Up" in docker ps, but the service keeps
dropping out every few seconds. Its logs look normal and show no errors.

## Impact
Requests to orders-api fail intermittently.

## Task
Find out why it keeps restarting and make it stable for real, not by hiding
the restarts. Before you investigate, write your top three hypotheses in
postmortem.md.

## Run
    sudo bash inject.sh    # create the problem (do not read it first)
    sudo bash verify.sh    # check the fix
    sudo bash reset.sh     # clean up

Write-up: [postmortem.md](postmortem.md)
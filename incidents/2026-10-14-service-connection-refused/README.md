# Service refuses connections

Date: 2026-10-14
Category: kubernetes
Simulated fault in a lab cluster, not a production incident.

## Problem
In namespace shop, the web Deployment shows 2/2 pods Running and Ready.
But requests to the web Service fail with "connection refused".
Someone already restarted the pods and nothing changed.

## Impact
The shop web service is unreachable from inside the cluster.

## Task
Find out why the Service refuses connections and fix it. Before you
investigate, write your top three hypotheses in postmortem.md.

## Run
    sudo bash inject.sh    # create the problem (do not read it first)
    sudo bash verify.sh    # check the fix
    sudo bash reset.sh     # clean up

Write-up: [postmortem.md](postmortem.md)
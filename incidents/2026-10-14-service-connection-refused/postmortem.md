# Postmortem: service refuses connections

## Summary
In namespace shop, the web Deployment was 2/2 Ready but every request to the
web Service was refused. Two independent faults were stacked. The Service
selector (app=webapp) matched no pods, so the Service had no endpoints. After
that was fixed, targetPort 8080 pointed at a port nothing listens on, because
nginx listens on 80. Both faults produced the same "connection refused"
message, so fixing the first one changed nothing visible.

## Timeline
No clock times were recorded. Order of events:
1. verify.sh: pods ready, no endpoints, request fails.
2. Looked in the default namespace first and found nothing; the workload is
   in shop.
3. curl to the Service ClusterIP from the node failed to connect.
4. get endpointslices: ENDPOINTS and PORTS were <unset>.
5. get svc -o wide showed selector app=webapp. get pods --show-labels showed
   the pods labelled app=web.
6. Edited the Service selector to app=web. Requests were still refused.
   verify.sh now passed the endpoints check but failed the request check.
7. From a busybox pod, wget web was refused. get endpointslices -o wide now
   showed both pod IPs on port 8080.
8. wget web:8080 hung, because the Service exposes port 80, not 8080.
9. Edited the Service targetPort to 80. wget web:80 and curl to the ClusterIP
   returned the nginx page, and verify.sh passed all three checks.
10. netstat -tln inside a pod showed only port 80 listening.

## Hypotheses
Recorded before investigating.

| Hypothesis | Test | Result |
|------------|------|--------|
| Selector does not match pod labels, so the Service has no endpoints | get endpointslices; compare Service selector with pod labels | Confirmed: endpoints <unset>, app=webapp vs app=web |
| targetPort does not match the port the app listens on | get endpointslices -o wide; netstat -tln in a pod | Confirmed: endpoints on 8080, nginx listens on 80 only |
| Both at once | Run both checks even after the first one explains the symptom | Confirmed: the first fix did not change the symptom |
| Network-level problem (CNI or kube-proxy) | Not tested directly | Not tested; Service traffic worked once both faults were fixed |

## Root cause
- Trigger: the Service was created with selector app=webapp and targetPort
  8080.
- Cause: the pods carry the label app=web and nginx listens on port 80, so the
  Service had no endpoints, and once it had them it forwarded to a closed
  port. Two independent faults, one symptom.
- Detection gap: a Deployment showing 2/2 Ready says nothing about routing.
  Nothing checked that the Service had ready endpoints or answered a request
  after deploy.

## Why both faults looked the same
- No endpoints: kube-proxy rejects connections to a Service with nothing
  behind it.
- Wrong targetPort: the connection reaches the pod, which resets it because
  nothing listens on 8080.

Either way the client sees "connection refused". The difference is in the
EndpointSlice: empty in the first case, populated with the wrong port in the
second. A hang (wget web:8080) is a third case: the Service does not expose
that port, so nothing handled the packets.

## Fix
1. Changed the Service selector to app=web.
2. Changed the Service targetPort to 80. The exact edit was not recorded; it
   is inferred from the working end state and confirmed by netstat showing
   only port 80 listening in the pod.

Both were made with kubectl edit on the live Service, which is a live
mitigation. The durable fix is to correct the manifest in Git.

Verified with verify.sh: pods ready, service has endpoints, request to the
service succeeds.

## Prevention
| Action | Type | Status |
|--------|------|--------|
| Fix selector and targetPort in the manifest in Git, not only on the live Service | prevent | Open |
| Name the container port and point targetPort at the name so the Service follows the container | prevent | Open |
| Generate selector and pod labels from one source (Helm helper or Kustomize labels) | prevent | Open |
| Run a request through the Service after every deploy (verify.sh does this in the lab) | detect | Done in lab |
| Alert when a Service has zero ready endpoints (kube-state-metrics, once Prometheus is installed) | detect | Open |
| kubectl edit on the live Service as a stopgap until the manifest is fixed | mitigate | Done |

## Commands that mattered
    kubectl get endpointslices -n shop -o wide
    kubectl get svc -n shop -o wide
    kubectl get pods -n shop --show-labels
    kubectl -n shop exec deploy/web -- netstat -tln
    kubectl -n shop exec busybox -- wget -qO- -T 3 http://web
    ./verify.sh

## What I got wrong
- Looked in the default namespace first. Setting the namespace once with
  kubectl config set-context --current --namespace=shop avoids this.
- Tried curl in a busybox pod. The image only has wget.
- Ran wget web:8080 against a Service that exposes port 80. It hung, which
  told me nothing about the pod.
- Confirmed the pod's real listening port with netstat only after changing
  targetPort, not before.
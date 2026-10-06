# Homework 8 — HA k3s cluster (3 control-plane + 3 workers)

A re-usable setup that builds a 6-node Kubernetes (k3s) cluster on a
MacBook using Multipass VMs, installs it with Ansible, and runs a
"hello world" pod and the HW7 chatbot on it. No node has dual roles.

## Architecture

| Node          | Role          |
|---------------|---------------|
| k3s-server-1  | control-plane (starts cluster, embedded etcd) |
| k3s-server-2  | control-plane |
| k3s-server-3  | control-plane |
| k3s-agent-1   | worker        |
| k3s-agent-2   | worker        |
| k3s-agent-3   | worker        |

Three control-plane nodes give high availability (the cluster
survives losing one). Three workers run the application pods.

## Prerequisites (on the Mac, once)

```bash
brew install --cask multipass
brew install ansible kubectl
```

## Run order

```bash
# 1. Create the 6 VMs + generate inventory.ini
chmod +x setup.sh
./setup.sh

# 2. Install the whole cluster, automatically (the re-usable playbook)
ansible-playbook -i inventory.ini playbook.yml

# 3. Talk to the cluster from the Mac
export KUBECONFIG=./kubeconfig
kubectl get nodes          # should list all 6 nodes as Ready

# 4. Hello world
kubectl apply -f hello-world.yaml
kubectl get pods -o wide   # see which worker it runs on

# 5. The chatbot (HW7) on the full cluster
#    First push the image so all workers can pull it:
docker tag chatbot <DOCKERHUB_USER>/chatbot:latest
docker push <DOCKERHUB_USER>/chatbot:latest
#    Edit chatbot/deployment.yaml -> set <DOCKERHUB_USER>
kubectl create secret generic openai-secret --from-env-file=.env
kubectl apply -f chatbot/
kubectl get pods -o wide
```

## How the web page is reachable from the laptop browser

This is the key networking question, and it has two parts:

1. **Reaching the nodes.** Multipass gives each VM an IP on a
   host-reachable network (on macOS, typically `192.168.64.x`). The
   Mac can talk to those IPs directly — no extra routing needed. You
   can check with `multipass list`.

2. **Reaching the app inside the cluster.** The service is of type
   **NodePort** (port `30080`). k3s runs kube-proxy on *every* node,
   so that port is open on *all six* node IPs. A request to any node
   is routed internally to whichever worker actually runs the pod —
   so it doesn't matter which node IP you pick.

So from the Mac browser:

```
http://<any-node-ip>:30080      # e.g. http://192.168.64.11:30080
```

Get a node IP from `kubectl get nodes -o wide` or `multipass list`.

(k3s also ships a built-in load balancer, ServiceLB, so a
`type: LoadBalancer` service would expose it on the node IPs at the
service port too — NodePort is just the most transparent to explain.)

## Tear down (re-usable: rebuild any time)

```bash
multipass delete k3s-server-1 k3s-server-2 k3s-server-3 \
                 k3s-agent-1 k3s-agent-2 k3s-agent-3
multipass purge
```

## Deliverables checklist

- [ ] 3 screenshots from the cluster setup
- [ ] This repo = the re-usable install (setup.sh + playbook.yml)
- [ ] Screenshot of working hello-world
- [ ] Screenshot of the working chatbot POD
- [ ] The networking explanation above

# Running GitHub Self-Hosted Runners on AKS Virtual Nodes (backed by Azure Container Instances)

Below is a focused, runnable plan plus ready-to-use manifests and commands to run GitHub self-hosted Actions runners on AKS Virtual Nodes backed by Azure Container Instances (ACI). It includes a quick manual runner Deployment (for testing) and the recommended production approach using actions-runner-controller (ARC).

I won't run anything on your cloud — these are exact commands and manifests you can paste into your shell.

---

## Summary of steps
- Prerequisites and Azure setup (resource group, subnet for ACI, register providers).
- Create AKS cluster with Virtual Node (ACI) addon.
- Confirm and inspect the virtual node labels (so we can schedule pods onto them).
- Option A — Quick test: run a single self-hosted runner Deployment and target the virtual node.
- Option B — Recommended: install actions-runner-controller (ARC) and configure RunnerDeployment CRs that schedule onto virtual nodes (ARC automates ephemeral token creation and lifecycle).
- Test a workflow, security notes, and cleanup.

---

## 1) Prerequisites
- Azure CLI (`az`) installed and logged in: `az login`
- `kubectl` installed
- `helm` installed (for actions-runner-controller)
- A GitHub PAT (personal access token) with appropriate scopes:
  - repo-level runners: `repo` & `repo:status` (or `repo` scopes as appropriate)
  - org-level runners: `admin:org` or admin-level scopes
  - Prefer using a GitHub App for production with ARC if possible
- An Azure subscription with permission to create AKS, VNet, and ACI resources.

---

## 2) Azure: register providers & create resource group, vnet and subnet for ACI
ACI used with AKS virtual nodes requires a dedicated subnet for ACI.

```bash
# Set variables
RG="rg-aks-virtualnode"
LOCATION="eastus"
VNET="vnet-aks"
SUBNET="aci-subnet"

# create resource group
az group create -n $RG -l $LOCATION

# register providers (if not already)
az provider register --namespace Microsoft.ContainerInstance
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.ContainerService

# create virtual network and dedicated subnet for ACI
az network vnet create -g $RG -n $VNET --address-prefix 10.0.0.0/8 --subnet-name $SUBNET --subnet-prefix 10.240.0.0/16

# capture subnet id
SUBNET_ID=$(az network vnet subnet show -g $RG -n $SUBNET --vnet-name $VNET --query id -o tsv)
echo $SUBNET_ID
```

---

## 3) Create AKS with Virtual Node (ACI) add-on
Create an AKS cluster and enable the virtual-node addon, pointing to the ACI subnet.

```bash
CLUSTER="aks-vnodes"
AKS_RG=$RG
NODE_COUNT=1

az aks create \
  -g $AKS_RG \
  -n $CLUSTER \
  --node-count $NODE_COUNT \
  --enable-managed-identity \
  --network-plugin azure \
  --enable-addons virtual-node \
  --aci-subnet-name $SUBNET \
  --generate-ssh-keys
```

Notes:
- Use `--network-plugin azure` (required by virtual nodes).
- Flags may vary across Azure CLI versions; the essential parts are the virtual-node addon and a dedicated subnet for ACI.

Get cluster credentials:

```bash
az aks get-credentials -g $AKS_RG -n $CLUSTER
kubectl get nodes
```

---

## 4) Inspect the virtual node and its labels (important — we’ll target these)
Virtual nodes appear as nodes in Kubernetes (backed by the virtual-kubelet/ACI). Discover the virtual node name and labels:

```bash
kubectl get nodes -o wide
kubectl get nodes --show-labels
```

Look for node names or labels indicating virtual-kubelet/ACI, e.g.:
- node name containing "virtual" or "virtual-kubelet" or "aci"
- labels such as `virtual-kubelet.io/provider=azure` or similar

You can add your own label to the virtual node for easier scheduling:

```bash
kubectl label node <virtual-node-name> runner=aci-virtual-node
```

---

## 5) Option A — Quick/manual runner deployment (good for testing)
This runs the official runner container on the virtual node. It requires creating a GitHub registration token (ephemeral — expires quickly). For production use ARC (next section).

Get a registration token (repo-level example; requires `$GITHUB_PAT`):

```bash
OWNER="your-github-owner"
REPO="your-repo"
GITHUB_PAT="ghp_xxx..."  # set this securely

TOKEN=$(curl -s -X POST -H "Authorization: token $GITHUB_PAT" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/runners/registration-token" | jq -r .token)
echo $TOKEN
```

Create a Kubernetes secret (for demo only — token is short-lived):

```bash
kubectl create secret generic gh-runner-token --from-literal=token=$TOKEN --namespace default
```

Sample Deployment manifest that pins the runner to the virtual node (update nodeSelector to match your label):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-runner-aci
  labels:
    app: github-runner-aci
spec:
  replicas: 1
  selector:
    matchLabels:
      app: github-runner-aci
  template:
    metadata:
      labels:
        app: github-runner-aci
    spec:
      nodeSelector:
        runner: aci-virtual-node   # <- replace with your virtual node label
      containers:
      - name: runner
        image: ghcr.io/actions/runner:latest
        env:
        - name: RUNNER_NAME
          value: "aks-aci-runner-1"
        - name: RUNNER_REPO
          value: "YOUR_ORG/YOUR_REPO"   # replace
        - name: RUNNER_TOKEN
          valueFrom:
            secretKeyRef:
              name: gh-runner-token
              key: token
        - name: RUNNER_WORKDIR
          value: /tmp/runner
        volumeMounts:
        - name: work
          mountPath: /tmp/runner
      volumes:
      - name: work
        emptyDir: {}
```

Apply it:

```bash
kubectl apply -f runner-deployment.yaml
kubectl get pods -w
```

Notes:
- Registration token expires quickly; create the Deployment immediately after creating the token for testing.
- Manual approach is fine for experimentation, but not recommended for production due to token lifecycle and management.

---

## 6) Option B — Recommended: actions-runner-controller (ARC) on AKS + schedule to virtual nodes
ARC automates runner token creation, scaling, and lifecycle. Use Helm to install ARC, then create RunnerDeployment CRs.

Install ARC:

```bash
kubectl create namespace actions-runner-system

helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

helm install actions-runner-controller actions-runner-controller/actions-runner-controller \
  -n actions-runner-system
```

Authentication for ARC:
- ARC needs a secret with a GitHub PAT or GitHub App credentials. Example (PAT approach, repo-level):

```bash
kubectl create secret generic controller-manager --from-literal=github_token=$GITHUB_PAT -n actions-runner-system
```

Create a RunnerDeployment that schedules pods onto the virtual node by nodeSelector or nodeAffinity. Replace `nodeSelector` value with the label you discovered/labeled earlier.

Example RunnerDeployment:

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: aks-aci-runners
  namespace: default
spec:
  replicas: 2
  template:
    spec:
      nodeSelector:
        runner: aci-virtual-node   # <-- replace with actual label
      runnerGroup: ""
      labels:
        - "self-hosted"
        - "linux"
      repository: "YOUR_ORG_OR_USER/YOUR_REPO"   # set to repo or remove for orgRunners
      resources:
        requests:
          cpu: "0.5"
          memory: "1Gi"
```

Apply:

```bash
kubectl apply -f runner-deployment-arc.yaml
kubectl get runners -n default
```

ARC will automatically create registration tokens and manage runner lifecycle. ARC supports autoscaling with HorizontalRunnerAutoscaler CRD.

Important ARC considerations:
- Use the chart README to set secret names and fields correctly.
- For org-level runners, the PAT must have appropriate admin scopes.
- Prefer GitHub App authentication for production for better security.

---

## 7) Test a workflow
Add a workflow that uses `self-hosted`:

Create `.github/workflows/test-self-hosted.yml` in your repo:

```yaml
name: CI on self-hosted

on: [push]

jobs:
  test:
    runs-on: [self-hosted, linux]
    steps:
      - name: Print runner
        run: |
          echo "Runner: $RUNNER_NAME"
          uname -a
```

Push and watch the job on GitHub — it should be picked up by your runner(s).

---

## 8) Networking, egress, and DNS
- ACI-backed virtual nodes run containers in ACI with outbound NAT; ensure outbound access to:
  - api.github.com
  - actions.githubusercontent.com
  - github.com
- If your org requires fixed egress IP addresses, configure NAT or other outbound solutions. ACI virtual nodes use dynamic IPs by default; plan accordingly.

---

## 9) Security and secrets
- Use least privilege for PATs. Prefer GitHub App authentication.
- Do not store long-lived PATs in plain manifests; use Kubernetes Secrets and rotate tokens.
- Consider running runner containers as non-root and use PodSecurity admission controls.
- Use repository-scoped tokens where possible; ARC automates ephemeral tokens and is recommended.

---

## 10) Cost & scaling behavior
- Virtual Nodes (ACI) are billed per second for container group resources and are good for burst workloads.
- ACI provisioning cold start is typically seconds to tens of seconds.
- ARC autoscaling + ACI virtual nodes is a cost-efficient pairing for workflows with bursty demand.

---

## 11) Troubleshooting
- If pods are Pending, check nodeSelector and that the virtual node exists and has labels:
  - `kubectl describe pod <pod>`
  - `kubectl describe node <virtual-node-name>`
- If registration fails, token freshness is usually the issue for manual deployments. ARC avoids this.
- ARC logs: `kubectl -n actions-runner-system logs deploy/actions-runner-controller`

---

## 12) Cleanup
```bash
# delete AKS
az aks delete -g $AKS_RG -n $CLUSTER --yes

# delete resource group (removes VNet, subnets, ACI resources, etc)
az group delete -n $RG --yes --no-wait
```

---

## Files / Manifests (ready to copy)

Runner Deployment (manual test) — save as `runner-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-runner-aci
  labels:
    app: github-runner-aci
spec:
  replicas: 1
  selector:
    matchLabels:
      app: github-runner-aci
  template:
    metadata:
      labels:
        app: github-runner-aci
    spec:
      nodeSelector:
        runner: aci-virtual-node   # <-- replace with the label you chose/discovered
      containers:
      - name: runner
        image: ghcr.io/actions/runner:latest
        env:
        - name: RUNNER_NAME
          value: "aks-aci-runner-1"
        - name: RUNNER_REPO
          value: "YOUR_ORG/YOUR_REPO"   # replace
        - name: RUNNER_TOKEN
          valueFrom:
            secretKeyRef:
              name: gh-runner-token
              key: token
        - name: RUNNER_WORKDIR
          value: /tmp/runner
        volumeMounts:
        - name: work
          mountPath: /tmp/runner
      volumes:
      - name: work
        emptyDir: {}
```

RunnerDeployment for actions-runner-controller — save as `runner-deployment-arc.yaml`:

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: aks-aci-runners
  namespace: default
spec:
  replicas: 2
  template:
    spec:
      nodeSelector:
        runner: aci-virtual-node   # <-- replace with your virtual node label
      labels:
      - "self-hosted"
      - "linux"
      repository: "YOUR_ORG_OR_USER/YOUR_REPO"   # replace with real repo
```

---

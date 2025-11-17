# On-demand Pod Generation with k3s
Dynamic OTA Verification Pods with HostPath-mounted Artifacts

## 📌 Overview
This project implements an on-demand dynamic Pod generator on a k3s cluster.
When an external system (or CI/CD) sends a **wake-up (TCP/nc) signal**,
the spawner automatically creates a **temporary OTA verification pod (ota-agent)**.

Each ota-agent pod loads the provided OTA image `.tar`, performs **D1/D4/D7 dynamic security validation**,
stores results in a shared host directory, and then terminates automatically.

This architecture is ideal for secure OTA pipelines, sandbox verification,
or isolated firmware inspection environments.

---

## 🏗 Build Steps

### 🔹 0. Preliminary
Make sure to put the OTA image you want to test **inside the `agent-io` directory**
(e.g., `agent-io/ivi-theme-0.1.tar`)

---

### 🔹 1. Build podman images

#### Spawner
CODEBLOCK_START bash
cd spawner
podman build -t localhost/ota-spawner:latest .
podman save -o ota-spawner.tar localhost/ota-spawner:latest
CODEBLOCK_END

#### Agent
CODEBLOCK_START bash
cd ../ota-agent
podman build -t localhost/ota-agent:latest .
podman save -o ota-agent.tar localhost/ota-agent:latest
CODEBLOCK_END

---

### 🔹 2. Import images into k3s
CODEBLOCK_START bash
sudo k3s ctr images import ota-spawner.tar
sudo k3s ctr images import ota-agent.tar
CODEBLOCK_END

---

### 🔹 3. Deploy the spawner
CODEBLOCK_START bash
cd ../k3s
sudo kubectl apply -f deployment.yaml
CODEBLOCK_END

---

### 🔹 4. Check pods
CODEBLOCK_START bash
sudo kubectl get pods -w
CODEBLOCK_END

---

### 🔹 5. Wake the spawner (trigger dynamic pod generation)
CODEBLOCK_START bash
echo "wake" | nc <your_ip> 4321
CODEBLOCK_END

---

### 🔹 6. Check OTA agent results

Outputs generated under:

- `agent-io/out/report.txt`
- `agent-io/out/artifacts/proc_list.log`

---

## ✔️ Done!
Your dynamic OTA verification environment is fully operational.


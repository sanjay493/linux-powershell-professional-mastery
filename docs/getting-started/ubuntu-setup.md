---
description: "Install and prepare Ubuntu 24.04 LTS (VM or physical) for the course."
---

# Ubuntu 24.04 LTS Setup

Ubuntu 24.04 LTS ("Noble Numbat") is the documented Linux platform for this course. It receives standard security updates until 2029.

## Option A — Virtual machine (recommended for Modules 3–4)

1. Download the ISO from <https://ubuntu.com/download> (Desktop or Server).
2. Create a VM in **VirtualBox** (free) or **Hyper-V** (Windows 11 Pro/Enterprise): 2 vCPU, 4 GB RAM, 25 GB disk.
3. Networking: use **NAT** for internet access. Add a second **Host-only** adapter for labs that need host-to-VM traffic (Days 12–15, 20, 26).
4. Install with default options and create a normal user (the course uses `student`).
5. **Take a snapshot** named `clean-install` once setup is finished. Before every risky lab (firewall, permissions), take another.

## Option B — WSL2

See [WSL2 Installation](wsl2.md).

## First-boot configuration

```bash
# Update the package lists and installed packages
sudo apt update && sudo apt full-upgrade -y

# Tools used throughout the course
sudo apt install -y curl wget git tree vim nano htop man-db bash-completion \
    net-tools dnsutils iproute2 iputils-ping traceroute mtr-tiny tcpdump \
    lsof psmisc sysstat jq shellcheck

# Check the release
cat /etc/os-release
```

!!! info "What these packages provide"
    `dnsutils` provides `dig` and `nslookup` (Day 13). `iproute2` provides `ip` and `ss` (Days 11, 14). `mtr-tiny`, `traceroute` and `iputils-ping` are used for connectivity (Day 12), `tcpdump` for packet capture (Day 15), `sysstat` for `iostat`/`sar` (Day 28), `jq` for JSON (Day 24) and `shellcheck` for script linting (Module 5).

## Install PowerShell 7 on Ubuntu (optional, from Day 5)

See [PowerShell 7 Installation](powershell-install.md#ubuntu-2404).

## Create your practice folder

```bash
mkdir -p ~/lpm-lab
```

## Verification

```bash
lsb_release -a          # Ubuntu 24.04.x LTS
bash --version | head -1
which dig ss ip tcpdump
ls -ld ~/lpm-lab
```

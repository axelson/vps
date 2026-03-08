# Plan: Migrate to nerves_system_x86_64 (PoC on Vultr)

## Overview

Convert the project to use `nerves_system_x86_64` (from hex.pm, `~> 1.33`) for a proof-of-concept deployment on a **new Vultr VM**. The existing production service (`:vultr` target) stays untouched until the PoC is verified.

---

## Context

### Current State

- The project already lists `:x86_64` in `@all_targets` and has a hex.pm dep on `nerves_system_x86_64 ~> 1.13`
- The `:vultr` target uses a custom `nerves_system_vultr` package
- `nerves_system_br` is pinned to `1.30.1` (from CVE-2025-32433 fix in commit `b04d1c1`)
- `nerves_system_x86_64 ~> 1.33` requires `nerves_system_br 1.33.2`
- Production runs at `pham.jasonaxelson.com` with sub-app domains at `*.jasonaxelson.com`

### Goal

Deploy a parallel PoC instance on a **new Vultr VM** at different hostnames, using `MIX_TARGET=x86_64`. Once verified, the PoC becomes production and the old instance is retired.

---

## PoC Domain Plan

To run both services in parallel, the PoC needs distinct domains:

| App | Current (production) | PoC |
|-----|---------------------|-----|
| VpsWeb (main/ACME) | `pham.jasonaxelson.com` | `poc.jasonaxelson.com` |
| dep_viz | `depviz.jasonaxelson.com` | `depviz-poc.jasonaxelson.com` |
| makeup_live | `makeuplive.jasonaxelson.com` | `makeuplive-poc.jasonaxelson.com` |
| sketchpad | `sketch.jasonaxelson.com` | `sketch-poc.jasonaxelson.com` |
| jamroom | `jamroom.jasonaxelson.com` | `jamroom-poc.jasonaxelson.com` |

All PoC DNS A records point to the new Vultr VM's IP.

---

## How Vultr Bootstrapping Works

The original deployment used [`nerves_vultr_loader`](https://github.com/fhunleth/fhunleth-buildroot-experiments/tree/main/board/nerves_vultr_loader), which exploits **Vultr's iPXE Custom Script** feature.

### The mechanism

When creating a Vultr VM, you can select "iPXE Custom Script" as the boot method. Vultr will network-boot the VM using your script. The script:

1. Downloads a minimal Linux **kernel** (`bzImage`) from S3
2. Downloads a minimal Linux **initrd** (`rootfs.cpio.xz`) from S3 — this contains `fwup` and an init script
3. Downloads the **Nerves `.fw` file** as `/root/install.fw` (also via initrd)
4. Boots this tiny Linux

Once booted, the init script (`S99load`) runs:

```sh
fwup -a -i /root/install.fw -d /dev/vda -t complete
# Then provisions SSH host keys on partition 1
# Then formats the app partition (/dev/vda4) with ext4
# Then reboots
```

After reboot, the VM boots into Nerves from `/dev/vda`.

### How the `.fw` file URL is specified

iPXE's `initrd` command accepts an optional destination path as a second argument:

```ipxe
initrd https://example.com/vps.fw /root/install.fw
```

This downloads the file over HTTPS and injects it at `/root/install.fw` inside the merged initramfs (on top of the base `rootfs.cpio.xz`). **Any publicly reachable HTTPS URL works** — it is not specific to S3. GitHub release assets, Cloudflare R2, any CDN, or even a temporary URL all work equally well.

### Disk device note

Vultr KVM VMs expose virtio block devices as `/dev/vda`. The `nerves_system_x86_64` `erlinit` config uses `/dev/rootdisk0p*` symlinks (created by erlinit at boot time, pointing at whatever device holds the root filesystem), so this is transparent — no config changes needed for `/dev/vda` vs `/dev/sda`.

---

## Can the Existing S3 Loader Be Reused?

**Probably not safely.** There are two significant issues:

### Issue 1: fwup version incompatibility (high risk)

The `nerves_vultr_loader` is a **"v0.0.1 proof of concept"** built on Linux 4.11, which dates it to approximately 2017. The `fwup` binary in the S3-hosted `rootfs.cpio.xz` is from that era — likely version 0.15.x or similar.

`nerves_system_x86_64 ~> 1.33` produces `.fw` files using **fwup 1.15.0** format. While fwup has tried to maintain backward compatibility for reading old files, an old `fwup` binary trying to write a new `.fw` file is the risky direction — new format features may be unrecognized by the old binary, causing the install to fail silently or write a corrupt image.

This can be verified by attempting a write with the old binary, but it's a real risk for a production bootstrap.

### Issue 2: Third-party infrastructure with no SLA (medium risk)

The kernel and rootfs at `files.troodon-software.com` are hosted in Frank Hunleth's personal S3 bucket. There is no guarantee of availability, and the bucket could be deleted or made private at any time. Depending on it for production bootstrapping is fragile.

### Conclusion

The `.fw` file URL is trivially replaceable (just update the third `initrd` line). The kernel and rootfs are the problem. **Recommended approach: use a fresh bootstrapping method that doesn't depend on the old loader artifacts.**

---

## Recommended Bootstrap Approach: Alpine Linux + fwup

The cleanest alternative that requires no pre-built infrastructure: boot the new VM with **Alpine Linux** (available directly in the Vultr VM creation UI), SSH in, download a static `fwup` binary from GitHub, write the firmware, and reboot.

### Why this works

- Alpine Linux is available as a standard Vultr OS option — no custom scripts or uploads needed
- `fwup` publishes static pre-built binaries for Linux x86_64 on GitHub releases
- The static binary runs on any Linux, no dependencies
- The process takes ~5 minutes and uses only official sources

### Bootstrap procedure

```sh
# 1. Create Vultr VM with Alpine Linux (standard option in Vultr UI)
#    SSH in as root

# 2. Download the fwup static binary (match version used by nerves_system_x86_64 ~> 1.33)
wget https://github.com/fwup-home/fwup/releases/download/v1.15.0/fwup_1.15.0_x86_64.tar.gz
tar xzf fwup_1.15.0_x86_64.tar.gz

# 3. Download the Nerves firmware (from GitHub release or other host)
wget https://<your-fw-url>/vps.fw

# 4. Write the firmware to the VM's disk
#    /dev/vda is Vultr's virtio disk
./fwup -a -i vps.fw -d /dev/vda -t complete

# 5. Reboot — the VM will now boot into Nerves
reboot
```

After reboot, the Alpine Linux OS is completely replaced by Nerves. SSH will come up on port 22 with the keys configured in `config/target.exs`.

### Hosting the `.fw` file

The firmware file needs to be reachable via HTTPS during the bootstrap. The simplest option:

**GitHub Releases** — attach `vps.fw` to a tagged release in this repo:

```sh
gh release create x86-poc-v1 _build/x86_64_prod/nerves/images/vps.fw \
  --title "x86_64 PoC v1" \
  --notes "Initial x86_64 PoC firmware"
```

The download URL will be:
`https://github.com/axelson/vps/releases/download/x86-poc-v1/vps.fw`

Note: if the repo is private, the URL will require authentication — use a temporary public URL (e.g. Cloudflare R2, a public S3 bucket, or a short-lived signed URL) for bootstrapping.

### Alternative: iPXE with fresh loader artifacts

If the iPXE approach is preferred (e.g., for repeatability across many VMs), build a fresh loader from source and host the artifacts yourself. The Buildroot project is at `/Users/jason/dev/forks/fhunleth-buildroot-experiments`. This produces a current `bzImage` and `rootfs.cpio.xz` with fwup 1.15.0, which you host on your own S3/R2 bucket. The iPXE script then points at your artifacts. This is more work upfront but makes subsequent VM provisioning fully automated.

---

## Local Testing with QEMU

Before deploying to Vultr, the firmware can be tested locally using QEMU. This is the recommended workflow since `nerves_system_x86_64` is designed for QEMU use.

```sh
# Build firmware
export MIX_TARGET=x86_64
export MIX_ENV=prod
mix deps.get && mix firmware

# Create a virtual disk
qemu-img create -f raw /tmp/nerves-poc.img 4G

# Write the firmware to the disk
fwup -d /tmp/nerves-poc.img _build/x86_64_prod/nerves/images/vps.fw

# Boot in QEMU
# - Port 10022 → SSH (port 22 on the VM)
# - Port 8080 → HTTP (port 80 on the VM)
qemu-system-x86_64 \
  -drive file=/tmp/nerves-poc.img,if=virtio,format=raw \
  -net nic,model=virtio \
  -net user,hostfwd=tcp::10022-:22,hostfwd=tcp::8080-:80 \
  -nographic \
  -serial mon:stdio \
  -m 2048
```

First boot takes longer — the app data partition (`/dev/vda4` → `/dev/rootdisk0p4`) is formatted with ext4 on first run.

**Access the running VM:**

```sh
# SSH
ssh -p 10022 nerves@localhost

# IEx (via SSH)
ssh -p 10022 nerves@localhost -t '/srv/erlang/bin/vps remote'
```

**OTA firmware update to QEMU:**

```sh
mix firmware.gen.script   # generates upload.sh
SSH_OPTIONS="-p 10022" ./upload.sh localhost
```

**Exit QEMU:** Run `poweroff` at the IEx prompt, or `killall qemu-system-x86_64` from another shell.

---

## Step-by-Step Plan

### Step 1: Resolve `nerves_system_br` Version Conflict

**Problem:** `nerves_system_br` is pinned to `1.30.1` for CVE-2025-32433, but `nerves_system_x86_64 ~> 1.33` requires `1.33.2`.

**Action:**
1. Check the nerves_system_br CHANGELOG to confirm `1.33.2` includes the CVE-2025-32433 fix (it almost certainly does, as the fix predates 1.33.x)
2. Update `mix.exs`:

```elixir
# Change from:
{:nerves_system_br, "1.30.1", runtime: false}

# To:
{:nerves_system_br, "1.33.2", runtime: false}
```

### Step 2: Update `nerves_system_x86_64` Dependency

Update to the current version from hex.pm:

```elixir
# Change from:
{:nerves_system_x86_64, "~> 1.13", runtime: false, targets: :x86_64},

# To:
{:nerves_system_x86_64, "~> 1.33", runtime: false, targets: :x86_64},
```

Nerves will automatically download the prebuilt system artifact from GitHub releases — no local Buildroot compilation required.

### Step 3: Update Elixir Version Requirement

`nerves_system_x86_64 ~> 1.33` requires Elixir `~> 1.17`. Update `mix.exs`:

```elixir
elixir: "~> 1.17",
```

The project already runs Elixir 1.17.2 in practice, so this is safe.

### Step 4: Refactor Target Config to Support Multiple Targets

Currently `config/target.exs` has the production domain config hard-coded. Refactor so that each target gets its own config file, imported at the bottom of `target.exs`.

**4a.** Create `config/vultr.exs` by moving the existing production domain config out of `target.exs`:

```elixir
# config/vultr.exs
import Config

endpoint_configs = [
  {:gviz, GVizWeb.Endpoint, "depviz.jasonaxelson.com"},
  {:makeup_live, MakeupLiveWeb.Endpoint, "makeuplive.jasonaxelson.com"},
  {:sketchpad, SketchpadWeb.Endpoint, "sketch.jasonaxelson.com"},
  {:jamroom, JamroomWeb.Endpoint, "jamroom.jasonaxelson.com"}
]

domains = Enum.map(endpoint_configs, fn {_, _, domain} -> domain end)

config :vps,
  http_mode: :https,
  port: 443,
  endpoint_configs: endpoint_configs,
  cert_mode: "production",
  site_encrypt_db_folder: Path.join(~w[/data site_encrypt]),
  site_encrypt_domains: ["pham.jasonaxelson.com"] ++ domains

config :vps, Vps.Repo, database: "/data/vps.db"

config :vps, VpsWeb.Endpoint,
  url: [host: "pham.jasonaxelson.com", port: 80],
  render_errors: [view: VpsWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Vps.PubSub,
  server: false
```

**4b.** Create `config/x86_64.exs` with PoC-specific domains:

```elixir
# config/x86_64.exs
import Config

endpoint_configs = [
  {:gviz, GVizWeb.Endpoint, "depviz-poc.jasonaxelson.com"},
  {:makeup_live, MakeupLiveWeb.Endpoint, "makeuplive-poc.jasonaxelson.com"},
  {:sketchpad, SketchpadWeb.Endpoint, "sketch-poc.jasonaxelson.com"},
  {:jamroom, JamroomWeb.Endpoint, "jamroom-poc.jasonaxelson.com"}
]

domains = Enum.map(endpoint_configs, fn {_, _, domain} -> domain end)

config :vps,
  http_mode: :https,
  port: 443,
  endpoint_configs: endpoint_configs,
  cert_mode: "production",
  site_encrypt_db_folder: Path.join(~w[/data site_encrypt]),
  site_encrypt_domains: ["poc.jasonaxelson.com"] ++ domains

config :vps, Vps.Repo, database: "/data/vps.db"

config :vps, VpsWeb.Endpoint,
  url: [host: "poc.jasonaxelson.com", port: 80],
  render_errors: [view: VpsWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Vps.PubSub,
  server: false
```

**4c.** At the bottom of `config/target.exs`, uncomment the import line:

```elixir
import_config "#{Mix.target()}.exs"
```

And remove the domain-specific config that's now in the per-target files.

### Step 5: Build and Test Locally with QEMU

```sh
export MIX_TARGET=x86_64
export MIX_ENV=prod
mix deps.get
mix firmware

# Write to virtual disk and boot in QEMU
qemu-img create -f raw /tmp/nerves-poc.img 4G
fwup -d /tmp/nerves-poc.img _build/x86_64_prod/nerves/images/vps.fw
qemu-system-x86_64 \
  -drive file=/tmp/nerves-poc.img,if=virtio,format=raw \
  -net nic,model=virtio \
  -net user,hostfwd=tcp::10022-:22,hostfwd=tcp::8080-:80 \
  -nographic -serial mon:stdio -m 2048
```

Verify SSH access works and the application starts. HTTP will be on `localhost:8080` (no TLS in QEMU since there's no real domain/cert — use `cert_mode: "local"` in x86_64.exs for QEMU testing if needed).

### Step 6: Host the Firmware File

Upload the firmware to GitHub Releases so it's reachable via HTTPS during bootstrap:

```sh
gh release create x86-poc-v1 _build/x86_64_prod/nerves/images/vps.fw \
  --title "x86_64 PoC v1" \
  --notes "Initial x86_64 PoC firmware for Vultr bootstrap"
```

The repo is public, so the release asset URL is directly downloadable without authentication:
`https://github.com/axelson/vps/releases/download/x86-poc-v1/vps.fw`

**What's in the firmware file?** The `.fw` is a ZIP archive containing the squashfs root filesystem (compiled Erlang release + baked-in config). It does NOT contain application secrets — those are loaded at runtime from `/data/.target.secret.exs` by `Vps.RuntimeConfigProvider`. What IS baked in: SSH authorized public keys (not sensitive), the Erlang cookie `"vps_cookie"` (already visible in `mix.exs`), domain names, and compiled BEAM files. No API keys, passwords, or TLS certificates are embedded. Since the source is already public, a public release asset adds no new exposure.

### Step 7: Bootstrap the New Vultr VM via Alpine Linux

The original `nerves_vultr_loader` iPXE approach uses ~2017 tooling (Linux 4.11, old `fwup`) stored in a third-party S3 bucket. The old `fwup` binary likely cannot write `.fw` files produced by the modern `nerves_system_x86_64 ~> 1.33`. Use **Alpine Linux** as the bootstrap environment instead — it's available directly in the Vultr OS selector and requires no custom infrastructure.

1. Create a new Vultr Cloud Compute instance:
   - Region: match the existing VM
   - Plan: match or exceed the existing VM's specs
   - **OS**: Alpine Linux

2. SSH in as `root`, then write the Nerves firmware:

```sh
# Download fwup static binary (matches version used by nerves_system_x86_64 ~> 1.33)
wget https://github.com/fwup-home/fwup/releases/download/v1.15.0/fwup_1.15.0_x86_64.tar.gz
tar xzf fwup_1.15.0_x86_64.tar.gz

# Download the Nerves firmware
wget https://github.com/axelson/vps/releases/download/x86-poc-v1/vps.fw

# Write firmware to the disk (/dev/vda is Vultr's virtio block device)
./fwup -a -i vps.fw -d /dev/vda -t complete

# Reboot — Alpine is completely replaced by Nerves
reboot
```

3. After reboot, SSH is on port 22 using the keys configured in `config/target.exs`.

### Step 9: Configure Runtime Secrets

```sh
# Copy secrets to the new VM after it boots
scp /path/to/.target.secret.exs nerves@<new-vm-ip>:/data/.target.secret.exs
```

The `Vps.RuntimeConfigProvider` loads this file at boot. You may need to reboot after copying:

```sh
ssh nerves@<new-vm-ip> 'reboot'
```

### Step 10: Configure DNS

Add A records for the PoC domains:

```
poc.jasonaxelson.com              A  <new-vm-ip>
depviz-poc.jasonaxelson.com       A  <new-vm-ip>
makeuplive-poc.jasonaxelson.com   A  <new-vm-ip>
sketch-poc.jasonaxelson.com       A  <new-vm-ip>
jamroom-poc.jasonaxelson.com      A  <new-vm-ip>
```

SiteEncrypt will obtain Let's Encrypt certificates automatically on first HTTPS request.

### Step 11: Verify the PoC

1. `https://poc.jasonaxelson.com/logs` — LogViz UI loads
2. Each sub-app at its `-poc` domain loads correctly
3. Let's Encrypt certificates are valid (not staging/self-signed)
4. SSH access works: `ssh nerves@<new-vm-ip>`
5. OTA update works: `MIX_TARGET=x86_64 MIX_ENV=prod ./upload.sh <new-vm-ip>`
6. Existing production service is unaffected

### Step 12: Cutover (After PoC Verified)

1. Update DNS: point the production domains to the new VM's IP
2. Wait for TTL to expire
3. Verify traffic on production domains hits the new VM
4. Shut down the old Vultr VM

After cutover, update `config/x86_64.exs` to use the production domains (or create a separate `config/x86_64_prod.exs` strategy). The `:vultr` target and `nerves_system_vultr` dep can be removed.

---

## Risks and Considerations

### `nerves_system_br` CVE Pin

Pinning to `1.30.1` was specifically for CVE-2025-32433 (Erlang/OTP SSH vulnerability). That CVE affects the Erlang runtime included in the system, not the Buildroot scripts themselves — so the fix is actually in the Erlang version bundled by `nerves_system_br`. Version `1.33.2` bundles a much newer Erlang/OTP (28.x) which is well past that CVE's affected range.

### QEMU vs Vultr Networking

In QEMU, the network is NATed — the VM gets a private IP and the host does port forwarding. This means:
- SiteEncrypt/Let's Encrypt cannot reach the VM (no public IP), so HTTPS with real certs won't work in QEMU
- Use `cert_mode: "local"` in `config/x86_64.exs` for QEMU testing and switch to `"production"` before Vultr deployment
- Or accept that QEMU testing is just for verifying the app starts and SSH works, not end-to-end HTTPS

### First Boot App Partition Formatting

On first boot, Nerves formats the application data partition (`/dev/rootdisk0p4`). This is expected behavior — it takes a few extra seconds and only happens once.

---

## Summary of File Changes

| File | Change |
|------|--------|
| `mix.exs` | Bump `nerves_system_x86_64` to `~> 1.33`, update `nerves_system_br` to `1.33.2`, update `elixir` to `~> 1.17` |
| `config/target.exs` | Remove hard-coded domain config; uncomment `import_config "#{Mix.target()}.exs"` at the bottom |
| `config/vultr.exs` | New file — production domain config (moved from `target.exs`) |
| `config/x86_64.exs` | New file — PoC domain config (`-poc` subdomains) |
| GitHub Releases | Upload `vps.fw` as a release asset for bootstrap download |
| DNS | A records for PoC domains → new VM IP |

---

## Quick Reference

```sh
# Build x86_64 firmware
export MIX_TARGET=x86_64 MIX_ENV=prod
mix deps.get && mix firmware
# Output: _build/x86_64_prod/nerves/images/vps.fw

# Test in QEMU
qemu-img create -f raw /tmp/nerves-poc.img 4G
fwup -d /tmp/nerves-poc.img _build/x86_64_prod/nerves/images/vps.fw
qemu-system-x86_64 \
  -drive file=/tmp/nerves-poc.img,if=virtio,format=raw \
  -net nic,model=virtio \
  -net user,hostfwd=tcp::10022-:22,hostfwd=tcp::8080-:80 \
  -nographic -serial mon:stdio -m 2048

# SSH into QEMU
ssh -p 10022 nerves@localhost

# OTA update (to QEMU or real VM)
mix firmware.gen.script
SSH_OPTIONS="-p 10022" ./upload.sh localhost   # QEMU
./upload.sh <vm-ip>                             # real VM

# Deploy to Vultr: tag a GitHub release with the .fw file, then
# create an Alpine VM, SSH in, run fwup to write firmware, reboot
```

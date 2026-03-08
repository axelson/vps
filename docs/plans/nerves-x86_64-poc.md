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

### Key insight: the loader is system-agnostic

The S3-hosted kernel and initrd are generic — they just run `fwup` against whatever `.fw` file you give them. The existing loader infrastructure (kernel + rootfs on S3 at `files.troodon-software.com`) can be **reused as-is** for the x86_64 firmware, since `nerves_system_x86_64` uses the same `fwup`-based format.

The only thing that changes between systems is the `.fw` file URL in the iPXE script.

### Disk device note

Vultr KVM VMs expose virtio block devices as `/dev/vda`. The `nerves_system_x86_64` `erlinit` config uses `/dev/rootdisk0p*` symlinks (created by erlinit at boot time, pointing at whatever device holds the root filesystem), so this is transparent — no config changes needed for `/dev/vda` vs `/dev/sda`.

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

The iPXE bootstrap needs the `.fw` file accessible via HTTPS. Options:

- **GitHub Release**: Tag a release in this repo and attach `vps.fw` as a release asset
- **S3 / Cloudflare R2**: Upload to an object storage bucket with a public URL
- **Temporary HTTP server**: For one-off bootstrapping, `ngrok http` + `python3 -m http.server` works

Example GitHub release approach:
```sh
gh release create poc-v1 _build/x86_64_prod/nerves/images/vps.fw --title "PoC v1"
# Note the download URL from the release page
```

### Step 7: Create Vultr iPXE Startup Script

In the [Vultr control panel → Startup Scripts](https://my.vultr.com/startup/), create a new script of type **PXE** with this content:

```ipxe
#!ipxe

# Download the loader's Linux kernel (reuse existing vultr loader infrastructure)
kernel https://s3.amazonaws.com/files.troodon-software.com/vultr/bzImage

# Download the loader's root filesystem (contains fwup + install script)
initrd https://s3.amazonaws.com/files.troodon-software.com/vultr/rootfs.cpio.xz

# Download the vps x86_64 firmware — UPDATE THIS URL
initrd https://<your-fw-file-url>/vps.fw /root/install.fw

boot
```

The key change from the original script is only the third `initrd` line — everything else (kernel, rootfs) is reused from the existing Vultr loader.

**Note on the S3 URLs:** These are fhunleth's publicly hosted loader images from `files.troodon-software.com`. If they are unavailable, the loader will need to be rebuilt from the `nerves_vultr_loader` Buildroot project and hosted elsewhere.

### Step 8: Create the New Vultr VM

1. In Vultr, create a new Cloud Compute instance
   - Type: Cloud Compute (shared or dedicated)
   - Region: Match the existing VM's region
   - Plan: Match or exceed the existing VM's specs
   - **Server Image**: Choose "Upload ISO" → select "iPXE Custom Script" → choose the script created in Step 7
2. The VM will boot, run the loader, write the Nerves firmware to `/dev/vda`, and reboot into Nerves
3. Wait for the reboot — SSH will become available on port 22

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

### Availability of Loader S3 Assets

The kernel and rootfs images at `files.troodon-software.com` are hosted by Frank Hunleth and are not under our control. If unavailable, the fallback is to build the `nerves_vultr_loader` Buildroot project from source and host the artifacts. The source is at `/Users/jason/dev/forks/fhunleth-buildroot-experiments`.

### QEMU vs Vultr Networking

In QEMU, the network is NATed — the VM gets a private IP and the host does port forwarding. This means:
- SiteEncrypt/Let's Encrypt cannot reach the VM (no public IP), so HTTPS with real certs won't work in QEMU
- Use `cert_mode: "local"` in `config/x86_64.exs` for QEMU testing and switch to `"production"` before Vultr deployment
- Or accept that QEMU testing is just for verifying the app starts and SSH works, not end-to-end HTTPS

### First Boot App Partition Formatting

On first boot, Nerves formats the application data partition. The `S99load` script in the loader also pre-formats it (`mke2fs -t ext4 -L appdata /dev/vda4`), so this should be a no-op or transparent on the VM.

---

## Summary of File Changes

| File | Change |
|------|--------|
| `mix.exs` | Bump `nerves_system_x86_64` to `~> 1.33`, update `nerves_system_br` to `1.33.2`, update `elixir` to `~> 1.17` |
| `config/target.exs` | Remove hard-coded domain config; uncomment `import_config "#{Mix.target()}.exs"` at the bottom |
| `config/vultr.exs` | New file — production domain config (moved from `target.exs`) |
| `config/x86_64.exs` | New file — PoC domain config (`-poc` subdomains) |
| Vultr control panel | New Startup Script with updated `.fw` URL |
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

# Deploy to Vultr: upload .fw, create iPXE script, spin up VM
```

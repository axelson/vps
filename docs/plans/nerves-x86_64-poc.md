# Plan: Migrate to nerves_system_x86_64 (PoC on Vultr)

## Overview

Convert the `:vultr` target to use the local fork of `nerves_system_x86_64` (v1.33.1) for a proof-of-concept deployment on a new Vultr VM. The existing production service stays untouched until the PoC is verified.

The local fork is at: `/Users/jason/dev/forks/nerves_system_x86_64`

---

## Context

### Current State

- The project already lists `:x86_64` in `@all_targets` and has a dependency on `nerves_system_x86_64 ~> 1.13` (hex.pm)
- The `:vultr` target uses a custom `nerves_system_vultr` (its own package)
- `nerves_system_br` is pinned to `1.30.1` (from CVE-2025-32433 fix in commit `b04d1c1`)
- The local fork of `nerves_system_x86_64` is version **1.33.1**, which requires `nerves_system_br 1.33.2`
- Production runs at `pham.jasonaxelson.com` with sub-app domains at `*.jasonaxelson.com`

### Goal

Deploy a parallel PoC instance on a **new Vultr VM** at different hostnames, using `MIX_TARGET=x86_64` with the local fork. Once verified, the PoC becomes production and the old instance is retired.

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

DNS A records for all PoC domains must point to the new Vultr VM's IP.

---

## Step-by-Step Plan

### Step 1: Resolve `nerves_system_br` Version Conflict

**Problem:** The project pins `nerves_system_br` to `1.30.1` for the CVE-2025-32433 fix, but the x86_64 fork (v1.33.1) requires `1.33.2`.

**Action:**
1. Verify that `nerves_system_br 1.33.2` includes the CVE-2025-32433 fix (check the nerves_system_br CHANGELOG)
2. If the fix is included, update `mix.exs`:

```elixir
# Remove or update this line in mix.exs deps:
# {:nerves_system_br, "1.30.1", runtime: false}
# Change to:
{:nerves_system_br, "1.33.2", runtime: false}
```

3. If the CVE is NOT fixed in 1.33.2, document the risk and decide whether to proceed (likely it is fixed, since 1.33.2 > 1.30.1 and the release timeline matches)

### Step 2: Update `nerves_system_x86_64` Dependency

In `mix.exs`, change the `:x86_64` target dependency from the hex.pm package to the local fork:

```elixir
# Change from:
{:nerves_system_x86_64, "~> 1.13", runtime: false, targets: :x86_64},

# To (using local path for PoC development):
{:nerves_system_x86_64, path: "/Users/jason/dev/forks/nerves_system_x86_64", runtime: false, targets: :x86_64},
```

**Note:** The local fork is the standard nerves-project release (v1.33.1), not a custom fork. If no customizations are needed, you can alternatively just bump the version to `~> 1.33` and use hex.pm.

### Step 3: Update Elixir Version Requirement

The nerves_system_x86_64 v1.33.1 requires Elixir `~> 1.17`. The current `mix.exs` specifies `elixir: "~> 1.9"`. Update:

```elixir
# mix.exs project/0
elixir: "~> 1.17",
```

Verify that the project and all dependencies compile against Elixir 1.17+. The project is already confirmed to use Elixir 1.17.2 in practice (from `DEVELOPMENT.md` notes), so this should be safe.

### Step 4: Create PoC Target Configuration

Create a new target config file for the x86_64 PoC at `config/x86_64.exs`:

```elixir
# config/x86_64.exs
import Config

# PoC-specific endpoint configuration with distinct domains
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

Then at the bottom of `config/target.exs`, uncomment and update the import line:

```elixir
# At the bottom of config/target.exs, uncomment:
import_config "#{Mix.target()}.exs"
```

This means when building with `MIX_TARGET=x86_64`, it imports `config/x86_64.exs` with the PoC domains, and `MIX_TARGET=vultr` continues to use the production `vultr.exs` (or inline target.exs config).

**Alternatively**, if the `import_config` approach would break the current `:vultr` target, move the existing production domain config in `target.exs` into a `config/vultr.exs` file and import it the same way.

### Step 5: Build the Firmware

```sh
# Ensure the correct Elixir/Erlang versions are active
# Elixir 1.17+, OTP 26/27

mix local.hex --force
mix local.rebar --force
mix archive.install hex nerves_bootstrap --force

export MIX_TARGET=x86_64
export MIX_ENV=prod

mix deps.get
mix compile --warnings-as-errors
mix firmware
```

The firmware will be created at:
`_build/x86_64_prod/nerves/images/vps.fw`

### Step 6: Provision the New Vultr VM

1. Create a new Vultr VM (bare metal or VPS with x86_64)
   - Recommended: Same region/tier as existing VM
   - Boot medium: The Nerves firmware image will replace the OS entirely

2. Write the firmware to the VM's disk. For Vultr, this typically requires:
   - Boot from a rescue/live ISO to get shell access
   - Use `fwup` to write the firmware to the disk
   - Or use the `mix upload` mechanism if the Vultr target supports it

   ```sh
   # From local machine, after getting disk access on the new VM:
   fwup -d /dev/sda _build/x86_64_prod/nerves/images/vps.fw
   ```

   **Note:** Consult how `nerves_system_vultr` currently handles the initial flash — the x86_64 system uses the same `fwup`-based approach, writing to `/dev/sda`.

3. Reboot the VM. On first boot, Nerves will format the application data partition (`/dev/sda4`).

### Step 7: Configure Runtime Secrets

Copy the runtime secrets file to the new VM via SSH:

```sh
# After the VM boots and SSH is accessible:
scp /path/to/.target.secret.exs root@<new-vm-ip>:/data/.target.secret.exs
```

The `Vps.RuntimeConfigProvider` will load this on the next boot.

### Step 8: Configure DNS

Add DNS A records pointing the PoC domains to the new Vultr VM's IP:

```
poc.jasonaxelson.com          A  <new-vm-ip>
depviz-poc.jasonaxelson.com   A  <new-vm-ip>
makeuplive-poc.jasonaxelson.com A <new-vm-ip>
sketch-poc.jasonaxelson.com   A  <new-vm-ip>
jamroom-poc.jasonaxelson.com  A  <new-vm-ip>
```

SiteEncrypt will automatically obtain Let's Encrypt certificates on first access.

### Step 9: Verify the PoC

1. Access `https://poc.jasonaxelson.com/logs` to verify LogViz is working
2. Test each sub-app at its PoC domain
3. Verify SSL certificates were issued by Let's Encrypt
4. Check SSH access: `ssh nerves@<new-vm-ip>`
5. Check firmware update works: `MIX_TARGET=x86_64 MIX_ENV=prod mix upload <new-vm-ip>`
6. Verify the existing production service is unaffected

### Step 10: Cutover (After PoC Verified)

Once satisfied the PoC works correctly:

1. Update DNS: point the production domains to the new VM's IP
2. Wait for TTL to expire / verify traffic is routing to the new VM
3. Shut down the old Vultr VM
4. Optionally create a `config/vultr.exs` with production domains and retire the `:vultr` target, or rename the x86_64 config to be the canonical production config

---

## Risks and Considerations

### `nerves_system_br` CVE Pin

The project previously pinned `nerves_system_br` to `1.30.1` to fix CVE-2025-32433. Before upgrading to `1.33.2`, confirm the vulnerability is addressed in that version. Check the [nerves_system_br CHANGELOG](https://github.com/nerves-project/nerves_system_br/blob/main/CHANGELOG.md).

### nerves_system_vultr vs nerves_system_x86_64

The existing `:vultr` target may have Vultr-specific customizations (e.g., serial console settings, disk device naming, networking). Review what `nerves_system_vultr` adds beyond `nerves_system_x86_64`:

- `erlinit.config` console settings (ttyS0 — same as x86_64 ✓)
- Disk naming (`/dev/rootdisk0` via erlinit — same ✓)
- Networking (VintageNet DHCP on eth0 — should work on Vultr ✓)

The x86_64 system is designed for generic x86_64 hardware and should work on Vultr VMs, which are standard x86_64 KVM-based VMs with virtio network/block devices. The Linux kernel config in the fork already includes `VIRTIO_NET` and `VIRTIO_BLK` support.

### Local Path Dependency

Using `path:` for `nerves_system_x86_64` means the system will need to be compiled from source (Buildroot), which takes significant time (30-90 minutes). Consider whether to:
- Use the path dep and build from source (most flexibility for future customization)
- Switch to hex.pm `~> 1.33` and use the prebuilt artifact (faster, less control)

For a PoC, using hex.pm `~> 1.33` is simpler and faster. Switch to path dep when customization is actually needed.

### SiteEncrypt Let's Encrypt Rate Limits

Let's Encrypt has rate limits on certificate issuance. During PoC testing, consider using the staging ACME server by setting `cert_mode: "staging"` in `config/x86_64.exs` until the PoC is ready for real traffic. Switch to `"production"` for final verification.

### Deployment Mechanism

The current `mix upload vultr` command likely uses SSH-based firmware upload (via `ssh_subsystem_fwup`). For the initial flash of the new VM, a different approach is needed since there's no Nerves running yet. Options:

1. **Vultr rescue mode**: Boot into a live Linux ISO via Vultr's rescue feature, then use `fwup` to write the firmware to `/dev/sda`
2. **QEMU local test first**: Verify the firmware works in QEMU before deploying to Vultr

After initial flash, subsequent updates use the standard `mix upload <ip>` workflow.

---

## Summary of File Changes

| File | Change |
|------|--------|
| `mix.exs` | Update `nerves_system_x86_64` dep (path or newer hex version), update `nerves_system_br` to `1.33.2`, update elixir version to `~> 1.17` |
| `config/target.exs` | Uncomment `import_config "#{Mix.target()}.exs"` at the bottom; move current domain config to `config/vultr.exs` |
| `config/vultr.exs` | New file with current production domain config (moved from target.exs) |
| `config/x86_64.exs` | New file with PoC domain config (`-poc` subdomains) |
| DNS | Add A records for PoC domains pointing to new Vultr VM IP |

---

## Quick Reference: Build and Deploy Commands

```sh
# Build for PoC
export MIX_TARGET=x86_64
export MIX_ENV=prod
mix deps.get && mix compile && mix firmware

# Test in QEMU first (optional but recommended)
qemu-img create -f raw disk.img 4G
fwup -d disk.img _build/x86_64_prod/nerves/images/vps.fw
qemu-system-x86_64 \
  -drive file=disk.img,if=virtio,format=raw \
  -net nic,model=virtio \
  -net user,hostfwd=tcp::10022-:22,hostfwd=tcp::8080-:80 \
  -nographic -serial mon:stdio -m 2048

# SSH into QEMU instance
ssh -p 10022 nerves@localhost

# OTA update to running Nerves device
mix upload <vm-ip>
```

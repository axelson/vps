# Bootstrapping a New Vultr VM

How to provision a fresh Vultr VM running this Nerves firmware from scratch.

---

## Prerequisites

- Firmware built and uploaded to GitHub Releases (see below)
- DNS A records added for all target domains
- `/data/.target.secret.exs` contents ready to deploy

---

## Step 1: Build and Upload Firmware

```sh
MIX_TARGET=x86_64 MIX_ENV=prod mix compile --warnings-as-errors && mix firmware
```

Upload to GitHub Releases (creates or overwrites the release asset):

```sh
gh release upload x86-poc-v1 _build/x86_64_prod/nerves/images/vps.fw --clobber
```

The firmware will be downloadable at:
`https://github.com/axelson/vps/releases/download/x86-poc-v1/vps.fw`

The repo is public so no authentication is needed.

---

## Step 2: Create Vultr VM and Boot Alpine ISO

1. Create a new Vultr Cloud Compute instance (match region and plan of existing VM)
2. In the **ISO** section, attach a custom ISO using this URL:
   ```
   https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/alpine-standard-3.23.3-x86_64.iso
   ```
   (Check for a newer version at `https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/`)
   - Note: you may need to download it to your host machine and upload it to the Vultr dashboard as a Custom ISO
3. Boot the VM — it will start into the Alpine live environment
4. Open the noVNC console and log in as `root` (no password)

---

## Step 3: Flash Nerves Firmware

Run this single compound command in the Alpine console:

```sh
ip link set eth0 up && udhcpc -i eth0 \
  && echo "https://dl-cdn.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories \
  && echo "https://dl-cdn.alpinelinux.org/alpine/latest-stable/main" >> /etc/apk/repositories \
  && apk update && apk add fwup e2fsprogs \
  && wget -O /root/vps.fw https://github.com/axelson/vps/releases/download/x86-poc-v1/vps.fw \
  && fwup -a -i /root/vps.fw -d /dev/vda -t complete
```

Tip: To paste into the noVNC console click the little arrow on the left of the screen and click on the clipboard icon

This will: bring up networking, add the Alpine community repo (needed for fwup), install fwup and e2fsprogs, download the firmware, write it to `/dev/vda`, and reboot.

In the Vultr dashboard navigate to your server and remove the ISO (Settings -> Custom ISO -> Remove ISO) which will cause the server to reboot into Nerves

---

## Step 4: Add DNS Records

In your DNS system where your domain is registered do the following.

Add A records pointing all domains to the new VM's IP:

| Hostname | Type | Value |
|---|---|---|
| `poc.jasonaxelson.com` | A | `<vm-ip>` |
| `depviz-poc.jasonaxelson.com` | A | `<vm-ip>` |
| `makeuplive-poc.jasonaxelson.com` | A | `<vm-ip>` |
| `sketch-poc.jasonaxelson.com` | A | `<vm-ip>` |
| `jamroom-poc.jasonaxelson.com` | A | `<vm-ip>` |

---

## Step 5: Configure Runtime Secrets

After Nerves boots, connect via the noVNC console (IEx prompt appears there due to `ctty: "tty1"`) or via SSH.

Generate and write fresh secrets:

```elixir
secret = fn -> :crypto.strong_rand_bytes(64) |> Base.encode64() end
salt = fn -> :crypto.strong_rand_bytes(32) |> Base.encode64() end

File.write!("/data/.target.secret.exs", """
import Config
config :vps, VpsWeb.Endpoint, secret_key_base: "#{secret.()}", live_view: [signing_salt: "#{salt.()}"]
config :gviz, GVizWeb.Endpoint, secret_key_base: "#{secret.()}", live_view: [signing_salt: "#{salt.()}"]
config :makeup_live, MakeupLiveWeb.Endpoint, secret_key_base: "#{secret.()}", live_view: [signing_salt: "#{salt.()}"]
config :sketchpad, SketchpadWeb.Endpoint, secret_key_base: "#{secret.()}", live_view: [signing_salt: "#{salt.()}"]
config :jamroom, JamroomWeb.Endpoint, secret_key_base: "#{secret.()}", live_view: [signing_salt: "#{salt.()}"]
""")
```

Then restart the BEAM to pick up the new config (no full reboot needed):

```elixir
:init.restart()
```

---

## Step 6: Deploy latest version

The firmware version installed in Step 5 is outdated, install the latest by folowing `DEVELOPMENT.md`

## Step 7: Issue Let's Encrypt Certificates

site_encrypt generates a self-signed cert on first boot and schedules real cert issuance for 3:32 AM UTC. To get real certs immediately:

```elixir
SiteEncrypt.force_certify(VpsWeb.Endpoint)
```

Watch the IEx console for `Certificate successfully obtained!` (via `RingLogger.attach`).

---

## Step 8: Verify

- `https://poc.jasonaxelson.com/` — loads with valid TLS cert
- `https://depviz-poc.jasonaxelson.com/` — dep_viz loads
- `https://makeuplive-poc.jasonaxelson.com/` — makeup_live loads
- `https://sketch-poc.jasonaxelson.com/` — sketchpad loads
- `https://jamroom-poc.jasonaxelson.com/` — jamroom loads
- SSH: `ssh nerves@<vm-ip>`
- OTA update: `MIX_TARGET=x86_64 MIX_ENV=prod ./upload.sh <vm-ip>`

---

## Notes

### First-boot EXT4 formatting

`nerves_runtime` automatically formats the app data partition (`/dev/vda4`) on first boot if it's unformatted. This is expected and only happens once. If it fails (EXT4 mount error in noVNC), boot Alpine ISO again and run `mkfs.ext4 /dev/vda4` manually, then reboot.

### ctty: tty1

The erlinit config uses `ctty: "tty1"` so the IEx prompt appears on the noVNC VGA console. This is intentional — Vultr has no serial console. SSH still works normally; log output from an SSH session goes to the SSH terminal.

### Restarting

- `:init.restart()` — restarts the BEAM only; re-runs config providers. Use after writing `/data/.target.secret.exs`.
- `Nerves.Runtime.reboot()` — full system reboot. Use after OTA firmware updates.

### SSH public keys are baked into the firmware

`config/target.exs` reads `~/.ssh/id_rsa.pub`, `id_ed25519.pub`, etc. from the build machine at compile time and embeds them as `authorized_keys` in the squashfs image. The firmware file therefore contains your SSH public keys. Public keys are not sensitive, but be aware that anyone who downloads `vps.fw` from the GitHub release can extract them.

### /data is a symlink to /root

The `nerves_system_x86_64` rootfs has `/data -> /root`. The app data partition is mounted at `/root` by erlinit. All paths under `/data/` (secrets, database, certs) resolve correctly through this symlink.

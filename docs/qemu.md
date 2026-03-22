# Running Locally with QEMU

## Prerequisites

- `qemu-system-x86_64` installed (`brew install qemu`)
- `fwup` installed (`brew install fwup`)
- Firmware built (see below)

## Build the Firmware

```sh
export VPS_INSTANCE=qemu MIX_TARGET=x86_64 MIX_ENV=prod
mix deps.get && mix firmware
```

Output: `_build/x86_64_prod/nerves/images/vps.fw`

## Start QEMU

```sh
./scripts/qemu.sh
```

On first run this creates a 4GB virtual disk at `/tmp/nerves-qemu.img`, flashes the firmware onto it, and boots. Subsequent runs reuse the existing disk, preserving `/data` state (database, certs, secrets).

To wipe the disk and start fresh:

```sh
./scripts/qemu.sh --fresh
```

Port mappings:
- `localhost:10022` → SSH (port 22)
- `localhost:8080` → HTTP (port 80)

**Note:** The IEx console is configured for VGA (`ctty tty1`), so it does not appear in the terminal when running with `-nographic`. Use SSH to access IEx instead (see below).

## SSH Access

```sh
ssh -p 10022 nerves@localhost
```

For a remote IEx session:

```sh
ssh -p 10022 nerves@localhost -t '/srv/erlang/bin/vps remote'
```

## Push Firmware Updates (OTA)

After rebuilding firmware, push it over SSH without reflashing the disk:

```sh
VPS_INSTANCE=qemu MIX_TARGET=x86_64 MIX_ENV=prod mix firmware
SSH_OPTIONS="-p 10022" ./upload.sh localhost
```

The device reboots automatically after the update.

## Accessing Sub-apps

main_proxy routes by `Host` header. The `qemu` instance uses `.localhost` domains. Add entries to `/etc/hosts`:

```
127.0.0.1 poc.localhost
127.0.0.1 depviz.localhost
127.0.0.1 makeuplive.localhost
127.0.0.1 sketch.localhost
127.0.0.1 jamroom.localhost
```

Then access via `http://depviz.localhost:8080/` etc. Or use `curl` with a `Host` override without touching `/etc/hosts`:

```sh
curl -H "Host: depviz.localhost" http://localhost:8080/
```

## Stopping QEMU

From the SSH session or IEx console:

```sh
poweroff
```

Or from another terminal:

```sh
killall qemu-system-x86_64
```

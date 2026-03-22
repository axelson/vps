## First-boot EXT4 formatting

`nerves_runtime` automatically formats the app data partition (`/dev/vda4`) on first boot if it's unformatted. This is expected and only happens once. If it fails (EXT4 mount error in noVNC), boot Alpine ISO again and run `mkfs.ext4 /dev/vda4` manually, then reboot.

## ctty: tty1

The erlinit config uses `ctty: "tty1"` so the IEx prompt appears on the noVNC VGA console. This is intentional — Vultr has no serial console. SSH still works normally; log output from an SSH session goes to the SSH terminal.

## Restarting

- `:init.restart()` — restarts the BEAM only; re-runs config providers. Use after writing `/data/.target.secret.exs`.
- `Nerves.Runtime.reboot()` — full system reboot. Use after OTA firmware updates.

## SSH public keys are baked into the firmware

`config/target.exs` reads `~/.ssh/id_rsa.pub`, `id_ed25519.pub`, etc. from the build machine at compile time and embeds them as `authorized_keys` in the squashfs image. The firmware file therefore contains your SSH public keys. Public keys are not sensitive, but be aware that anyone who downloads `vps.fw` from the GitHub release can extract them.

## /data is a symlink to /root

The `nerves_system_x86_64` rootfs has `/data -> /root`. The app data partition is mounted at `/root` by erlinit. All paths under `/data/` (secrets, database, certs) resolve correctly through this symlink.


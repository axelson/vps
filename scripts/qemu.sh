#!/bin/sh
# Run the x86_64 Nerves firmware in QEMU.
#
# Port mappings:
#   10022 -> 22  (SSH)
#   8080  -> 80  (HTTP)
#
# On first run, creates and flashes a virtual disk at /tmp/nerves-qemu.img.
# Subsequent runs reuse the existing disk (preserving /data state).
# Pass --fresh to wipe the disk and start over.

set -e

FIRMWARE="_build/x86_64_prod/nerves/images/vps.fw"
DISK="/tmp/nerves-qemu.img"

if [ ! -f "$FIRMWARE" ]; then
  echo "Firmware not found at $FIRMWARE — run:"
  echo "  export VPS_INSTANCE=poc3 MIX_TARGET=x86_64 MIX_ENV=prod"
  echo "  mix compile && mix firmware"
  exit 1
fi

if [ "$1" = "--fresh" ] || [ ! -f "$DISK" ]; then
  echo "Creating fresh disk image at $DISK..."
  qemu-img create -f raw "$DISK" 4G
  fwup -a -i "$FIRMWARE" -d "$DISK" -t complete
fi

echo "Booting Nerves in QEMU..."
echo "  SSH:  ssh -p 10022 nerves@localhost"
echo "  HTTP: http://localhost:8080"
echo ""

qemu-system-x86_64 \
  -drive file="$DISK",if=virtio,format=raw \
  -netdev user,id=net0,hostfwd=tcp::10022-:22,hostfwd=tcp::8080-:80 \
  -device virtio-net-pci,netdev=net0 \
  -nographic \
  -serial mon:stdio \
  -m 2048

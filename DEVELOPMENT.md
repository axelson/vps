# Development

## Bootstrapping

See `docs/bootstrapping.md` for initial bootstrapping instructions

## Deploy to production (vultr.com) with nerves_system_x86_64 (current)

Build and upload — set `VPS_INSTANCE` to select the domain config:

```sh
# poc3
export VPS_INSTANCE=poc3 MIX_TARGET=x86_64 MIX_ENV=prod
mix compile --warnings-as-errors && mix firmware && ./upload.sh vultr

# production
export VPS_INSTANCE=production MIX_TARGET=x86_64 MIX_ENV=prod
mix compile --warnings-as-errors && mix firmware && ./upload.sh vultr
```

If `upload.sh` doesn't exist, generate it first:

```sh
MIX_TARGET=x86_64 MIX_ENV=prod mix firmware.gen.script
```

## Deploy to qemu (development)

```
export MIX_TARGET=x86_64 MIX_ENV=prod VPS_INSTANCE=qemu
./scripts/qemu-run.sh [--fresh]
mix compile --warnings-as-errors && mix firmware && ./scripts/qemu-upload.sh
./scripts/qemu-ssh.sh
```

Visit http://localhost:8080

## Troubleshooting

If the ssl settings are not applied correctly then re-compile the deps

```
mix deps.compile gviz makeup_live sketchpad jamroom --force
```

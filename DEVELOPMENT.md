# Development

## Deploy to x86_64 (current)

Build and upload — set `VPS_INSTANCE` to select the domain config:

```sh
# poc3 (default)
export VPS_INSTANCE=poc3 MIX_TARGET=x86_64 MIX_ENV=prod
mix compile --warnings-as-errors && mix firmware && ./upload.sh 144.202.117.48

# production
export VPS_INSTANCE=production MIX_TARGET=x86_64 MIX_ENV=prod
mix compile --warnings-as-errors && mix firmware && ./upload.sh vultr
```

If `upload.sh` doesn't exist, generate it first:

```sh
MIX_TARGET=x86_64 MIX_ENV=prod mix firmware.gen.script
```

## Deploy to vultr (legacy, retired)

```sh
set -x MIX_TARGET vultr; set -x MIX_ENV prod
mix compile --warnings-as-errors && mix firmware && mix upload vultr
```

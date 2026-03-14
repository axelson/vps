# Development

## Deploy to x86_64 (current)

Build and upload:

```sh
MIX_TARGET=x86_64 MIX_ENV=prod mix compile --warnings-as-errors && mix firmware && ./upload.sh 149.248.17.84
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

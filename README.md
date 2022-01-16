# Vps

Deploy with:

``` sh
set -x MIX_TARGET vultr; set -x MIX_ENV prod
mix compile --warnings-as-errors && mix firmware && mix upload vultr
```

Run locally with:

``` sh
mix deps.get
iex -S mix phx.server
```

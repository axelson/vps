# File hosting app

## Goal

Add a standalone, extractable Phoenix app to this repo that hosts my static HTML/JS
bundles at `files.jasonaxelson.com`, plus a `/public-file-hosting` skill to publish them.

## Approach

The behavior and decisions live in `apps/file_hosting/docs/design.md`. Implementation:

- Hand-written slim Phoenix app (no Ecto, HTML, assets, LiveView): an endpoint with no
  session or body parsers, a router with an authenticated `/_api` scope, and a bundle
  controller that serves files itself (Plug.Static can't serve directory `index.html`
  or redirect `/<name>` → `/<name>/`).
- `FileHosting.Store` GenServer serializes writes (quota check + symlink swap). Reads go
  straight to the filesystem.
- Upload validation inspects the tarball with `:erl_tar.table/2` (types, paths, sizes)
  before extracting anything.
- `vps` wires it in the same way as the GitHub sub-apps: an `endpoint_configs` entry
  and per-environment endpoint config.

## Changes

`apps/file_hosting/` (new standalone Mix project):

- `mix.exs`, `.formatter.exs`, `.gitignore`, `config/{config,dev,test,runtime}.exs` — for
  standalone dev/test; inside `vps` the root config applies.
- `lib/file_hosting/application.ex` — starts the Store and the endpoint.
- `lib/file_hosting/store.ex` — storage layout, publish/delete/list/get, quota, startup cleanup.
- `lib/file_hosting/bundle_archive.ex` — tarball validation and extraction.
- `lib/file_hosting/name.ex` — name validation.
- `lib/file_hosting_web/{endpoint,router}.ex`.
- `lib/file_hosting_web/plugs/require_token.ex` — bearer auth, fail closed.
- `lib/file_hosting_web/controllers/{api_controller,bundle_controller}.ex`.
- `test/` — store, archive, API and serving tests.
- `skill/` — `SKILL.md`, `scripts/{publish,list,delete,preview,lint,common.sh}`,
  `lint/` Go source.
- `docs/design.md`.

`vps`:

- `mix.exs` — add the path dep.
- `config/host.exs`, `config/target.exs`, `config/x86_64.exs` — endpoint configs,
  storage dir, dev token, `files.*` domains.
- `README.md` — pointer to the design doc.

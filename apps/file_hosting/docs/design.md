# File Hosting — Design

`file_hosting` publishes static HTML/JS bundles at `https://files.jasonaxelson.com/<name>/`.
It has one user, is driven by an HTTP API (no admin UI), and is published to by the
`/public-file-hosting` Claude skill in `skill/`.

The app is a standalone Mix project so it can be extracted from the `vps` repo: move
`apps/file_hosting` to its own repo and change the `vps` dep from `path:` to `github:`.

## Content model

- A **bundle** is a directory of static files with a top-level `index.html`, served
  under `/<name>/`. A single uploaded file is a one-file bundle (`index.html`).
- Static only: files are served as-is with a MIME type from their extension. No
  server-side code, no SPA fallback — a missing path is a plain 404.
- `/<name>` redirects to `/<name>/` so relative paths in `index.html` resolve under the
  bundle. A directory path inside a bundle (`/<name>/sub/`) serves its `index.html`.
- There is no public index: `/` is a 404 and bundles are only discoverable by URL.

## Names

- Flat, one path segment, `^[a-z0-9][a-z0-9-]{0,79}$`. Names can't start with `_` or
  `.`, which keeps `/_api` reserved.
- The skill defaults to `YYYY-MM-DD-<slug>` (today's date plus a slug of the file or
  directory name); an explicit name overrides it, with no date.

## API

All `/_api` routes require `Authorization: Bearer <token>`.

| Route | Behavior |
| --- | --- |
| `PUT /_api/bundles/:name` | Body is a `.tar.gz` of the bundle. Creates or replaces it in place. |
| `GET /_api/bundles` | Lists bundle metadata. |
| `GET /_api/bundles/:name` | One bundle's metadata, or 404. |
| `DELETE /_api/bundles/:name` | Deletes the bundle. |

Upload rules (violations are rejected with a 4xx and nothing changes):

- Request body ≤ 25 MB, and the extracted total ≤ 25 MB.
- Only regular files and directories; no symlinks, absolute paths, or `..`.
- A top-level `index.html` is required.
- All bundles together stay ≤ 1 GB (the replaced bundle's old size doesn't count).

## Auth

A single static bearer token, compared in constant time
(`Plug.Crypto.secure_compare/2`). When no token is configured every API request is
rejected (fail closed).

- Device: `config :file_hosting, api_token: "..."` in `/data/.target.secret.exs`.
- Laptop: macOS Keychain, service `file-hosting`
  (`security find-generic-password -s file-hosting -w`). `FILE_HOSTING_TOKEN` overrides
  it.
- Rotation: edit the secret file, `:init.restart()`, update the Keychain item.

## Origin and headers

Every bundle shares the `files.jasonaxelson.com` origin, so bundles can read each
other's `localStorage`. This is accepted: the content is all mine. API auth never uses
cookies and the endpoint sets none, so hosted JS can't act with my credentials. If
untrusted content is ever hosted, per-bundle `Content-Security-Policy: sandbox` is the
upgrade path (it costs that bundle `localStorage`, cookies, and same-origin `fetch`).

Bundle responses send `Cache-Control: no-cache`, an `ETag` (with `304` on
`If-None-Match`), and `X-Content-Type-Options: nosniff`.

## Storage

Rooted at `storage_dir` (`/data/file-hosting` on the device, `tmp/file-hosting` on host):

```
bundles/<name>  -> ../versions/<name>.<id>   symlink; the served bundle
versions/<name>.<id>/                         bundle files
meta/<name>.json                              created_at, updated_at, size_bytes, file_count
staging/                                      in-flight uploads
```

A publish extracts into `staging/`, moves it to `versions/`, then atomically swaps the
`bundles/<name>` symlink (`rename(2)` of a fresh symlink), so readers never see a
half-written bundle. The old version is deleted afterwards. `meta/` is outside the
served tree; `created_at` survives replaces, so a bundle's age is readable with
`cat meta/<name>.json`. On startup, `staging/` and unreferenced `versions/` are cleaned
up.

## The skill

`skill/` holds the `/public-file-hosting` skill; `~/.claude/skills/public-file-hosting`
symlinks to it. Scripts do the mechanical work to keep context small:

- `scripts/lint` — Go (stdlib only), compiled to `skill/bin/` on first use and rebuilt
  when its source changes. Flags a missing `index.html`, root-absolute references
  (`src="/x"`, `url(/x)`, `fetch("/x")`), local references to files not in the bundle,
  and size over the cap; lists external URLs.
- `scripts/publish`, `scripts/list`, `scripts/delete` — bash + `curl` + `tar`.
- `scripts/preview` — serves the bundle locally under `/<name>/` for a browser check.

Flow: lint → Claude fixes errors → browser check for multi-file bundles → confirm before
overwriting an existing name → upload → print the URL and `pbcopy` it.
`FILE_HOSTING_URL` points the scripts at another server (e.g. `http://files.localhost:4000`).

## Wiring into vps

The `vps` firmware includes it as `{:file_hosting, path: "apps/file_hosting"}`. Its
endpoint runs with `server: false`; `VpsWeb.MyProxy` routes the hostname to it via the
`:endpoint_configs` entry `{:file_hosting, FileHostingWeb.Endpoint, "<host>"}`.

Dev: `files.localhost:4000`, token `dev-token`, storage in `tmp/file-hosting/`.

### Production checklist

1. DNS A record for `files.jasonaxelson.com` → the VPS. Do this **before** deploying:
   site_encrypt requests one certificate for all domains, so an unresolvable domain
   breaks issuance for every site.
2. Add `{:file_hosting, FileHostingWeb.Endpoint, "files.jasonaxelson.com"}` to
   `endpoint_configs`, and the domain to `site_encrypt_domains`, in both
   `config/x86_64.exs` (done) and the device's `/data/.target.secret.exs`.
3. In `/data/.target.secret.exs`:
   ```elixir
   config :file_hosting, api_token: "<random>"
   config :file_hosting, FileHostingWeb.Endpoint, secret_key_base: "<random>"
   ```
4. Deploy the firmware, then `:init.restart()`.
5. `security add-generic-password -s file-hosting -a "$USER" -w '<token>'` on the laptop.

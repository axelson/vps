---
name: public-file-hosting
description: Publish static HTML/JS to files.jasonaxelson.com as a public, shareable URL; also list or delete published bundles. Use when asked to publish, host, share, or put online a page, file, or directory.
---

# Public file hosting

Publishes a **bundle** — one `.html` file, or a directory with a top-level
`index.html` — to `https://files.jasonaxelson.com/<name>/`. Anyone with the URL can
view it; there is no index page. Design: `../docs/design.md`.

All scripts are in `scripts/` next to this file. `FILE_HOSTING_URL` points them at
another server (`http://files.localhost:4000` for the local dev server).

## Publish

1. **Pick the target.** A path the user gave, or what you just built in this
   conversation. A page with sibling assets is published as its directory; a fully
   self-contained `.html` file is published alone (it becomes `index.html`).

2. **Lint until clean.** Run `scripts/lint <target>`. Fix every `ERROR` in the
   content, then re-run; done when it reports 0 errors.
   - Root-absolute reference (`/app.js`) → make it relative (`app.js`, `../app.js`).
     The bundle lives under `/<name>/`, so `/` points outside it.
   - Missing file → copy it into the bundle, inline it, or fix the path.
   - Single file with local references → publish the directory instead, or inline them.
   - `WARN` lines: resolve or confirm each one is intended (e.g. a bare import backed
     by an import map).
   - `EXTERNAL` lines: tell the user which outside URLs the page depends on.

   When the content is the user's own files, say what you changed.

3. **Check it in a browser** (multi-file bundles, or a single file that runs JS).
   Start `scripts/preview <target>` in the background; it prints a
   `http://localhost:8765/preview/` URL that mirrors the `/<name>/` layout. Open it
   with the Chrome DevTools MCP and check the console and network panel. Done when the
   page renders with no console errors and no failed requests to bundle files. Stop
   the preview afterwards.

4. **Upload.** `scripts/publish <target> [--name NAME]`.
   - The default name is `YYYY-MM-DD-<slug>`; pass `--name` when the user asked for a
     specific one (no date is added then). Names: 1–80 of `a-z`, `0-9`, `-`.
   - Exit code 3 means the name is taken: show the user the line it printed and ask
     whether to replace it. Only on a yes, re-run with `--yes`.
   - On success it prints the URL and copies it to the clipboard. Give the user the URL.

## List and delete

- `scripts/list` — every bundle with its last update, size, and file count.
- `scripts/delete <name>` — removes a bundle. Confirm the exact name with the user
  first; deletion is permanent.

## Token

The scripts read the API token from `FILE_HOSTING_TOKEN`, else the macOS Keychain
item `file-hosting`. If a script reports the token is missing, give the user the
`security add-generic-password` command it printed; never ask for the token in chat.

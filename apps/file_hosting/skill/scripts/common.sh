# Shared settings for the file hosting scripts. Source, don't execute.
set -euo pipefail

FILE_HOSTING_URL="${FILE_HOSTING_URL:-https://files.jasonaxelson.com}"
FILE_HOSTING_URL="${FILE_HOSTING_URL%/}"

die() { echo "error: $*" >&2; exit 1; }

token() {
  if [[ -n "${FILE_HOSTING_TOKEN:-}" ]]; then
    printf '%s' "$FILE_HOSTING_TOKEN"
  else
    security find-generic-password -s file-hosting -w 2>/dev/null ||
      die "no token: set FILE_HOSTING_TOKEN or add it to the Keychain with
  security add-generic-password -s file-hosting -a \"\$USER\" -w '<token>'"
  fi
}

# api METHOD PATH [curl args...] — prints the body, then the status code on its own line.
api() {
  local method=$1 path=$2
  shift 2
  curl -sS -X "$method" -H "Authorization: Bearer $(token)" -w '\n%{http_code}' "$@" \
    "$FILE_HOSTING_URL/_api$path"
}

# Splits api output: sets BODY and STATUS.
split_response() {
  STATUS=$(tail -n1 <<<"$1")
  BODY=$(sed '$d' <<<"$1")
}

valid_name() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,79}$ ]]; }

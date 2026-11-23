#!/bin/bash
# Publish a sanitized snapshot of this repo to the public GitHub repo.
#
# The working repo (origin, private) keeps full history. The public repo never
# receives that history: each publish is one new commit whose tree is a filtered
# export of REF, stacked on the previous public commit. No force push, ever.
#
#   scripts/publish-public.sh            # dry run: build, gate, show the diff
#   scripts/publish-public.sh --push     # also commit and push to the public repo
#
# Gates (any failure stops the publish):
#   1. Paths listed in .public-exclude are stripped and no .DS_Store survives.
#   2. No text file matches the external private denylist ($DENYLIST).
#   3. No text file matches generic leak regexes (emails, local /Users/<user>, keys, etc.).
#   4. Every image has its sha256 listed in $IMAGES_OK.
#   5. gitleaks reports zero findings on the exported tree.
#   6. Standalone Python tests (examples/byo-backend) pass cleanly.
set -euo pipefail

PUSH=0
if [ $# -gt 1 ]; then
  echo "Usage: $0 [--push]" >&2
  exit 2
fi
case "${1:-}" in
  "") ;;
  --push) PUSH=1 ;;
  *)
    echo "Usage: $0 [--push]" >&2
    exit 2
    ;;
esac

REF=${REF:-main}
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(git rev-parse --show-toplevel 2>/dev/null || git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel)
PUBLIC_DIR=${ONTO_RADIO_PUBLIC_DIR:-$HOME/Projects/onto-the-radio-public}
IDENT_NAME="todd866"
IDENT_EMAIL="todd866@users.noreply.github.com"

cd "$REPO"

# Resolve external denylist (read-only; never print its contents).
DENYLIST="${PUBLIC_DENYLIST:-$HOME/.config/onto-the-radio/public-denylist.txt}"
if [ -n "${PUBLIC_DENYLIST:-}" ] && [ ! -f "$DENYLIST" ]; then
  echo "BLOCKED: PUBLIC_DENYLIST not found: $DENYLIST" >&2
  exit 2
fi

IMAGES_OK="${PUBLIC_IMAGES_OK:-$REPO/scripts/public-images-approved.txt}"
if [ ! -f "$IMAGES_OK" ]; then
  echo "BLOCKED: missing approved images file: $IMAGES_OK" >&2
  exit 2
fi

for cmd in rg gitleaks python3 shasum rsync; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: missing required command: $cmd" >&2; exit 2; }
done

# Preflight safety checks on private and public repos.
if [ -n "$(git -C "$REPO" status --porcelain --untracked-files=no)" ]; then
  echo "BLOCKED: tracked files in $REPO have uncommitted changes." >&2
  exit 2
fi

if ! git -C "$REPO" rev-parse --verify --quiet "$REF^{commit}" >/dev/null; then
  echo "BLOCKED: ref '$REF' is not a valid commit in $REPO." >&2
  exit 2
fi

if [ ! -d "$PUBLIC_DIR/.git" ]; then
  echo "BLOCKED: public repo missing at $PUBLIC_DIR (.git not found)." >&2
  exit 2
fi

REPO_ORIGIN=$(git -C "$REPO" remote get-url origin 2>/dev/null || true)
PUBLIC_ORIGIN=$(git -C "$PUBLIC_DIR" remote get-url origin 2>/dev/null || true)
if [ -z "$PUBLIC_ORIGIN" ]; then
  echo "BLOCKED: $PUBLIC_DIR has no origin remote." >&2
  exit 2
fi
if [ -n "$REPO_ORIGIN" ] && [ "$PUBLIC_ORIGIN" = "$REPO_ORIGIN" ]; then
  echo "BLOCKED: $PUBLIC_DIR origin matches private repo origin ($PUBLIC_ORIGIN)." >&2
  exit 2
fi
case "$PUBLIC_ORIGIN" in
  *-private*)
    echo "BLOCKED: $PUBLIC_DIR origin matches *-private* ($PUBLIC_ORIGIN)." >&2
    exit 2
    ;;
esac

EXPORT=$(mktemp -d "${TMPDIR:-/tmp}/onto-radio-public.XXXXXX")
trap 'rm -rf "$EXPORT"' EXIT
git -C "$REPO" archive "$REF" | tar -x -C "$EXPORT"

# Gate 1: .public-exclude + .DS_Store check.
if [ -f "$EXPORT/.public-exclude" ]; then
  while IFS= read -r pat || [ -n "$pat" ]; do
    pat=${pat%$'\r'}
    case "$pat" in ''|\#*) continue ;; esac
    case "$pat" in
      /*|*..*) echo "BLOCKED: unsafe .public-exclude pattern: $pat" >&2; exit 2 ;;
    esac
    (
      cd "$EXPORT"
      shopt -s nullglob dotglob
      for p in $pat; do
        if [ -e "$p" ] || [ -L "$p" ]; then
          rm -rf -- "$p"
        fi
      done
    ) || true
    # Fail closed: nothing a listed pattern names may survive the removal.
    if (
      cd "$EXPORT"
      shopt -s nullglob dotglob
      for p in $pat; do
        if [ -e "$p" ] || [ -L "$p" ]; then
          exit 0
        fi
      done
      exit 1
    ); then
      echo "BLOCKED: excluded path still present: $pat" >&2
      exit 1
    fi
  done < "$EXPORT/.public-exclude"
fi

if ds=$(find "$EXPORT" -name '.DS_Store' -print -quit) && [ -n "$ds" ]; then
  echo "BLOCKED: .DS_Store present in export: ${ds#$EXPORT/}" >&2
  exit 1
fi

fail=0

# Gate 2: External denylist scan (print only filenames on match; exit >1 is error).
if [ -f "$DENYLIST" ]; then
  if ! grep -E -q -v '^(#|[[:space:]]*$)' "$DENYLIST"; then
    echo "BLOCKED: public denylist contains no active patterns." >&2
    exit 2
  fi
  rg_rc=0
  hits=$(cd "$EXPORT" && rg -P -i -l --hidden -f <(grep -v '^#' "$DENYLIST" | grep -v '^[[:space:]]*$') . 2>/dev/null) || rg_rc=$?
  case "$rg_rc" in
    0)
      echo "BLOCKED: private terms matched in:" >&2
      printf '%s\n' "$hits" | sed 's/^/  /' >&2
      fail=1
      ;;
    1)
      ;;
    *)
      echo "ERROR: denylist scan failed (rg exit $rg_rc)." >&2
      exit 2
      ;;
  esac
else
  echo "Gate 2: no repo-specific denylist at $DENYLIST; skipping custom term list."
fi

# Gate 3: Generic leak regexes via inline Python.
if ! python3 - "$EXPORT" <<'PY'; then
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])

EMAIL_RE = re.compile(r"(?<![A-Za-z0-9._%+-])([A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,})(?![A-Za-z0-9.-])")
ASSET_SCALE_RE = re.compile(r"^[123]x\.(png|jpe?g|gif|webp|icns|svg|pdf)$", re.IGNORECASE)
USERS_RE = re.compile(r"/Users/([A-Za-z0-9_][A-Za-z0-9._-]*)")
HOST_RE = re.compile(r"ian" + r"todd" + r"s\x2dmacbook\x2dair", re.IGNORECASE)
TAILNET_RE = re.compile(r"\btail[0-9a-f]+\.ts\.net\b", re.IGNORECASE)
PEM_KEY_RE = re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")
R2_RE = re.compile(r"[0-9a-f]{32}\.r2\.cloudflarestorage\.com", re.IGNORECASE)
AIZA_RE = re.compile(r"AIza[0-9A-Za-z_-]{30,}")
SK_RE = re.compile(r"(?<![A-Za-z0-9_-])sk-(?:proj-|svcacct-)?[0-9A-Za-z]{20,}")

ALLOWED_EMAIL_DOMAINS = {"users.noreply.github.com", "example.com"}

findings = []

for path in sorted(root.rglob("*")):
    if not path.is_file() or path.is_symlink():
        continue
    data = path.read_bytes()
    if b"\x00" in data:
        continue
    text = data.decode("utf-8", errors="replace")
    rel = path.relative_to(root).as_posix()

    for lineno, line in enumerate(text.splitlines(), 1):
        for m in EMAIL_RE.finditer(line):
            addr = m.group(1)
            _, domain = addr.rsplit("@", 1)
            if domain.lower() in ALLOWED_EMAIL_DOMAINS:
                continue
            if ASSET_SCALE_RE.match(domain):
                continue
            findings.append(f"{rel}:{lineno}: personal email")
        for m in USERS_RE.finditer(line):
            if m.group(1) != "example":
                findings.append(f"{rel}:{lineno}: local /Users/ path")
        if HOST_RE.search(line):
            findings.append(f"{rel}:{lineno}: local machine hostname")
        if TAILNET_RE.search(line):
            findings.append(f"{rel}:{lineno}: tailnet hostname")
        if PEM_KEY_RE.search(line):
            findings.append(f"{rel}:{lineno}: PEM private key header")
        if R2_RE.search(line):
            findings.append(f"{rel}:{lineno}: R2 account endpoint")
        if AIZA_RE.search(line):
            findings.append(f"{rel}:{lineno}: Google API key pattern")
        if SK_RE.search(line):
            findings.append(f"{rel}:{lineno}: sk- token pattern")

if findings:
    print("BLOCKED: generic leak scan matched:", file=sys.stderr)
    for item in findings:
        print(f"  {item}", file=sys.stderr)
    sys.exit(1)
PY
  fail=1
fi

# Gate 4: Image SHA-256 allowlist.
while IFS= read -r -d '' img; do
  sum=$(shasum -a 256 "$img" | cut -d' ' -f1)
  if ! grep -q -E "^${sum}([[:space:]]|$)" "$IMAGES_OK"; then
    echo "BLOCKED: unreviewed image ${img#$EXPORT/} ($sum)" >&2
    fail=1
  fi
done < <(find "$EXPORT" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.icns' -o -iname '*.svg' \) -print0)

# Gate 5: gitleaks scan on exported tree.
if ! gitleaks dir "$EXPORT" --no-banner --exit-code 1; then
  echo "BLOCKED: gitleaks failed on exported tree." >&2
  fail=1
fi

# Gate 6: Standalone Python tests.
if ! PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$EXPORT/examples/byo-backend" -v; then
  echo "BLOCKED: standalone byo-backend tests failed." >&2
  fail=1
fi

[ $fail -eq 0 ] || { echo "Nothing published." >&2; exit 1; }
echo "All 6 gates passed: $(cd "$EXPORT" && find . -type f | wc -l | tr -d ' ') files from $REF ($(git -C "$REPO" rev-parse --short "$REF"))."

# Sync into $PUBLIC_DIR cleanly from origin/main.
git -C "$PUBLIC_DIR" fetch -q origin main
git -C "$PUBLIC_DIR" checkout -q -B main origin/main
git -C "$PUBLIC_DIR" reset -q --hard origin/main

rsync -a --delete --exclude .git "$EXPORT"/ "$PUBLIC_DIR"/
git -C "$PUBLIC_DIR" add -A

if [ $PUSH -eq 0 ]; then
  if git -C "$PUBLIC_DIR" diff --cached --quiet; then
    echo "Dry run: public repo already matches $REF."
  else
    git -C "$PUBLIC_DIR" diff --cached --stat
  fi
  git -C "$PUBLIC_DIR" reset -q --hard origin/main
  if [ -n "$(git -C "$PUBLIC_DIR" status --porcelain)" ]; then
    echo "ERROR: $PUBLIC_DIR not clean after dry-run restore." >&2
    exit 2
  fi
  echo "Dry run clean. Re-run with --push to publish."
  exit 0
fi

if git -C "$PUBLIC_DIR" diff --cached --quiet; then
  echo "Public repo already matches $REF."
  exit 0
fi

git -C "$PUBLIC_DIR" diff --cached --stat | tail -1
GIT_AUTHOR_NAME="$IDENT_NAME" GIT_AUTHOR_EMAIL="$IDENT_EMAIL" \
GIT_COMMITTER_NAME="$IDENT_NAME" GIT_COMMITTER_EMAIL="$IDENT_EMAIL" \
  git -C "$PUBLIC_DIR" -c commit.gpgsign=false commit -q \
    -m "Snapshot of $(git -C "$REPO" rev-parse --short "$REF") ($(date -u +%Y-%m-%d))"

git -C "$PUBLIC_DIR" log -1 --format='%an <%ae> / %cn <%ce>' | grep -qv gmail
git -C "$PUBLIC_DIR" push origin main

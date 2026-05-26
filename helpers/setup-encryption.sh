#!/usr/bin/env bash
# setup-encryption — generate a full Age + EJSON encryption chain for a
# dotfiles profile.
#
# Generates in CWD: age_key_<profile>.age, ejson_key_<profile>.age, and
# (if not deploying) writes a sealed evault skeleton + a public-keys.txt
# summary file.
#
# Usage:
#   ./setup-encryption.sh <personal|work> [--deploy [--repo /path]] [--force]
#
# Examples:
#   # Generate keys + evault in CWD (no repo touched)
#   ./setup-encryption.sh personal
#
#   # Generate + auto-deploy to dotfiles repo (chezmoi source-path used)
#   ./setup-encryption.sh personal --deploy
#
#   # Generate + deploy to explicit repo path
#   ./setup-encryption.sh work --deploy --repo ~/devel/homelab/dotfiles
#
#   # Overwrite existing files
#   ./setup-encryption.sh personal --force

set -uo pipefail

# ───── Colors ────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { printf "${GREEN}✓ %s${NC}\n" "$*"; }
err()  { printf "${RED}✗ %s${NC}\n" "$*" >&2; }
warn() { printf "${YELLOW}⚠ %s${NC}\n" "$*"; }
info() { printf "${BLUE}ℹ %s${NC}\n" "$*"; }
step() { printf "\n${BLUE}━━━ %s ━━━${NC}\n" "$*"; }

die() { err "$*"; exit 1; }

usage() {
    cat <<EOF
Usage: $(basename "$0") <personal|work> [options]

Generates a complete Age + EJSON encryption chain for a dotfiles profile.

Arguments:
  personal | work      Which profile to set up

Options:
  --deploy             Copy generated files into the dotfiles repo and
                       update .chezmoi.yaml.tmpl placeholders
  --repo <path>        Dotfiles DEVELOPMENT repo path (where you 'git commit').
                       Falls back to \$DOTFILES_REPO env var, then interactive
                       prompt. Do NOT use chezmoi's source-path
                       (~/.local/share/chezmoi) — those are managed copies.
  --force              Overwrite existing output files in CWD
  -h, --help           Show this message

The script will prompt for the Age passphrase interactively (twice — encrypt
and verify). Save the passphrase to a password manager BEFORE running this
script; if you lose it, the profile is unrecoverable.
EOF
}

# ───── Argument parsing ──────────────────────────────────────────────────────

PROFILE=""
DO_DEPLOY=0
EXPLICIT_REPO=""
FORCE=0

while [ $# -gt 0 ]; do
    case "$1" in
        personal|work)
            [ -n "${PROFILE}" ] && die "Profile already set to '${PROFILE}' — only one allowed"
            PROFILE="$1"
            ;;
        --deploy)
            DO_DEPLOY=1
            ;;
        --repo)
            EXPLICIT_REPO="${2:-}"
            [ -z "${EXPLICIT_REPO}" ] && die "--repo requires a path argument"
            shift
            ;;
        --force)
            FORCE=1
            ;;
        -h|--help)
            usage; exit 0
            ;;
        *)
            err "Unknown argument: $1"
            usage; exit 1
            ;;
    esac
    shift
done

[ -z "${PROFILE}" ] && { usage; die "Missing positional argument: profile"; }

# ───── Tool availability ─────────────────────────────────────────────────────

for tool in age ejson chezmoi; do
    command -v "${tool}" >/dev/null 2>&1 || die "Required tool '${tool}' not found on PATH"
done

# ───── Resolve dotfiles repo (if --deploy) ───────────────────────────────────
#
# IMPORTANT: chezmoi source-path returns the chezmoi-managed working copy
# (~/.local/share/chezmoi by default), NOT your development repo. Writing
# generated key files there would get overwritten by the next `chezmoi
# update`. Always deploy to the development repo (where you `git commit`).
#
# Resolution order (first match wins):
#   1. --repo <path>                           (explicit, always wins)
#   2. $DOTFILES_REPO env var
#   3. Interactive prompt (last resort)

REPO=""
if [ "${DO_DEPLOY}" -eq 1 ]; then
    if [ -n "${EXPLICIT_REPO}" ]; then
        REPO="${EXPLICIT_REPO}"
    elif [ -n "${DOTFILES_REPO:-}" ]; then
        REPO="${DOTFILES_REPO}"
        info "Using \$DOTFILES_REPO: ${REPO}"
    else
        warn "No deploy target specified. Provide one of:"
        warn "  --repo /path/to/dev-repo            (recommended)"
        warn "  DOTFILES_REPO=/path env var"
        warn ""
        warn "Note: do NOT use chezmoi's source-path (~/.local/share/chezmoi)."
        warn "      That is chezmoi's working copy — your edits would get reset."
        warn "      Use your DEVELOPMENT repo where you 'git commit'."
        warn ""
        printf "Enter dotfiles development repo path: "
        read -r REPO
    fi

    [ -d "${REPO}" ] || die "Repo path does not exist: ${REPO}"
    [ -f "${REPO}/.chezmoi.yaml.tmpl" ] || die "Not a dotfiles repo (missing .chezmoi.yaml.tmpl): ${REPO}"
    [ -d "${REPO}/.git" ] || warn "Repo path has no .git/ — sure this is your dev repo? Continuing anyway."

    # Safety check — refuse to write into chezmoi-managed state
    CHEZMOI_STATE=$(chezmoi source-path 2>/dev/null || true)
    if [ -n "${CHEZMOI_STATE}" ] && [ "$(realpath "${REPO}" 2>/dev/null)" = "$(realpath "${CHEZMOI_STATE}" 2>/dev/null)" ]; then
        die "Refusing to deploy: target '${REPO}' is chezmoi's managed source-path. Use your dev repo instead."
    fi

    info "Deploy target: ${REPO}"
fi

# ───── Pre-flight: refuse to overwrite ───────────────────────────────────────

OUT_AGE_KEY="age_key_${PROFILE}.age"
OUT_EJSON_KEY="ejson_key_${PROFILE}.age"
OUT_EVAULT="evault_${PROFILE}.json"
OUT_PUB_KEYS="public-keys-${PROFILE}.txt"

if [ "${FORCE}" -eq 0 ]; then
    for f in "${OUT_AGE_KEY}" "${OUT_EJSON_KEY}" "${OUT_EVAULT}" "${OUT_PUB_KEYS}"; do
        [ -e "${f}" ] && die "Output file '${f}' already exists. Use --force to overwrite."
    done
fi

# ───── Tmpfs workspace for plaintext keys ────────────────────────────────────

if [ -d /dev/shm ] && [ -w /dev/shm ]; then
    WORK_BASE=/dev/shm
else
    WORK_BASE=/tmp
    warn "/dev/shm unavailable, falling back to /tmp (plaintext keys may touch disk)"
fi
WORK="${WORK_BASE}/setup-encryption-${PROFILE}-$$"
mkdir -p "${WORK}" && chmod 700 "${WORK}"

# Always shred plaintext on exit (success or failure)
cleanup() {
    if [ -d "${WORK}" ]; then
        find "${WORK}" -type f -exec shred -u {} \; 2>/dev/null
        rmdir "${WORK}" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# ───── Step 1: Generate Age key pair ─────────────────────────────────────────

step "Step 1/10 — Generate Age key pair for '${PROFILE}'"

AGE_KEY_PLAIN="${WORK}/${PROFILE}.age.key"
age-keygen -o "${AGE_KEY_PLAIN}" 2>/dev/null
AGE_PUB=$(grep "public key:" "${AGE_KEY_PLAIN}" | awk '{print $NF}')
[ -z "${AGE_PUB}" ] && die "Failed to extract Age public key"
ok "Age public key: ${AGE_PUB}"

# ───── Step 2: Generate EJSON key pair ───────────────────────────────────────

step "Step 2/10 — Generate EJSON key pair"

EJSON_KEYS="${WORK}/${PROFILE}.ejson.keys"
ejson keygen > "${EJSON_KEYS}"
EJSON_PUB=$(awk '/^Public Key:/{getline; print; exit}' "${EJSON_KEYS}")
EJSON_PRIV=$(awk '/^Private Key:/{getline; print; exit}' "${EJSON_KEYS}")
[ -z "${EJSON_PUB}" ] || [ -z "${EJSON_PRIV}" ] && die "Failed to parse EJSON keys"
ok "EJSON public key:  ${EJSON_PUB}"

# Write EJSON private key file (name = public key, EJSON convention)
EJSON_KEY_FILE="${WORK}/${EJSON_PUB}"
printf "%s" "${EJSON_PRIV}" > "${EJSON_KEY_FILE}"

# ───── Step 3: Get Age passphrase (interactive prompt) ───────────────────────

step "Step 3/10 — Age passphrase (interactive)"
info "Save this passphrase to your password manager BEFORE typing it here."
info "Suggested entry name: dotfiles/age/${PROFILE}"

# ───── Step 4: Encrypt Age key with passphrase ───────────────────────────────

step "Step 4/10 — Encrypt Age key with passphrase"

chezmoi age encrypt --passphrase --output "${WORK}/${OUT_AGE_KEY}" "${AGE_KEY_PLAIN}" \
    || die "chezmoi age encrypt failed"

# Immediate round-trip test — catch passphrase typos NOW, not at verify time
info "Round-trip test: decrypting back to verify passphrase was typed consistently..."
ROUNDTRIP="${WORK}/roundtrip.key"
if ! chezmoi age decrypt --passphrase --output "${ROUNDTRIP}" "${WORK}/${OUT_AGE_KEY}"; then
    die "Round-trip decrypt failed. Re-run the script and type the passphrase consistently."
fi
if ! diff -q "${ROUNDTRIP}" "${AGE_KEY_PLAIN}" >/dev/null 2>&1; then
    die "Round-trip mismatch — Age decrypt did not produce identical content. ABORT."
fi
ok "Round-trip passphrase verified"

# ───── Step 5: Encrypt EJSON key with Age recipient ──────────────────────────

step "Step 5/10 — Encrypt EJSON key with Age recipient"

age --recipient "${AGE_PUB}" --output "${WORK}/${OUT_EJSON_KEY}" "${EJSON_KEY_FILE}" \
    || die "age encrypt of EJSON key failed"

# Round-trip
if ! age --decrypt --identity "${AGE_KEY_PLAIN}" --output "${WORK}/roundtrip.ejson" "${WORK}/${OUT_EJSON_KEY}"; then
    die "EJSON round-trip decrypt failed"
fi
if ! diff -q "${WORK}/roundtrip.ejson" "${EJSON_KEY_FILE}" >/dev/null 2>&1; then
    die "EJSON round-trip mismatch — ABORT"
fi
ok "EJSON key encrypted and verified"

# ───── Step 6: Build evault skeleton with real _public_key ───────────────────

step "Step 6/10 — Generate sealed evault skeleton"

# Default field content — operator can edit later via `edit-evault`
if [ "${PROFILE}" = "personal" ]; then
    GIT_USER="Your Name"
    GIT_EMAIL="personal@example.com"
else
    GIT_USER="FILL_IN_WORK_NAME"
    GIT_EMAIL="FILL_IN_WORK_EMAIL"
fi

cat > "${WORK}/evault.json" <<EOF
{
  "_public_key": "${EJSON_PUB}",
  "_comment": "${PROFILE} profile evault. Edit via 'edit-evault ${PROFILE}'.",
  "git": {
    "user": "${GIT_USER}",
    "email": "${GIT_EMAIL}"
  }
}
EOF

# Run ejson encrypt (in place — replaces plaintext values with EJ[1:...])
ejson encrypt "${WORK}/evault.json" >/dev/null
ok "Evault encrypted with _public_key = ${EJSON_PUB}"

# ───── Step 7: Write outputs to CWD ──────────────────────────────────────────

step "Step 7/10 — Copy outputs to CWD"

cp "${WORK}/${OUT_AGE_KEY}"   "${OUT_AGE_KEY}"
cp "${WORK}/${OUT_EJSON_KEY}" "${OUT_EJSON_KEY}"
cp "${WORK}/evault.json"      "${OUT_EVAULT}"

cat > "${OUT_PUB_KEYS}" <<EOF
# Dotfiles encryption public keys for profile: ${PROFILE}
# Generated: $(date -Iseconds)
#
# These values go into .chezmoi.yaml.tmpl placeholders.
# Keep this file — it has no secrets, just public identifiers.

PROFILE=${PROFILE}
AGE_PUBLIC_KEY=${AGE_PUB}
EJSON_PUBLIC_KEY=${EJSON_PUB}
EOF

ok "Wrote:"
ls -la "${OUT_AGE_KEY}" "${OUT_EJSON_KEY}" "${OUT_EVAULT}" "${OUT_PUB_KEYS}" | sed 's/^/    /'

# ───── Step 8: Optional deploy ───────────────────────────────────────────────

if [ "${DO_DEPLOY}" -eq 1 ]; then
    step "Step 8/10 — Deploy to dotfiles repo"

    cp "${OUT_AGE_KEY}"   "${REPO}/${OUT_AGE_KEY}"
    cp "${OUT_EJSON_KEY}" "${REPO}/${OUT_EJSON_KEY}"
    mkdir -p "${REPO}/secrets/${PROFILE}"
    cp "${OUT_EVAULT}"    "${REPO}/secrets/${PROFILE}/evault"
    ok "Copied encrypted blobs + evault to ${REPO}"

    # Update .chezmoi.yaml.tmpl placeholders for THIS profile only
    YAML="${REPO}/.chezmoi.yaml.tmpl"
    UPCASE=$(echo "${PROFILE}" | tr '[:lower:]' '[:upper:]')

    if grep -q "REPLACE_WITH_${UPCASE}_AGE_PUBLIC_KEY" "${YAML}"; then
        sed -i "s|REPLACE_WITH_${UPCASE}_AGE_PUBLIC_KEY|${AGE_PUB}|" "${YAML}"
        ok "Updated .chezmoi.yaml.tmpl Age recipient for ${PROFILE}"
    else
        warn ".chezmoi.yaml.tmpl already has a real Age recipient for ${PROFILE} — left untouched"
    fi

    if grep -q "REPLACE_WITH_${UPCASE}_EJSON_PUBLIC_KEY" "${YAML}"; then
        sed -i "s|REPLACE_WITH_${UPCASE}_EJSON_PUBLIC_KEY|${EJSON_PUB}|" "${YAML}"
        ok "Updated .chezmoi.yaml.tmpl EJSON key id for ${PROFILE}"
    else
        warn ".chezmoi.yaml.tmpl already has a real EJSON key id for ${PROFILE} — left untouched"
    fi
else
    info "Skipping deploy — pass --deploy to copy files into the dotfiles repo"
fi

# ───── Step 9: End-to-end verify ─────────────────────────────────────────────

step "Step 9/10 — Verify the encryption chain end-to-end"

# Determine which files to verify against — repo if deployed, CWD otherwise
if [ "${DO_DEPLOY}" -eq 1 ]; then
    V_AGE_BLOB="${REPO}/${OUT_AGE_KEY}"
    V_EJSON_BLOB="${REPO}/${OUT_EJSON_KEY}"
    V_EVAULT="${REPO}/secrets/${PROFILE}/evault"
    V_LOC="repo"
else
    V_AGE_BLOB="${OUT_AGE_KEY}"
    V_EJSON_BLOB="${OUT_EJSON_KEY}"
    V_EVAULT="${OUT_EVAULT}"
    V_LOC="CWD"
fi

info "Verifying decrypt chain against files in ${V_LOC}..."

VERIFY_DIR="${WORK}/verify"
mkdir -p "${VERIFY_DIR}/keys" && chmod 700 "${VERIFY_DIR}"

# 9.1 — Age decrypt (we already have the plaintext Age key in tmpfs, but we
# verify the BLOB roundtrips by extracting via the chain, not by reusing
# the plaintext we kept in memory). To do this we re-decrypt with the
# passphrase. Skip if not in deploy (round-trip was done in Step 4 anyway).
# Instead, use the plaintext key still in WORK as the identity for the
# EJSON decrypt — this proves the chain end-to-end without asking for the
# passphrase again.

if [ ! -f "${AGE_KEY_PLAIN}" ]; then
    err "Internal: plaintext Age key missing from tmpfs — cannot verify chain"
    exit 1
fi
ok "Stage 1: Age key already round-tripped in Step 4"

# 9.2 — EJSON key decrypt via Age key (re-test against blob from V_AGE_BLOB-side chain)
if ! age --decrypt --identity "${AGE_KEY_PLAIN}" --output "${VERIFY_DIR}/ejson.key" "${V_EJSON_BLOB}" 2>/dev/null; then
    err "Stage 2: failed to decrypt ${V_EJSON_BLOB} with extracted Age key"
    exit 1
fi
ACTUAL_EJSON_PRIV=$(cat "${VERIFY_DIR}/ejson.key")
if [ "${ACTUAL_EJSON_PRIV}" != "${EJSON_PRIV}" ]; then
    err "Stage 2: EJSON key mismatch — chain is broken"
    exit 1
fi
ok "Stage 2: EJSON key decrypted via Age key, content matches expected"

# 9.3 — Evault decrypt via EJSON key
cp "${VERIFY_DIR}/ejson.key" "${VERIFY_DIR}/keys/${EJSON_PUB}"
if ! ejson -keydir "${VERIFY_DIR}/keys" decrypt "${V_EVAULT}" > "${VERIFY_DIR}/evault.json" 2>/dev/null; then
    err "Stage 3: failed to decrypt evault with EJSON key"
    exit 1
fi
# Verify content matches what we wrote into evault.json before encryption
ACTUAL_USER=$(python3 -c "import json; print(json.load(open('${VERIFY_DIR}/evault.json'))['git']['user'])" 2>/dev/null)
ACTUAL_EMAIL=$(python3 -c "import json; print(json.load(open('${VERIFY_DIR}/evault.json'))['git']['email'])" 2>/dev/null)
if [ "${ACTUAL_USER}" != "${GIT_USER}" ] || [ "${ACTUAL_EMAIL}" != "${GIT_EMAIL}" ]; then
    err "Stage 3: evault content mismatch (user='${ACTUAL_USER}' email='${ACTUAL_EMAIL}')"
    exit 1
fi
ok "Stage 3: evault decrypted, git.user='${ACTUAL_USER}' git.email='${ACTUAL_EMAIL}'"

# 9.4 — Cross-profile isolation (only if other profile exists in repo)
if [ "${DO_DEPLOY}" -eq 1 ]; then
    OTHER=$([ "${PROFILE}" = "personal" ] && echo work || echo personal)
    OTHER_BLOB="${REPO}/age_key_${OTHER}.age"
    if [ -f "${OTHER_BLOB}" ]; then
        if age --decrypt --identity "${AGE_KEY_PLAIN}" --output /dev/null "${OTHER_BLOB}" 2>/dev/null; then
            err "Stage 4 ISOLATION BROKEN: ${PROFILE} Age key decrypted ${OTHER} blob!"
            err "  This is a critical security failure. Investigate before committing."
            exit 1
        else
            ok "Stage 4: ${PROFILE} Age key cannot decrypt ${OTHER} blob (expected)"
        fi
    else
        info "Stage 4: ${OTHER} profile not yet set up — isolation check deferred until both profiles exist"
    fi
fi

ok "End-to-end verify PASSED for profile '${PROFILE}'"

# ───── Step 10: Summary ──────────────────────────────────────────────────────

step "Step 10/10 — Summary"

cat <<EOF

  Profile:           ${PROFILE}
  Age public key:    ${AGE_PUB}
  EJSON public key:  ${EJSON_PUB}

  Files in CWD:
    ${OUT_AGE_KEY}              (commit to repo)
    ${OUT_EJSON_KEY}            (commit to repo)
    ${OUT_EVAULT}               (commit to repo as secrets/${PROFILE}/evault)
    ${OUT_PUB_KEYS}             (reference only — public values for .chezmoi.yaml.tmpl)

EOF

if [ "${DO_DEPLOY}" -eq 1 ]; then
    cat <<EOF
  ✓ Deployed to: ${REPO}
  ✓ Encryption chain verified end-to-end

  Next steps:
    1. cd ${REPO} && git diff --stat
    2. After running setup-encryption for BOTH profiles, commit.
EOF
else
    cat <<EOF
  ✓ Encryption chain verified end-to-end (against files in CWD)

  Next steps to deploy manually:
    1. cp ${OUT_AGE_KEY}   <repo>/
    2. cp ${OUT_EJSON_KEY} <repo>/
    3. cp ${OUT_EVAULT}    <repo>/secrets/${PROFILE}/evault
    4. Edit <repo>/.chezmoi.yaml.tmpl — replace placeholders:
       REPLACE_WITH_${UPCASE:=$(echo "${PROFILE}" | tr '[:lower:]' '[:upper:]')}_AGE_PUBLIC_KEY   → ${AGE_PUB}
       REPLACE_WITH_${UPCASE}_EJSON_PUBLIC_KEY → ${EJSON_PUB}

  Or re-run with --deploy to do all of the above automatically.
EOF
fi

echo ""
ok "Setup complete and verified for profile '${PROFILE}'"

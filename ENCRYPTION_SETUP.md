# Encryption setup & verification

Step-by-step guide for generating a fresh set of encryption keys for a
profile (personal or work) and verifying that the full decrypt chain works
end-to-end.

Run this when:
- First-time setup of dotfiles (clean slate)
- Rotating keys after a suspected compromise
- A previous setup attempt got into a broken state

The guide is per-profile — run the same steps for `personal` and again for
`work` (with different passphrases).

---

## Quick path — automated setup

For most cases, use the helper script that does Steps 1-7 automatically:

```bash
# Generate keys in CWD only (then copy to repo manually)
./helpers/setup-encryption.sh personal

# Or generate + auto-deploy to the dotfiles repo (chezmoi source-path)
./helpers/setup-encryption.sh personal --deploy

# Or specify the repo path explicitly
./helpers/setup-encryption.sh work --deploy --repo ~/devel/homelab/dotfiles
```

The script prompts once for the Age passphrase (and once for verify),
generates Age + EJSON key pairs, runs the round-trip test inside the
encrypt step (catches passphrase typos immediately), seals the evault
skeleton, optionally updates `.chezmoi.yaml.tmpl` placeholders, and
**runs an end-to-end verify automatically** (decrypts the full chain
to confirm everything matches expected values). Plaintext keys are
shredded on exit even when interrupted.

Run it twice — once for `personal`, once for `work` — with two
**different** passphrases. When the second run completes (with the
first profile already in the repo), the script additionally tests
cross-profile isolation — confirming the work key cannot decrypt
personal blobs and vice versa.

A standalone verify script (`~/verify-encryption.sh personal|work`) is
also available — useful when you want to re-test the chain later or
after key rotation, without re-running setup.

If the script fails (e.g. tool missing, passphrase mismatch), the manual
guide below explains each step individually for debugging.

---

## Overview of the encryption chain

```
[password manager]                    ← Age passphrase (manual prerequisite)
         │
         ▼
age_key_<profile>.age                 ← Age-encrypted Age key (passphrase-protected)
         │
         ▼
ejson_key_<profile>.age               ← Age-encrypted EJSON private key
         │
         ▼
secrets/<profile>/evault              ← EJSON-encrypted structured JSON
```

Three keys (Age passphrase, Age key pair, EJSON key pair) — chained so that
the only manual prerequisite is one Age passphrase per profile, and
everything downstream is automatically decryptable from it.

---

## Prerequisites

- `age` 1.x installed
- `ejson` installed (Shopify EJSON: https://github.com/Shopify/ejson/releases)
- `chezmoi` installed (we use its built-in Age for passphrase encryption)
- A password manager to store the Age passphrase (1Password / Bitwarden /
  KeePassXC / …)

Verify all three are on `PATH`:

```bash
age --version       # e.g. 1.3.1
ejson keygen        # prints a fresh key pair (we'll use this in Step 2)
chezmoi --version   # e.g. v2.65.x
```

---

## Setup — per profile

Replace `<profile>` with `personal` or `work` in every command below.

All commands assume working directory `~/dotfiles-keygen` (or any path
outside the dotfiles repo — we'll copy finished blobs to the repo at the
end).

```bash
mkdir -p ~/dotfiles-keygen && chmod 700 ~/dotfiles-keygen
cd ~/dotfiles-keygen
```

### Step 1 — Generate a new Age key pair

```bash
age-keygen -o <profile>.age.key
```

This writes a plaintext Age key file containing both the public recipient
and the private key. Note the public key from the output — you'll need it
in Step 3 and Step 6.

Example output:

```
Public key: age1abc...xyz
```

```bash
# Capture the public key for later use
grep "public key:" <profile>.age.key
```

### Step 2 — Generate a new EJSON key pair

```bash
ejson keygen
```

EJSON prints both keys to stdout. Capture them:

```bash
ejson keygen > <profile>.ejson.keys.txt
cat <profile>.ejson.keys.txt
```

Example output:

```
Public Key:
2c1c1c78bfbbcc263930e9a8fc669390c69647756249dc7da43fc987ce6d6041
Private Key:
51cf6711866185f534951011ffa2f32dd22278048bc351ff3a9567c426f53145
```

Save the EJSON private key to a file named after its public key (EJSON
convention):

```bash
EJSON_PUB=$(awk '/^Public Key:/{getline; print; exit}' <profile>.ejson.keys.txt)
EJSON_PRIV=$(awk '/^Private Key:/{getline; print; exit}' <profile>.ejson.keys.txt)
printf "%s" "${EJSON_PRIV}" > "${EJSON_PUB}"
ls -la "${EJSON_PUB}"
```

### Step 3 — Create a strong Age passphrase

Use your password manager to generate a strong passphrase (4-5 random
words or 20+ random chars). Save it as:

- `dotfiles/age/personal` (for personal profile)
- `dotfiles/age/work` (for work profile)

**Critical:** if you lose this passphrase, the profile is unrecoverable.
Back it up to a second password manager or write it down in a physical
safe.

**Use DIFFERENT passphrases for personal and work** — same passphrase
defeats the kryptografic isolation goal.

### Step 4 — Encrypt the Age key with the passphrase

```bash
chezmoi age encrypt --passphrase --output age_key_<profile>.age <profile>.age.key
```

`chezmoi age encrypt --passphrase` will prompt:

```
Enter passphrase: ████████
Confirm passphrase: ████████
```

Paste the passphrase from the password manager (or type if you generated it
manually).

**Verify the file was created:**

```bash
ls -la age_key_<profile>.age
# Expected: ~370 bytes
```

Try it round-trip immediately (don't continue if this fails):

```bash
chezmoi age decrypt --passphrase --output /tmp/roundtrip-test.key age_key_<profile>.age
# → paste same passphrase
diff /tmp/roundtrip-test.key <profile>.age.key
# Expected: no output (files identical)
rm /tmp/roundtrip-test.key
```

If `diff` shows differences or `decrypt` fails — **stop**. You typed a
different passphrase during encrypt vs. now. Re-do Step 4 carefully.

### Step 5 — Encrypt the EJSON key with the Age recipient

This is non-interactive — uses the Age public key as recipient (not the
passphrase).

```bash
AGE_PUB=$(grep "public key:" <profile>.age.key | awk '{print $NF}')
age --recipient "${AGE_PUB}" --output ejson_key_<profile>.age "${EJSON_PUB}"
ls -la ejson_key_<profile>.age
# Expected: ~265 bytes
```

Round-trip test:

```bash
age --decrypt --identity <profile>.age.key --output /tmp/roundtrip-ejson.key ejson_key_<profile>.age
diff /tmp/roundtrip-ejson.key "${EJSON_PUB}"
# Expected: no output
rm /tmp/roundtrip-ejson.key
```

### Step 6 — Update `.chezmoi.yaml.tmpl` with the public identifiers

Edit `/path/to/dotfiles/.chezmoi.yaml.tmpl` and replace placeholders:

```yaml
# Before:
{{- $enc_age_recipient_<profile>  := "REPLACE_WITH_<PROFILE>_AGE_PUBLIC_KEY" -}}
{{- $enc_ejson_key_id_<profile>   := "REPLACE_WITH_<PROFILE>_EJSON_PUBLIC_KEY" -}}

# After (use values from Step 1 and Step 2):
{{- $enc_age_recipient_<profile>  := "age1abc...xyz" -}}
{{- $enc_ejson_key_id_<profile>   := "2c1c1c78bfbbcc..." -}}
```

### Step 7 — Create the evault skeleton with real public key

Create `secrets/<profile>/evault`:

```json
{
  "_public_key": "<paste EJSON public key from Step 2>",
  "_comment": "Profile evault. Run 'ejson encrypt' before committing.",
  "git": {
    "user": "Your Name",
    "email": "your.email@example.com"
  }
}
```

Encrypt it (in place, replaces plaintext values with `EJ[1:...]` blobs):

```bash
ejson encrypt /path/to/dotfiles/secrets/<profile>/evault
```

The `_public_key` and `_comment` fields stay plaintext (EJSON convention —
keys starting with `_` are not encrypted). All other values become `EJ[...]`.

### Step 8 — Copy encrypted blobs into the dotfiles repo

```bash
cp age_key_<profile>.age   /path/to/dotfiles/
cp ejson_key_<profile>.age /path/to/dotfiles/
# secrets/<profile>/evault was already in place from Step 7
```

### Step 9 — Shred plaintext key files

```bash
shred -u <profile>.age.key
shred -u <profile>.ejson.keys.txt
shred -u "${EJSON_PUB}"
```

After both profiles are done:

```bash
shred -u ~/dotfiles-keygen/* 2>/dev/null
rm -rf ~/dotfiles-keygen
```

---

## Verification — end-to-end decrypt chain

Run this after both profiles' setup is complete to confirm everything works.

Save the script below as `~/verify-encryption.sh`, then run it:

```bash
chmod +x ~/verify-encryption.sh
~/verify-encryption.sh personal   # verify personal profile
~/verify-encryption.sh work       # verify work profile
```

Script body:

```bash
#!/usr/bin/env bash
# Verify the Age + EJSON decrypt chain for a given profile.
set -uo pipefail

PROFILE="${1:?Usage: $0 personal|work}"
DOTFILES="${DOTFILES:-$HOME/devel/homelab/dotfiles}"
WORK="/tmp/verify-encryption-${PROFILE}"

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { printf "${GREEN}✓ %s${NC}\n" "$*"; }
err()  { printf "${RED}✗ %s${NC}\n" "$*"; }
step() { printf "\n${BLUE}━━━ %s ━━━${NC}\n" "$*"; }

rm -rf "${WORK}"
mkdir -p "${WORK}" && chmod 700 "${WORK}"
cd "${WORK}"

step "Step A — Decrypt Age key (interactive: paste ${PROFILE} passphrase)"
chezmoi age decrypt --passphrase --output age.key \
    "${DOTFILES}/age_key_${PROFILE}.age" || { err "Age decrypt failed"; exit 1; }
chmod 600 age.key
ok "Age key decrypted"
grep "public key:" age.key

step "Step B — Decrypt EJSON key using extracted Age key"
age --decrypt --identity age.key --output ejson.key \
    "${DOTFILES}/ejson_key_${PROFILE}.age" || { err "EJSON decrypt failed"; exit 1; }
chmod 600 ejson.key
ok "EJSON key decrypted: $(cat ejson.key | head -c 16)..."

step "Step C — Decrypt evault using EJSON key"
EJSON_PUB=$(grep '"_public_key"' "${DOTFILES}/secrets/${PROFILE}/evault" \
            | sed 's/.*"_public_key": *"\([^"]*\)".*/\1/')
mkdir -p ./keys
cp ejson.key "./keys/${EJSON_PUB}"
if ejson -keydir ./keys decrypt "${DOTFILES}/secrets/${PROFILE}/evault" > evault.json; then
    ok "Evault decrypted"
    sed 's/^/    /' evault.json
else
    err "Evault decrypt failed"; exit 1
fi

step "Step D — Cross-profile isolation check"
OTHER=$([ "${PROFILE}" = "personal" ] && echo work || echo personal)
if age --decrypt --identity age.key --output /dev/null \
        "${DOTFILES}/age_key_${OTHER}.age" 2>/dev/null; then
    err "ISOLATION BROKEN — ${PROFILE} key decrypted ${OTHER} blob!"
    exit 1
else
    ok "${PROFILE} Age key cannot decrypt ${OTHER} blob (expected)"
fi

echo ""
ok "Profile '${PROFILE}' — ALL CHECKS PASSED"
echo "Cleanup: rm -rf ${WORK}"
```

### What each step verifies

| Step | What it tests |
|------|---|
| A | Age passphrase + chezmoi can decrypt `age_key_<profile>.age` |
| B | Extracted Age key matches the recipient used to encrypt `ejson_key_<profile>.age` |
| C | EJSON private key matches the `_public_key` in `secrets/<profile>/evault` |
| D | The OTHER profile's Age key is NOT decryptable with this profile's key |

If all four pass, the encryption chain is functional and the profile
isolation guarantee holds.

---

## Troubleshooting

### "chezmoi age decrypt failed" or "no identity matched any of the recipients"

You typed a different passphrase during encrypt (Step 4) vs. decrypt
(verify). Re-do Step 4: generate the Age key again, type the passphrase
slowly twice (encrypt prompt + confirm), and run the immediate round-trip
test inside Step 4 before continuing.

### Step B fails ("no identity matched")

The Age public key used to encrypt `ejson_key_<profile>.age` (Step 5) does
not match the Age private key extracted in Step A. This means Step 5 used
the wrong recipient. Re-do Step 5 with the correct `AGE_PUB` (from
`grep "public key:" <profile>.age.key`).

### Step C fails ("could not find key for public key")

The `_public_key` field in `secrets/<profile>/evault` does not match the
EJSON private key extracted in Step B. Re-do Step 7: open the evault
JSON, fix `_public_key` to match the actual EJSON public key from Step 2,
then re-run `ejson encrypt`.

### Step D succeeds (isolation NOT working)

Both profiles share the same Age key. This is a critical bug — re-do the
**other** profile's Step 1 (generate fresh key, don't reuse).

### Lost passphrase

Without the passphrase, the profile is permanently unrecoverable. Generate
a completely new key set (start over from Step 1) and re-encrypt the
evault content.

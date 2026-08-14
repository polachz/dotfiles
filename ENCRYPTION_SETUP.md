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

# Generate + auto-deploy to the dotfiles dev repo (recommended)
./helpers/setup-encryption.sh personal --deploy --repo ~/Devel/dotfiles

# Or set DOTFILES_REPO once per shell and omit --repo
export DOTFILES_REPO=~/Devel/dotfiles
./helpers/setup-encryption.sh work --deploy
```

**Critical**: `--deploy` writes to your **development repo** (where you
`git commit`), not to chezmoi's managed source-path
(`~/.local/share/chezmoi/`). The script refuses to deploy into the
managed copy — chezmoi would overwrite your edits on the next
`chezmoi update`. Use the dev repo path, push from there, and other
machines pick up the change via `chezmoi update`.

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
DOTFILES="${DOTFILES:-$HOME/Devel/dotfiles}"
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

## Operational security after deploy

Once `chezmoi apply` has run successfully, the following plaintext material
lives on disk **permanently** (mode 600, owned by your user):

```
~/.config/chezmoi/age_<profile>.key       ← Age private key (plaintext)
~/.config/chezmoi/keys/<ejson_pub_id>     ← EJSON private key (plaintext)
~/.gitconfig                               ← rendered template — contains
                                             plaintext decrypted from evault
~/<other rendered templates>               ← any file using ejsonValue
```

This is **by design** — Age + EJSON protect data **in the repo**, not on
the running machine. Anyone with read access to your home directory can
read these files.

### Backup considerations — CRITICAL

If your backup tool includes `~/.config/chezmoi/`, the **plaintext private
keys end up in the backup**. Combined with the encrypted blobs from the
public dotfiles repo, anyone who obtains the backup can decrypt everything.

**Always one of the following:**

1. **Exclude key material from backups** (recommended for cloud sync):
   ```
   # Add to rsync --exclude / restic --exclude / borg --exclude / etc.
   .config/chezmoi/age_*.key
   .config/chezmoi/keys/
   .config/chezmoi/chezmoi.yaml      # contains rendered key paths
   ```

2. **Encrypt the backup itself** (e.g. restic, borg with passphrase, age-encrypted
   tar). Then key files inside are protected by the backup's own crypto.

If you use Nextcloud / Dropbox / OneDrive for home sync **without a
client-side encryption layer**: keys leak to the cloud. Don't.

### What's safe to publish (public repo)

| File | Safe to push? | Why |
|------|---------------|-----|
| `age_key_<profile>.age` | ✅ yes | Passphrase-encrypted; brute force requires the passphrase |
| `ejson_key_<profile>.age` | ✅ yes | Encrypted with Age recipient |
| `secrets/<profile>/evault` | ✅ yes | Per-field encrypted with EJSON |
| `.chezmoi.yaml.tmpl` | ✅ yes | Contains only public recipient strings and EJSON key IDs |
| `~/.config/chezmoi/age_*.key` | ❌ NEVER | Plaintext Age private key |
| `~/.config/chezmoi/keys/*` | ❌ NEVER | Plaintext EJSON private key |
| Plaintext evault content (`_public_key` `EJ[...]`) | n/a | Should never exist on disk; if it does, shred immediately |

### What about `chezmoi cat` / `chezmoi data`?

Both commands print **rendered plaintext** including decrypted values. Don't
pipe their output to log files, pastebins, or chat tools.

### Stale plaintext check

After `edit-evault` or a failed setup-encryption run, plaintext may
linger in tmpfs if a process was `kill -9`-ed (the `trap` cleanup doesn't
run on SIGKILL):

```bash
# Should print nothing — if it does, shred them
find /dev/shm -maxdepth 2 \( -name 'edit-evault-*' -o -name 'setup-encryption-*' \) 2>/dev/null
```

`/dev/shm` clears on reboot, so this is at worst a session-scoped leak.

---

## Editing evault — workflow

Use the `edit-evault` helper to add or change fields:

```bash
# Decrypts into tmpfs, opens $EDITOR, re-encrypts on save
edit-evault personal --repo ~/Devel/dotfiles

# Or with the env var (set once per shell)
export DOTFILES_REPO=~/Devel/dotfiles
edit-evault personal
```

**Critical** — `edit-evault` writes to your **dev repo** (the one you
`git push` from), not to chezmoi's managed source-path
(`~/.local/share/chezmoi/`). If you pass `--repo ~/.local/share/chezmoi`,
the script refuses. After editing, propagate the change:

```bash
cd ~/Devel/dotfiles
git diff secrets/personal/evault       # encrypted blob diff
git add secrets/personal/evault
git commit -m 'evault: add ssh.signing_key for personal'
git push

# On other machines that already have the key chain installed:
chezmoi update                          # pulls + applies
```

### Adding new fields incrementally

The evault starts as a skeleton (just `git.user` + `git.email`). Add
fields when a template needs them, not preemptively:

1. A new chezmoi template fails with `field not found` during `chezmoi apply`
2. `edit-evault <profile>` → add the field as plaintext JSON
3. Save → `edit-evault` re-encrypts in place
4. Commit + push
5. `chezmoi apply` succeeds

### `edit-evault` no-op detection

If you open the editor and exit without changes (same SHA256 before/after),
the script skips re-encryption — no spurious commits.

### If JSON gets broken during edit

If you save invalid JSON, `edit-evault` refuses to encrypt and **disables
its own cleanup**, leaving the plaintext file at
`/dev/shm/edit-evault-<profile>-<pid>/evault.json`. Fix the JSON in
another editor, then either:

- Manually `cp` the fixed file to `<repo>/secrets/<profile>/evault` and
  run `ejson encrypt <path>`
- Or re-run `edit-evault <profile>` from scratch (it ignores the stale
  tmpfs file)

Either way, `shred -u /dev/shm/edit-evault-*/evault.json` when done.

---

## Recovery scenarios

### Lost Age passphrase

Without the passphrase, you cannot decrypt `age_key_<profile>.age` on any
**new** machine. Existing machines still work — the decrypted Age key
lives at `~/.config/chezmoi/age_<profile>.key` and only the bootstrap
flow needs the passphrase.

**Two paths:**

1. **At least one machine still has the decrypted Age key**: rotate just
   the passphrase wrapper. The Age key pair and evault content remain
   unchanged. See [Scenario A](#scenario-a--passphrase-rotation-only)
   below.

2. **No machine has the decrypted Age key anymore** (e.g. all installs
   wiped, only the encrypted blob in the public repo remains): the
   profile is unrecoverable in the strict sense — but you can start
   fresh. See [Scenario D](#scenario-d--full-re-key-age--ejson-both).
   The evault content is permanently lost unless you have a separate
   plaintext backup of the field values.

### Broken JSON during edit-evault

See "If JSON gets broken during edit" in the editing workflow section above.

### Stuck setup-encryption / corrupted blob state

If a setup run was interrupted mid-stream and one of the four blobs is
missing or won't round-trip:

```bash
# Remove the broken blobs from the dev repo
cd ~/Devel/dotfiles
rm age_key_<profile>.age ejson_key_<profile>.age secrets/<profile>/evault
git add -A

# Re-run setup from scratch (use a fresh CWD)
mkdir /tmp/setup-redo && cd /tmp/setup-redo
~/Devel/dotfiles/helpers/setup-encryption.sh <profile> --deploy \
    --repo ~/Devel/dotfiles

# Clean up CWD output
shred -u /tmp/setup-redo/* && rmdir /tmp/setup-redo
```

### Machine compromise — emergency rotation

If you suspect a machine that had the decrypted keys was compromised
(stolen laptop, malware, leaked backup):

1. **Don't trust the existing key material.** Rotate both layers — see
   [Scenario D — full re-key](#scenario-d--full-re-key-age--ejson-both).
2. **Re-key all profiles** if the compromise might extend to both.
3. **Rotate any secrets that lived in the evault** (passwords, signing
   keys, API tokens). The encryption protected them in the repo, but if
   the attacker had the decrypted keys, they had the plaintext.
4. **Wipe the compromised machine.** Reinstall from clean media.

---

## Rotating keys

The encryption chain has three independent key layers, each with its own
rotation cost. Pick the lightest one that solves your problem.

### Which scenario do I have?

| Scenario | What changed | What still works | Use |
|----------|--------------|------------------|-----|
| Lost or weak **passphrase** only | Wrapper around Age key | Age key pair, EJSON key, evault content all valid | **Scenario A** — passphrase rotation |
| Suspected **Age key** compromise (passphrase + key pair leaked) | Age key pair, all downstream broken trust | EJSON key + evault content technically intact, but EJSON key was Age-wrapped → re-wrap needed | **Scenario B** — Age key rotation only |
| Suspected **EJSON key** compromise or starting fresh | EJSON key pair invalidated, evault must be re-sealed | Age key pair can be reused if not also compromised | **Scenario C** — EJSON key rotation (evault re-seal) |
| **Full re-key** (worst case) | Everything | Nothing | **Scenario D** — all keys |

Why the table: the evault content (the actual git.user, git.email, …)
only depends on the EJSON key. If only the Age passphrase changes, the
evault stays bit-identical. If the EJSON key changes, the evault must be
**decrypted with the old key and re-encrypted with the new one** — and
that requires having the old EJSON private key on disk.

### Critical: capture evault content BEFORE removing old keys

In any scenario that touches the EJSON key (C or D), you must have the
old EJSON private key accessible long enough to decrypt the evault. If
you `rm ~/.config/chezmoi/keys/<old_pub>` first, the evault content is
unrecoverable (the public repo blob is encrypted with a key you just
deleted).

The flows below either keep a working machine intact during the rotation,
or capture the evault content to tmpfs first.

---

### Scenario A — passphrase rotation only

The Age key pair stays the same; only the passphrase that wraps it
changes. Evault content remains bit-identical. **Cheapest rotation.**

**Prerequisite**: at least one machine has the decrypted Age key at
`~/.config/chezmoi/age_<profile>.key` (i.e. you've completed bootstrap
on it).

```bash
# 1. Pick a new passphrase, save to password manager FIRST
# 2. Re-wrap the existing Age key with the new passphrase
chezmoi age encrypt --passphrase \
    --output ~/Devel/dotfiles/age_key_<profile>.age \
    ~/.config/chezmoi/age_<profile>.key
# → enter NEW passphrase twice (encrypt prompt + confirm)

# 3. Round-trip verify (avoid silent failure)
chezmoi age decrypt --passphrase --output /tmp/rt.key \
    ~/Devel/dotfiles/age_key_<profile>.age
diff /tmp/rt.key ~/.config/chezmoi/age_<profile>.key && echo OK
shred -u /tmp/rt.key

# 4. Commit and push
cd ~/Devel/dotfiles
git add age_key_<profile>.age
git commit -m 'rotate: <profile> Age passphrase'
git push
```

**Other machines**: do nothing. They already have the decrypted Age key
at `~/.config/chezmoi/age_<profile>.key`. The passphrase is only used
during fresh bootstrap. The next time you bootstrap a new machine, you'll
use the new passphrase.

**`.chezmoi.yaml.tmpl` unchanged** — public identifiers didn't change.

---

### Scenario B — Age key rotation only

The Age key pair was compromised but EJSON key was not (e.g. someone got
the passphrase + the wrapped Age blob, but couldn't reach the decrypted
EJSON key on a machine). Evault content remains bit-identical, but
`ejson_key_<profile>.age` must be **re-wrapped** with the new Age
recipient because it was encrypted to the old Age public key.

**Prerequisite**: machine with both decrypted keys on disk
(`~/.config/chezmoi/age_<profile>.key` + `~/.config/chezmoi/keys/<ejson_pub>`).

```bash
# Workspace on tmpfs — plaintext keys live here briefly
WORK=/dev/shm/rekey-age-<profile>-$$
mkdir -p "${WORK}" && chmod 700 "${WORK}"
cd "${WORK}"
trap 'find "${WORK}" -type f -exec shred -u {} \; ; rmdir "${WORK}"' EXIT INT TERM

EJSON_PUB=$(grep '"_public_key"' \
    ~/Devel/dotfiles/secrets/<profile>/evault \
    | sed 's/.*"_public_key": *"\([^"]*\)".*/\1/')

# 1. Generate new Age key pair
age-keygen -o new_age.key
NEW_AGE_PUB=$(grep "public key:" new_age.key | awk '{print $NF}')

# 2. Re-wrap the EJSON private key with the NEW Age recipient
age --recipient "${NEW_AGE_PUB}" \
    --output ejson_key_<profile>.age \
    ~/.config/chezmoi/keys/"${EJSON_PUB}"

# 3. Round-trip verify
age --decrypt --identity new_age.key --output rt.ejson ejson_key_<profile>.age
diff rt.ejson ~/.config/chezmoi/keys/"${EJSON_PUB}" && echo "EJSON wrap OK"

# 4. Wrap the new Age key with the NEW passphrase (new password manager entry FIRST)
chezmoi age encrypt --passphrase --output age_key_<profile>.age new_age.key

# 5. Round-trip verify Age passphrase
chezmoi age decrypt --passphrase --output rt.age age_key_<profile>.age
diff rt.age new_age.key && echo "Age wrap OK"

# 6. Install the new Age key locally (replaces the old one)
mv new_age.key ~/.config/chezmoi/age_<profile>.key
chmod 600 ~/.config/chezmoi/age_<profile>.key

# 7. Copy new blobs to dev repo
cp age_key_<profile>.age ejson_key_<profile>.age \
   ~/Devel/dotfiles/

# 8. Update .chezmoi.yaml.tmpl with new Age recipient
sed -i 's|"<OLD_AGE_PUB>"|"'"${NEW_AGE_PUB}"'"|' \
    ~/Devel/dotfiles/.chezmoi.yaml.tmpl
# Verify the sed worked:
grep "age_recipient_<profile>" ~/Devel/dotfiles/.chezmoi.yaml.tmpl

# 9. Commit and push
cd ~/Devel/dotfiles
git add age_key_<profile>.age ejson_key_<profile>.age .chezmoi.yaml.tmpl
git commit -m 'rotate: <profile> Age key pair'
git push
```

**Evault stays untouched** — EJSON private key is the same, just wrapped
under a different Age recipient. `secrets/<profile>/evault` is not
modified.

**Other machines**: stale `~/.config/chezmoi/age_<profile>.key` — replace
via `rm ~/.config/chezmoi/age_<profile>.key && chezmoi apply` (triggers
init script to decrypt the new blob).

---

### Scenario C — EJSON key rotation (evault re-seal)

EJSON private key compromised or you want to rotate it. Age key can be
reused (if not also compromised). **Evault content must be decrypted
with the old EJSON key and re-encrypted with the new one.**

**Prerequisite**: working machine with current EJSON private key at
`~/.config/chezmoi/keys/<old_ejson_pub>`.

```bash
WORK=/dev/shm/rekey-ejson-<profile>-$$
mkdir -p "${WORK}" && chmod 700 "${WORK}"
cd "${WORK}"
trap 'find "${WORK}" -type f -exec shred -u {} \; ; rmdir "${WORK}"' EXIT INT TERM

REPO=~/Devel/dotfiles
OLD_EJSON_PUB=$(grep '"_public_key"' "${REPO}/secrets/<profile>/evault" \
    | sed 's/.*"_public_key": *"\([^"]*\)".*/\1/')

# 1. Decrypt the evault with the OLD EJSON key (still on disk)
ejson -keydir ~/.config/chezmoi/keys decrypt \
    "${REPO}/secrets/<profile>/evault" > evault_plain.json
chmod 600 evault_plain.json

# 2. Generate new EJSON key pair
ejson keygen > new_ejson.keys
NEW_EJSON_PUB=$(awk '/^Public Key:/{getline; print; exit}' new_ejson.keys)
NEW_EJSON_PRIV=$(awk '/^Private Key:/{getline; print; exit}' new_ejson.keys)

# 3. Build a new evault skeleton with the new _public_key, then merge
#    the decrypted fields back in. Use jq for safe JSON manipulation.
jq --arg pub "${NEW_EJSON_PUB}" \
   '. + {_public_key: $pub}' evault_plain.json > new_evault.json

# 4. Install new EJSON private key in chezmoi key dir (needed for encrypt)
printf "%s" "${NEW_EJSON_PRIV}" > ~/.config/chezmoi/keys/"${NEW_EJSON_PUB}"
chmod 600 ~/.config/chezmoi/keys/"${NEW_EJSON_PUB}"

# 5. Re-encrypt the evault with the new key (ejson encrypt is in-place)
ejson encrypt new_evault.json

# 6. Decrypt-round-trip verify (sanity check before committing)
ejson -keydir ~/.config/chezmoi/keys decrypt new_evault.json \
    | jq -e '.git.user and .git.email' >/dev/null && echo "Evault re-seal OK"

# 7. Re-wrap the new EJSON private key with the (unchanged) Age recipient
AGE_PUB=$(grep "public key:" ~/.config/chezmoi/age_<profile>.key | awk '{print $NF}')
age --recipient "${AGE_PUB}" \
    --output ejson_key_<profile>.age \
    ~/.config/chezmoi/keys/"${NEW_EJSON_PUB}"

# 8. Copy new artifacts into the dev repo
cp new_evault.json     "${REPO}/secrets/<profile>/evault"
cp ejson_key_<profile>.age "${REPO}/"

# 9. Update .chezmoi.yaml.tmpl with new EJSON public id
sed -i 's|"'"${OLD_EJSON_PUB}"'"|"'"${NEW_EJSON_PUB}"'"|' \
    "${REPO}/.chezmoi.yaml.tmpl"
grep "ejson_key_id_<profile>" "${REPO}/.chezmoi.yaml.tmpl"

# 10. (Optional but recommended) shred old EJSON private key on this machine
shred -u ~/.config/chezmoi/keys/"${OLD_EJSON_PUB}"

# 11. Commit and push
cd "${REPO}"
git add secrets/<profile>/evault ejson_key_<profile>.age .chezmoi.yaml.tmpl
git commit -m 'rotate: <profile> EJSON key pair (evault re-sealed)'
git push
```

**Age blob unchanged** — `age_key_<profile>.age` stays bit-identical.

**Other machines**: stale `~/.config/chezmoi/keys/<old_ejson_pub>` —
delete it and run `chezmoi apply`, which re-runs the init script and
extracts the new EJSON key from the new `ejson_key_<profile>.age`.

```bash
# On other machines:
rm ~/.config/chezmoi/keys/<OLD_EJSON_PUB>
chezmoi apply
```

#### Why jq + skeleton rebuild in Step 3?

The decrypted `evault_plain.json` from Step 1 still has the **old**
`_public_key` field. If you `ejson encrypt` it directly, EJSON looks up
the old key (still on disk in Step 3 — would work) but the resulting
blob would be encrypted **to the old recipient** — defeating the
rotation. Rewriting `_public_key` first ensures `ejson encrypt` picks
the new key.

If `jq` isn't installed, hand-edit `new_evault.json` and change
`_public_key` to `"${NEW_EJSON_PUB}"` before running `ejson encrypt`.

---

### Scenario D — full re-key (Age + EJSON both)

Worst case: both key layers compromised, or starting completely fresh.
Easiest implementation: do **C first** (EJSON rotation), then **B**
(Age rotation). Two commits, but each step is well-tested above.

Alternative single-pass approach using `setup-encryption.sh` (loses the
evault content unless you capture it first):

```bash
# 1. Capture evault content to tmpfs
WORK=/dev/shm/full-rekey-<profile>-$$
mkdir -p "${WORK}" && chmod 700 "${WORK}"
trap 'find "${WORK}" -type f -exec shred -u {} \; ; rmdir "${WORK}"' EXIT INT TERM

ejson -keydir ~/.config/chezmoi/keys decrypt \
    ~/Devel/dotfiles/secrets/<profile>/evault \
    > "${WORK}/evault_plain.json"

# 2. Hand-edit .chezmoi.yaml.tmpl: restore both placeholders
#    REPLACE_WITH_<PROFILE>_AGE_PUBLIC_KEY
#    REPLACE_WITH_<PROFILE>_EJSON_PUBLIC_KEY

# 3. Remove old blobs from repo
cd ~/Devel/dotfiles
rm age_key_<profile>.age ejson_key_<profile>.age secrets/<profile>/evault

# 4. Run setup-encryption with new passphrase (saved to password manager FIRST)
cd "${WORK}"
~/Devel/dotfiles/helpers/setup-encryption.sh <profile> --deploy \
    --repo ~/Devel/dotfiles
# → produces a SKELETON evault (just git.user/git.email) — we'll overwrite next

# 5. On this machine: chezmoi apply will install the new EJSON private key
#    from the freshly-deployed ejson_key_<profile>.age. Wait for that.
chezmoi apply

# 6. Restore the captured evault content with the new EJSON key
NEW_EJSON_PUB=$(grep '"_public_key"' \
    ~/Devel/dotfiles/secrets/<profile>/evault \
    | sed 's/.*"_public_key": *"\([^"]*\)".*/\1/')

# Rewrite the captured plaintext with the new _public_key, then encrypt
jq --arg pub "${NEW_EJSON_PUB}" \
   '. + {_public_key: $pub}' "${WORK}/evault_plain.json" \
   > ~/Devel/dotfiles/secrets/<profile>/evault
ejson encrypt ~/Devel/dotfiles/secrets/<profile>/evault

# 7. Commit the restored evault
cd ~/Devel/dotfiles
git add secrets/<profile>/evault
git commit -m 'rotate: <profile> evault re-sealed under new EJSON key'
git push
```

**Other machines** — same as the worst-case bootstrap:

```bash
chezmoi purge                                # nuke chezmoi state + keys
chezmoi init --apply https://github.com/<you>/dotfiles.git
# → prompts for new Age passphrase, deploys fresh chain
```

---

### Verifying any rotation worked

After any of A–D, run the standalone verify on a clean machine state:

```bash
# On a machine NOT involved in the rotation (or after fresh bootstrap)
~/verify-encryption.sh <profile>
```

All four checks (A–D in the verify script) should pass. If "Step D —
cross-profile isolation" fails, you accidentally reused a key between
profiles — start over.

---

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

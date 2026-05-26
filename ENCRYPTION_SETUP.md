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
./helpers/setup-encryption.sh personal --deploy --repo ~/devel/homelab/dotfiles

# Or set DOTFILES_REPO once per shell and omit --repo
export DOTFILES_REPO=~/devel/homelab/dotfiles
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
edit-evault personal --repo ~/devel/homelab/dotfiles

# Or with the env var (set once per shell)
export DOTFILES_REPO=~/devel/homelab/dotfiles
edit-evault personal
```

**Critical** — `edit-evault` writes to your **dev repo** (the one you
`git push` from), not to chezmoi's managed source-path
(`~/.local/share/chezmoi/`). If you pass `--repo ~/.local/share/chezmoi`,
the script refuses. After editing, propagate the change:

```bash
cd ~/devel/homelab/dotfiles
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

1. **Re-encrypt the existing Age key with a new passphrase** (from any
   machine where the key is already decrypted on disk):

   ```bash
   # Pick a new passphrase, save to password manager FIRST
   chezmoi age encrypt --passphrase \
       --output ~/devel/homelab/dotfiles/age_key_<profile>.age \
       ~/.config/chezmoi/age_<profile>.key

   cd ~/devel/homelab/dotfiles
   git add age_key_<profile>.age
   git commit -m 'rotate: <profile> Age passphrase'
   git push
   ```

   The Age key pair stays the same — only the passphrase wrapper changes.
   All evault content remains valid, no re-encryption needed.

2. **Full re-key the profile** (if no machine has the decrypted Age key
   anymore): see "Re-keying a profile" below.

### Broken JSON during edit-evault

See "If JSON gets broken during edit" in the editing workflow section above.

### Stuck setup-encryption / corrupted blob state

If a setup run was interrupted mid-stream and one of the four blobs is
missing or won't round-trip:

```bash
# Remove the broken blobs from the dev repo
cd ~/devel/homelab/dotfiles
rm age_key_<profile>.age ejson_key_<profile>.age secrets/<profile>/evault
git add -A

# Re-run setup from scratch (use a fresh CWD)
mkdir /tmp/setup-redo && cd /tmp/setup-redo
~/devel/homelab/dotfiles/helpers/setup-encryption.sh <profile> --deploy \
    --repo ~/devel/homelab/dotfiles

# Clean up CWD output
shred -u /tmp/setup-redo/* && rmdir /tmp/setup-redo
```

### Machine compromise — emergency rotation

If you suspect a machine that had the decrypted keys was compromised
(stolen laptop, malware, leaked backup):

1. **Don't trust the existing key material.** Generate a new Age + EJSON
   key pair for the affected profile (see "Re-keying" below).
2. **Re-key all profiles** if the compromise might extend to both.
3. **Rotate any secrets that lived in the evault** (passwords, signing
   keys, API tokens). The encryption protected them in the repo, but if
   the attacker had the decrypted keys, they had the plaintext.
4. **Wipe the compromised machine.** Reinstall from clean media.

---

## Re-keying a profile

Generate fresh Age + EJSON keys, re-encrypt the evault, replace all four
blobs + the public identifiers in `.chezmoi.yaml.tmpl`. Use when the
existing key material is suspected compromised or you simply want a
fresh start.

### Step-by-step

1. **Capture current evault content** (so you can re-seal it after re-key):

   ```bash
   edit-evault <profile> --repo ~/devel/homelab/dotfiles
   # In the editor: copy the full JSON content to a password manager
   # secure note. Then exit WITHOUT changes (no re-encrypt fires).
   ```

2. **Remove the old blobs and reset `.chezmoi.yaml.tmpl` placeholders**:

   ```bash
   cd ~/devel/homelab/dotfiles
   rm age_key_<profile>.age ejson_key_<profile>.age secrets/<profile>/evault

   # Restore placeholders in .chezmoi.yaml.tmpl (use the actual values you
   # see; the script needs the placeholder string to update it)
   # Hand-edit:
   #   $enc_age_recipient_<profile>  := "REPLACE_WITH_<PROFILE>_AGE_PUBLIC_KEY"
   #   $enc_ejson_key_id_<profile>   := "REPLACE_WITH_<PROFILE>_EJSON_PUBLIC_KEY"
   ```

3. **Generate new key chain** (fresh CWD, new passphrase in password
   manager first):

   ```bash
   mkdir /tmp/rekey && cd /tmp/rekey
   ~/devel/homelab/dotfiles/helpers/setup-encryption.sh <profile> --deploy \
       --repo ~/devel/homelab/dotfiles
   ```

4. **Restore evault content** with the captured JSON:

   ```bash
   # Wait for chezmoi apply on this machine to install the new EJSON key
   chezmoi init                    # if you reset the chezmoi state
   # (or follow the bootstrap flow below for a fresh decrypt)

   edit-evault <profile> --repo ~/devel/homelab/dotfiles
   # Paste the JSON content captured in step 1
   # Save → re-encrypts under the new EJSON key
   ```

5. **Commit + propagate**:

   ```bash
   cd ~/devel/homelab/dotfiles
   git add age_key_<profile>.age ejson_key_<profile>.age \
           secrets/<profile>/evault .chezmoi.yaml.tmpl
   git commit -m 'rekey: <profile> Age + EJSON keys'
   git push
   ```

6. **On other machines**: the old `~/.config/chezmoi/age_<profile>.key`
   and `~/.config/chezmoi/keys/<old_pub>` are stale. Either:

   - **Clean bootstrap**: `chezmoi purge && chezmoi init --apply <repo-url>`
     — chezmoi re-runs `run_once_before_init_age.sh.tmpl`, prompts for the
     new passphrase, deploys fresh keys.

   - **In-place swap**: `rm ~/.config/chezmoi/age_<profile>.key
     ~/.config/chezmoi/keys/<old_pub>`, then `chezmoi apply` re-runs the
     init script and prompts for the new passphrase.

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

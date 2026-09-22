#!/usr/bin/env bash
# Focused shell-session regression checks. These tests use an isolated fixture
# and mock commands; they never run a real chezmoi update or replace the test
# runner process.
set -euo pipefail

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bash_bin=$(command -v bash)
zsh_bin=$(command -v zsh || true)
fish_bin=$(command -v fish || true)

if [[ -z ${zsh_bin} || -z ${fish_bin} ]]; then
    printf 'SKIP: bash, zsh, and fish are required\n' >&2
    exit 0
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-shell-session.XXXXXX")
tmp_dir=$(CDPATH= cd -- "$tmp_dir" && pwd)
trap 'rm -rf "$tmp_dir"' EXIT
fixture_home="${tmp_dir}/fixture-home"
export ZDOTDIR="${tmp_dir}/zdotdir"
export XDG_CONFIG_HOME="${tmp_dir}/xdg-config"
export XDG_DATA_HOME="${tmp_dir}/xdg-data"
mkdir -p "${fixture_home}/.local/bin" "${tmp_dir}/bin" "$ZDOTDIR" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
wrong_shell="${tmp_dir}/inherited-shell"

# Keep the real HOME untouched. The shell fragments are copied into the
# fixture with their HOME references redirected to this task-specific value.
sed -e 's/\${HOME}/\${DOTFILES_TEST_HOME}/g' -e 's/\$HOME/\$DOTFILES_TEST_HOME/g' \
    "$repo_dir/dot_bashrc.d/10-shell.sh" >"${tmp_dir}/bash-shell.sh"
sed -e 's/\${HOME}/\${DOTFILES_TEST_HOME}/g' -e 's/\$HOME/\$DOTFILES_TEST_HOME/g' \
    "$repo_dir/dot_bashrc.d/10-path.sh" >"${tmp_dir}/bash-path.sh"
sed -e 's/\${HOME}/\${DOTFILES_TEST_HOME}/g' -e 's/\$HOME/\$DOTFILES_TEST_HOME/g' \
    "$repo_dir/dot_zshrc.d/10-shell.zsh" >"${tmp_dir}/zsh-shell.zsh"
sed -e 's/\${HOME}/\${DOTFILES_TEST_HOME}/g' -e 's/\$HOME/\$DOTFILES_TEST_HOME/g' \
    "$repo_dir/dot_zshrc.d/10-path.zsh" >"${tmp_dir}/zsh-path.zsh"
sed -e 's/\${HOME}/\${DOTFILES_TEST_HOME}/g' -e 's/\$HOME/\$DOTFILES_TEST_HOME/g' \
    "$repo_dir/dot_config/fish/conf.d/10-shell.fish" >"${tmp_dir}/fish-shell.fish"
sed -e 's/\${HOME}/\${DOTFILES_TEST_HOME}/g' -e 's/\$HOME/\$DOTFILES_TEST_HOME/g' \
    "$repo_dir/dot_config/fish/conf.d/10-path.fish" >"${tmp_dir}/fish-path.fish"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    [[ ${expected} == "${actual}" ]] || fail "${label}: expected $(printf '%q' "$expected"), got $(printf '%q' "$actual")"
}

assert_contains() {
    local haystack="$1" needle="$2" label="$3"
    [[ ${haystack} == *"${needle}"* ]] || fail "${label}: missing $(printf '%q' "$needle") in $(printf '%q' "$haystack")"
}

path_count() {
    printf '%s\n' "$1" | awk -v needle="$2" -F: '{ count = 0; for (i = 1; i <= NF; i++) if ($i == needle) count++; print count }'
}

# Interactive shells replace an inherited SHELL with their own resolved path.
bash_interactive=$(DOTFILES_TEST_HOME="$fixture_home" SHELL="$wrong_shell" PATH="/bin:/usr/bin" HISTFILE=/dev/null \
    "$bash_bin" --noprofile --norc -i -c \
    'source "$1/bash-shell.sh"; source "$1/bash-path.sh"; source "$1/bash-path.sh"; printf "SHELL=%s\nPATH=%s\n" "$SHELL" "$PATH"' \
    _ "$tmp_dir")
assert_contains "$bash_interactive" "SHELL=${bash_bin}" 'bash interactive SHELL'
bash_path=${bash_interactive##*PATH=}
assert_eq 1 "$(path_count "$bash_path" "${fixture_home}/.local/bin")" 'bash PATH deduplication'

zsh_interactive=$(DOTFILES_TEST_HOME="$fixture_home" SHELL="$wrong_shell" PATH="/bin:/usr/bin" HISTFILE=/dev/null \
    "$zsh_bin" -f -i -c \
    'source "$1/zsh-shell.zsh"; source "$1/zsh-path.zsh"; source "$1/zsh-path.zsh"; print -r -- "SHELL=$SHELL"; print -r -- "PATH=$PATH"' \
    _ "$tmp_dir")
assert_contains "$zsh_interactive" "SHELL=${zsh_bin}" 'zsh interactive SHELL'
zsh_path=${zsh_interactive##*PATH=}
assert_eq 1 "$(path_count "$zsh_path" "${fixture_home}/.local/bin")" 'zsh PATH deduplication'

fish_interactive=$(DOTFILES_TEST_HOME="$fixture_home" SHELL="$wrong_shell" PATH="/bin:/usr/bin" \
    "$fish_bin" --no-config --private -i -c \
    'source "$argv[1]/fish-shell.fish"; source "$argv[1]/fish-path.fish"; source "$argv[1]/fish-path.fish"; printf "SHELL=%s\nPATH=%s\n" "$SHELL" "$PATH"' \
    "$tmp_dir")
fish_resolved=$($fish_bin --no-config --private -c 'status fish-path')
assert_contains "$fish_interactive" "SHELL=${fish_resolved}" 'fish interactive SHELL'
fish_path=${fish_interactive##*PATH=}
assert_eq 1 "$(path_count "$fish_path" "${fixture_home}/.local/bin")" 'fish PATH deduplication'

# Noninteractive shells preserve an inherited SHELL value.
assert_eq "$wrong_shell" "$(DOTFILES_TEST_HOME="$fixture_home" SHELL="$wrong_shell" HISTFILE=/dev/null "$bash_bin" --noprofile --norc -c 'source "$1/bash-shell.sh"; printf "%s" "$SHELL"' _ "$tmp_dir")" 'bash noninteractive SHELL'
assert_eq "$wrong_shell" "$(DOTFILES_TEST_HOME="$fixture_home" SHELL="$wrong_shell" HISTFILE=/dev/null "$zsh_bin" -f -c 'source "$1/zsh-shell.zsh"; print -r -- "$SHELL"' _ "$tmp_dir")" 'zsh noninteractive SHELL'
assert_eq "$wrong_shell" "$(DOTFILES_TEST_HOME="$fixture_home" SHELL="$wrong_shell" "$fish_bin" --no-config --private -c 'source "$argv[1]/fish-shell.fish"; printf "%s" "$SHELL"' "$tmp_dir")" 'fish noninteractive SHELL'

# A nested shell gets its own value while the parent remains unchanged.
nested=$(DOTFILES_TEST_HOME="$fixture_home" SHELL="$wrong_shell" HISTFILE=/dev/null "$bash_bin" --noprofile --norc -i -c \
    'source "$1/bash-shell.sh"; child=$(SHELL="$SHELL" HISTFILE=/dev/null "$2" -f -i -c '\''source "$1/zsh-shell.zsh"; print -r -- "$SHELL"'\'' _ "$1"); printf "parent=%s child=%s" "$SHELL" "$child"' \
    _ "$tmp_dir" "$zsh_bin")
assert_contains "$nested" "parent=${bash_bin}" 'nested parent SHELL'
assert_contains "$nested" "child=${zsh_bin}" 'nested child SHELL'

nested_zsh_fish=$(DOTFILES_TEST_HOME="$fixture_home" SHELL="$wrong_shell" HISTFILE=/dev/null "$zsh_bin" -f -i -c \
    'source "$1/zsh-shell.zsh"; child=$(SHELL="$SHELL" "$2" --no-config --private -i -c '\''source "$argv[1]/fish-shell.fish"; printf "%s" "$SHELL"'\'' "$1"); print -r -- "parent=$SHELL child=$child"' \
    _ "$tmp_dir" "$fish_bin")
assert_contains "$nested_zsh_fish" "parent=${zsh_bin}" 'nested zsh parent SHELL'
assert_contains "$nested_zsh_fish" "child=${fish_resolved}" 'nested fish child SHELL'

# Render and run the bash sourcing ensure script in an isolated HOME. Verify
# the generated login bridge is idempotent and respects an existing quoted
# source line in the first effective startup file.
chezmoi_bin=$(command -v chezmoi || true)
if [[ -n ${chezmoi_bin} ]]; then
    login_state="${tmp_dir}/chezmoi-state.boltdb"
    login_cache="${tmp_dir}/chezmoi-cache"
    login_rendered="${tmp_dir}/ensure-bashrc.sh"
    login_fixture="${tmp_dir}/ensure-bashrc-fixture.sh"
    mkdir -p "${login_cache}"
    "$chezmoi_bin" --config /dev/null --config-format yaml --source "$repo_dir" \
        --persistent-state "$login_state" --cache "$login_cache" \
        execute-template --file "$repo_dir/.chezmoiscripts/run_after_ensure-bashrc-sourcing.sh.tmpl" \
        >"$login_rendered"
    sed -e 's/\${HOME}/\${DOTFILES_TEST_HOME}/g' -e 's/\$HOME/\$DOTFILES_TEST_HOME/g' \
        "$login_rendered" >"$login_fixture"
    login_home="${tmp_dir}/login-home"
    mkdir -p "$login_home"
    DOTFILES_TEST_HOME="$login_home" "$bash_bin" "$login_fixture" >/dev/null 2>&1
    DOTFILES_TEST_HOME="$login_home" "$bash_bin" "$login_fixture" >/dev/null 2>&1
    assert_eq 1 "$(grep -Fc '# dotfiles bootstrap: load ~/.bashrc for interactive login shells' "$login_home/.bash_profile")" 'bash login bridge idempotence'

    rm -f "$login_home/.bash_profile"
    printf 'if [ -f "$DOTFILES_TEST_HOME/.bashrc" ]; then . "$DOTFILES_TEST_HOME/.bashrc"; fi\n' >"$login_home/.bash_login"
    DOTFILES_TEST_HOME="$login_home" "$bash_bin" "$login_fixture" >/dev/null 2>&1
    assert_eq 0 "$(grep -Fc '# dotfiles bootstrap: load ~/.bashrc for interactive login shells' "$login_home/.bash_login")" 'existing quoted bashrc source'

    rm -f "$login_home/.bash_login"
    printf '# . "$DOTFILES_TEST_HOME/.bashrc"\n' >"$login_home/.profile"
    DOTFILES_TEST_HOME="$login_home" "$bash_bin" "$login_fixture" >/dev/null 2>&1
    assert_eq 1 "$(grep -Fc '# dotfiles bootstrap: load ~/.bashrc for interactive login shells' "$login_home/.profile")" 'commented bashrc source ignored'
fi

# Mock chezmoi and the shell re-exec target to test successful and failing ch.
cat >"${tmp_dir}/bin/chezmoi" <<'EOF'
#!/bin/sh
exit "${CH_TEST_STATUS:-0}"
EOF
cat >"${tmp_dir}/bin/mock-shell" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$CH_TEST_LOG"
exit 0
EOF
chmod +x "${tmp_dir}/bin/chezmoi" "${tmp_dir}/bin/mock-shell"

for shell_name in bash zsh; do
    shell_bin=${bash_bin}
    shell_args=(--noprofile --norc -i -c)
    [[ ${shell_name} == zsh ]] && shell_bin=${zsh_bin} && shell_args=(-f -i -c)
    success_log="${tmp_dir}/${shell_name}-success.log"
    PATH="${tmp_dir}/bin:/bin:/usr/bin" CH_TEST_LOG="$success_log" HISTFILE=/dev/null \
        "$shell_bin" "${shell_args[@]}" \
        'source "$1/dot_bashrc.d/chezmoi-aliases"; SHELL="$2"; ch update' \
        _ "$repo_dir" "${tmp_dir}/bin/mock-shell" >/dev/null
    [[ -f ${success_log} ]] || fail "${shell_name} ch update did not re-exec SHELL"
    assert_eq '-l' "$(<"${success_log}")" "${shell_name} successful ch arguments"

    failure_output=$(PATH="${tmp_dir}/bin:/bin:/usr/bin" CH_TEST_STATUS=7 HISTFILE=/dev/null \
        "$shell_bin" "${shell_args[@]}" \
        'source "$1/dot_bashrc.d/chezmoi-aliases"; SHELL="$2"; ch update; printf "RESULT=%s" "$?"' \
        _ "$repo_dir" "${tmp_dir}/bin/mock-shell")
    assert_contains "$failure_output" 'RESULT=7' "${shell_name} failing ch status"
done

fish_success_log="${tmp_dir}/fish-success.log"
PATH="${tmp_dir}/bin:/bin:/usr/bin" CH_TEST_LOG="$fish_success_log" \
    "$fish_bin" --no-config --private -i -c \
    'source "$argv[1]/dot_config/fish/conf.d/chezmoi-aliases.fish"; set -gx SHELL "$argv[2]"; ch update' \
    "$repo_dir" "${tmp_dir}/bin/mock-shell" >/dev/null
[[ -f ${fish_success_log} ]] || fail 'fish ch update did not re-exec SHELL'
assert_eq '-l' "$(<"${fish_success_log}")" 'fish successful ch arguments'

fish_failure=$(PATH="${tmp_dir}/bin:/bin:/usr/bin" CH_TEST_STATUS=7 \
    "$fish_bin" --no-config --private -i -c \
    'source "$argv[1]/dot_config/fish/conf.d/chezmoi-aliases.fish"; set -gx SHELL "$argv[2]"; ch update; printf "RESULT=%s" $status' \
    "$repo_dir" "${tmp_dir}/bin/mock-shell")
assert_contains "$fish_failure" 'RESULT=7' 'fish failing ch status'

printf 'PASS: shell session, nested SHELL, PATH, and ch behavior\n'

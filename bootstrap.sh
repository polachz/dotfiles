#!/bin/sh

# Self-contained dotfiles bootstrap.
#
# Downloaded directly by curl/wget — must not source any other repo file.
# Downloads chezmoi, prompts for profile (personal/work), then runs
# `chezmoi init --apply` against the dotfiles repo.

GITHUB_USERNAME="polachz"

# ───── Helpers ───────────────────────────────────────────────────────────────

log_color() {
  color_code="$1"
  shift
  printf "\033[${color_code}m%s\033[0m\n" "$*" >&2
}

log_red()    { log_color "0;31" "$@"; }
log_blue()   { log_color "0;34" "$@"; }
log_green()  { log_color "1;32" "$@"; }
log_yellow() { log_color "1;33" "$@"; }
log_brown()  { log_color "0;33" "$@"; }
log_task()   { log_blue "🔃" "$@"; }
log_error()  { log_red "❌" "$@"; }
log_info()   { log_blue "ℹ️" "$@"; }
error()      { log_error "$@"; exit 1; }

log_debug_force() { log_brown "🔎" "$@"; }
log_debug() {
    if [ -n "${CHZ_DOTFILES_DEBUG}" ]; then
       log_brown "🔎" "$@"
    fi
}

# ───── Profile menu ──────────────────────────────────────────────────────────

display_menu() {
    echo "Select dotfiles profile:"
    echo
    echo "  1) Personal — private machines, personal email/git/ssh identity"
    echo "  2) Work     — work machines, work email/git/ssh identity"
    echo "  e) Exit"
    echo
}

# ───── CLI parsing ───────────────────────────────────────────────────────────

HELP=$(cat <<EOF
Usage: bootstrap.sh [options]

Options:
  -p, --profile <personal|work>  Pre-select dotfiles profile (skip menu)
  -d, --dry-run                  Run chezmoi in dry-run mode
  -a, --apply                    Force apply (overrides default on re-runs)
  -v, --verbose                  Verbose output
  -r, --reinit                   Clear chezmoi state and re-apply from scratch
  --debug                        Enable debug logging in dotfile scripts
  --chezmoi-debug                Pass --debug to chezmoi itself
  --debug-all                    Both --debug and --chezmoi-debug
  -h, --help                     Show this message

Env vars:
  CHZ_DEPLOYMENT_PROFILE         Same as --profile
  CHZ_BOOTSTRAP_DRY_RUN          Set to 1 to dry-run
  CHZ_BOOTSTRAP_VERBOSE          Set to 1 for verbose output
  CHZ_DOTFILES_DEBUG             Set to 1 to trace dotfile scripts
EOF
)

while [ $# -gt 0 ]; do
    case "$1" in
        -p|--profile)
            CHZ_DEPLOYMENT_PROFILE="$2"
            shift
            ;;
        -d|--dry-run)
            CHZ_BOOTSTRAP_DRY_RUN=1
            ;;
        -v|--verbose)
            CHZ_BOOTSTRAP_VERBOSE=1
            ;;
        --debug)
            CHZ_DOTFILES_DEBUG=1
            ;;
        --chezmoi-debug)
            bootstrap_chezmoi_debug=1
            ;;
        --debug-all)
            bootstrap_chezmoi_debug=1
            CHZ_DOTFILES_DEBUG=1
            ;;
        -a|--apply)
            bootstrap_force_apply=1
            ;;
        -r|--reinit)
            bootstrap_chezmoi_reinit=1
            ;;
        -h|--help)
            echo "$HELP"
            exit 0
            ;;
        *)
            log_error "Unknown cmdline option $1."
            echo "$HELP"
            exit 1
            ;;
    esac
    shift
done

# ───── Resolve profile ───────────────────────────────────────────────────────

if [ -z "${CHZ_DEPLOYMENT_PROFILE-}" ]; then
    while true; do
        display_menu
        printf "Enter your choice: "
        read -r choice
        case "$choice" in
            1) CHZ_DEPLOYMENT_PROFILE="personal"; break;;
            2) CHZ_DEPLOYMENT_PROFILE="work";     break;;
            e|exit) echo "Aborted."; exit 0;;
            *) echo "Invalid selection. Please try again.";;
        esac
    done
fi

case "${CHZ_DEPLOYMENT_PROFILE}" in
    personal|work) ;;
    *) error "Invalid --profile: '${CHZ_DEPLOYMENT_PROFILE}' (must be 'personal' or 'work')";;
esac

log_info "Selected profile: ${CHZ_DEPLOYMENT_PROFILE}"

# ───── Install chezmoi ───────────────────────────────────────────────────────

chezmoi_github_url=""

if command -v "chezmoi" > /dev/null 2>&1; then
    log_info "Chezmoi already installed. Dry run will be provided."
    CHZ_BOOTSTRAP_DRY_RUN="1"
    chezmoi="chezmoi"
else
    log_task "Installing Chezmoi..."
    chezmoi_bin_dir="${HOME}/.local/bin"
    chezmoi="${chezmoi_bin_dir}/chezmoi"
    chezmoi_github_url="https://github.com/${GITHUB_USERNAME}/dotfiles.git"
    if command -v "curl" >/dev/null 2>&1; then
        chezmoi_install_script="$(curl -fsSL https://get.chezmoi.io)"
    elif command -v "wget" >/dev/null 2>&1; then
        chezmoi_install_script="$(wget -qO- https://get.chezmoi.io)"
    else
        error "To install chezmoi, you must have curl or wget installed!"
    fi
    sh -c "${chezmoi_install_script}" -- -b "$chezmoi_bin_dir"
    unset chezmoi_install_script
    log_info "Chezmoi installed successfully."
fi

# ───── Install EJSON if missing ──────────────────────────────────────────────

if ! command -v "ejson" > /dev/null 2>&1; then
    log_task "Installing EJSON..."
    # EJSON release binary — Shopify publishes Linux/macOS amd64 builds.
    ejson_os=$(uname -s | tr '[:upper:]' '[:lower:]')
    ejson_arch=$(uname -m)
    case "${ejson_arch}" in
        x86_64) ejson_arch="amd64";;
        aarch64|arm64) ejson_arch="arm64";;
    esac
    ejson_url="https://github.com/Shopify/ejson/releases/latest/download/ejson_${ejson_os}_${ejson_arch}.tar.gz"
    ejson_bin_dir="${HOME}/.local/bin"
    mkdir -p "${ejson_bin_dir}"
    if command -v "curl" >/dev/null 2>&1; then
        curl -fsSL "${ejson_url}" | tar -xz -C "${ejson_bin_dir}" ejson 2>/dev/null \
            || log_yellow "EJSON download/extract failed — install manually if needed."
    elif command -v "wget" >/dev/null 2>&1; then
        wget -qO- "${ejson_url}" | tar -xz -C "${ejson_bin_dir}" ejson 2>/dev/null \
            || log_yellow "EJSON download/extract failed — install manually if needed."
    fi
fi

# ───── Run chezmoi ───────────────────────────────────────────────────────────

log_task "Preparing Chezmoi run..."

if [ -n "${bootstrap_chezmoi_reinit-}" ]; then
    chezmoi state delete-bucket --bucket=entryState >/dev/null 2>&1
    chezmoi state delete-bucket --bucket=entryState >/dev/null 2>&1
    chezmoi update --init
fi

set -- init

if [ -n "${bootstrap_force_apply-}" ]; then
    set -- "$@" --apply
elif [ -n "${CHZ_BOOTSTRAP_DRY_RUN-}" ]; then
    set -- "$@" --dry-run
else
    set -- "$@" --apply "${chezmoi_github_url}"
fi

if [ -n "${bootstrap_chezmoi_debug-}" ]; then
    set -- "$@" --debug
elif [ -n "${CHZ_BOOTSTRAP_VERBOSE-}" ]; then
    set -- "$@" --verbose
fi

export CHZ_DEPLOYMENT_PROFILE
export CHZ_DOTFILES_DEBUG
export CHZ_BOOTSTRAP_DRY_RUN

log_task "Running 'chezmoi $*' (profile=${CHZ_DEPLOYMENT_PROFILE})"

exec "${chezmoi}" "$@"

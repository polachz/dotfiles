#!/bin/sh

# !! We can't include any other file here !!!
#
# This script is downloaded by curl/wget
# and then directly fired without any other dependencies.

# Define menu with variants for deployment
# The format is  "Menu description @ selected-value"
# with @ as separator  between menu  item 
# and returned value if item is selected
menu_items=(
    "Server VM @ server"
    "Non-GUI Workstation @ workstation"
    "GUI Workstation @ gui-workstation"
    "Work Non-GUI Workstation @ workstation-work"
    "Work GUI Workstation @ gui-workstation-work"
)

function log_color {
  color_code="$1"
  shift

  printf "\033[${color_code}m%s\033[0m\n" "$*" >&2
}

function log_red {
  log_color "0;31" "$@"
}

function log_blue {
  log_color "0;34" "$@"
}

function log_green() {
  log_color "1;32" "$@"
}

function log_yellow() {
  log_color "1;33" "$@"
}

function log_brown() {
  log_color "0;33" "$@"
}
function log_task {
  log_blue "🔃" "$@"
}

function log_error {
  log_red "❌" "$@"
}

function error {
  log_error "$@"
  exit 1
}

function log_info() {
  log_blue "ℹ️" "$@"
}

function log_debug_force() {
    log_brown "🔎" "$@"
}

function log_debug() {
    if [ -n "${CHZ_DOTFILES_DEBUG}" ]; then
       log_brown "🔎" "$@"
    fi
}


# Function to display menu
function display_menu {
    echo "Please select an option:"
    echo
    for i in "${!menu_items[@]}"; do
        IFS="@" read -r desc value <<< "${menu_items[$i]}"
        echo "$((i+1))) $desc"
    done
    echo "e) Exit"
}

while [[ "$#" -gt 0 ]]; do

    if [ -n "${DEBUG_SCRIPT}" ]; then
        log_debug_force "Processing cmdline param ${1}"
    fi

    case ${1} in
        -o|--one-shot)
        CHZ_BOOTSTRAP_ONE_SHOT=1
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
        -i|--deployment-id)
        CHZ_DEPLOYMENT_STRING_ID="${2}"
        shift # value
        ;;  
        -r|--reinit)
        bootstrap_chezmoi_reinit=1
        shift # value
        ;;  
        -h|--help)
        echo "$HELP"
        exit 0
        ;;
        *) # unknown option
        log_error "Unknown cmdline option ${1}."
        echo "$HELP" 
        exit 1
        ;;
    esac
    shift # arg
done
if [ -n "${CHZ_BOOTSTRAP_ONE_SHOT-}" ]; then
    # For one shoot, select server deployment type
    export CHZ_DEPLOYMENT_STRING_ID="server"
fi
if [ -z "${CHZ_DEPLOYMENT_STRING_ID-}" ]; then
    # Deployment Id is empty, ask for it
    echo
    while true; do
        display_menu
        echo
        read -p "Enter your choice: " choice
        if [[ $choice == "e" || $choice == "exit" ]]; then
            echo "Selection has been aborted. Exiting..."
            exit 0
        elif [[ $choice -ge 1 && $choice -le ${#menu_items[@]} ]]; then
            IFS="@" read -r menu_item_name menu_selection <<< "${menu_items[$((choice-1))]}"
            #trim spaces 
            menu_selection="${menu_selection// /}"
            menu_item_name="${menu_item_name%"${menu_item_name##*[![:space:]]}"}"
            
        echo
        break;
        else
            echo "Invalid selection. Please try again."
        fi
    done
    log_info " You have selected: \"$menu_item_name\""
    export CHZ_DEPLOYMENT_STRING_ID="${menu_selection}"
fi

chezmoi_github_user=""

if  command -v "chezmoi" > /dev/null 2>&1 ; then
    log_info "Chezmoi already installed. Dry run will be provided"
    CHZ_BOOTSTRAP_DRY_RUN="1"
    chezmoi="chezmoi"
else
    log_task "Installing Chezmoi..."
    chezmoi_bin_dir="${HOME}/.local/bin"
    chezmoi="${chezmoi_bin_dir}/chezmoi"
    chezmoi_github_user="polachz"
    if command -v "curl" >/dev/null 2>&1; then
        chezmoi_install_script="$(curl -fsSL https://get.chezmoi.io)"
    elif command -v "wget" >/dev/null 2>&1; then
        chezmoi_install_script="$(wget -qO- https://get.chezmoi.io)"
    else
        error "To install chezmoi, you must have curl or wget installed!"
    fi
    # Provide chezmoi installation:
    sh -c "${chezmoi_install_script}" -- -b "$chezmoi_bin_dir"
    unset chezmoi_install_script bin_dir
    #sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply polachz
    log_info "Chezmoi installed successfully."
fi
# Prepare for chezmoi run
#
log_task "Preparing Chezmoi run..."

if [ -n "${bootstrap_chezmoi_reinit-}" ]; then
chezmoi state delete-bucket --bucket=entryState >/dev/null 2>&1
chezmoi state delete-bucket --bucket=entryState >/dev/null 2>&1
chezmoi update --init
fi
set -- init

if [ -n "${bootstrap_force_apply-}" ]; then
    set -- "$@" --apply
elif [ -n "${CHZ_BOOTSTRAP_ONE_SHOT-}" ]; then
  set -- "$@" --one-shot
elif [ -n "${CHZ_BOOTSTRAP_DRY_RUN-}" ]; then
    set -- "$@" --dry-run
else
    set -- "$@" --apply "${chezmoi_github_user}"
fi
if [ -n "${bootstrap_chezmoi_debug-}" ]; then
    set -- "$@" --debug
elif [ -n "${CHZ_BOOTSTRAP_VERBOSE-}" ]; then
    set -- "$@" --verbose
fi
#
export CHZ_DOTFILES_DEBUG
export CHZ_BOOTSTRAP_ONE_SHOT
export CHZ_BOOTSTRAP_DRY_RUN

log_task "Running 'chezmoi $*'"
#chezmoi execute-template --init < .chezmoi.yaml.tmpl
# replace current process with chezmoi
#exec "${chezmoi}" init
exec "${chezmoi}" "$@"
log_info "Chezmoi config tasks finished successfully"

#make chezmoi config readable only by me
chmod 0600 "${HOME}/.config/chezmoi/chezmoi.yaml"

exit 0

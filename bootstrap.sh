#!/bin/sh

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

if [ -z "${CHEZMOI_BOOTSTRAP_ONE_SHOT-}" ]; then
    #we can ask for deployment type if one shoot is not defined
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
else
    # For one shoot, select server deployment type
    menu_selection="server"
fi

export CHEZMOI_DEPLOYMENT_STRING_ID="${menu_selection}"
echo "$CHEZMOI_DEPLOYMENT_STRING_ID"

if  command -v "chezmoi" > /dev/null 2>&1 ; then
    log_info "Chezmoi already installed. Dry run will be provided"
    CHEZMOI_BOOTSTRAP_DRY_RUN="1"
    chezmoi="chezmoi"
else
    log_task "Installing Chezmoi..."
    chezmoi_bin_dir="$HOME/.local/bin"
    chezmoi="$bin_dir/chezmoi"
    if command -v "curl" >/dev/null 2>&1; then
        chezmoi_install_script="$(curl -fsSL https://get.chezmoi.io)"
    elif command -v "wget" >/dev/null 2>&1; then
        chezmoi_install_script="$(wget -qO- https://get.chezmoi.io)"
    else
        error "To install chezmoi, you must have curl or wget installed!"
    fi
    # Provide chezmoi installation:
    sh -c "${chezmoi_install_script}" -- -b "$chezmoi_bin_dir"
    #sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply polachz
    log_info "Chezmoi installed successfully."
fi
# Prepare for chezmoi run
log_task "Preparing Chezmoi run..."
set -- init
# 
if [ -n "${CHEZMOI_BOOTSTRAP_ONE_SHOT-}" ]; then
  set -- "$@" --one-shot
else
    if [ -n "${CHEZMOI_BOOTSTRAP_DRY_RUN-}" ]; then
        #set -- "$@" --dry-run --debug
        set -- "$@" --apply
    else
        set -- "$@" --apply
    fi
fi

log_task "Running 'chezmoi $*'"
#chezmoi execute-template --init < .chezmoi.yaml.tmpl
# replace current process with chezmoi
#exec "${chezmoi}" init
exec "${chezmoi}" "$@"
log_info "Chezmoi config tasks finished successfully"

#make chezmoi config readable only by me
chmod 0600 "${HOME}/.config/chezmoi/chezmoi.yaml"

exit 0

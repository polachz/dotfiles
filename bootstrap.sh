#!/bin/bash

# Define menu with variants for deployment
# The format is  "Menu description @ selected-value"
# with @ as separator  between menu  item 
# and returned value if item is selected
menu_items=(
    "Server VM @ server"
    "Non-GUI Workstation @ non-gui"
    "GUI Workstation @ gui"
    "Work Non-GUI Workstation @ non-gui-work"
    "Work GUI Workstation @ gui-work"
)

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

# Main loop
echo
while true; do
    display_menu
    echo
    read -p "Enter your choice: " choice
    if [[ $choice == "e" || $choice == "exit" ]]; then
        echo "Selection has been aborted. Exiting..."
        exit 0
    elif [[ $choice -ge 1 && $choice -le ${#menu_items[@]} ]]; then
        IFS="@" read -r MENU_ITEM_NAME MENU_SELECTION <<< "${menu_items[$((choice-1))]}"
        #trim spaces 
        MENU_SELECTION="${MENU_SELECTION// /}"
        MENU_ITEM_NAME="${MENU_ITEM_NAME%"${MENU_ITEM_NAME##*[![:space:]]}"}"
	echo
	break;
    else
        echo "Invalid selection. Please try again."
    fi
done

echo " You have selected: \"$MENU_ITEM_NAME\""

export CHEZMOI_DEPLOYMENT_TYPE="${MENU_SELECTION}"
echo "$CHEZMOI_DEPLOYMENT_TYPE"

if  command -v "chezmoi" > /dev/null 2>&1 ; then
    echo "Chezmoi already installed. Dry run will be provided"
    BOOTSTRAP_DRY_RUN="1"
else
    echo "Installing Chezmoi..."
    sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply polachz
    echo "Chezmoi installed successfully."
fi


chezmoi execute-template --init < .chezmoi.yaml.tmpl

exit 0

#!/usr/bin/env bash
# Common shell functions — github release helpers, systemd checks, editor wrapper.

# Gets download url for latest release of a project on github.
# Return value stored in: zpfn_ret_github_download_url
function zpfn_get_github_project_latest_release_download_link {
   local user_and_repo=$1
   local grep_search_pattern=$2

   zpfn_ret_github_download_url=$( \
      curl -s "https://api.github.com/repos/${user_and_repo}/releases/latest" \
      | grep "browser_download_url.*${grep_search_pattern}" \
      | cut -d : -f 2,3 \
      | tr -d '\"' \
   )
   echo "${zpfn_ret_github_download_url}"
}
export -f zpfn_get_github_project_latest_release_download_link

# Gets version number for latest release of a project on github.
# Return value stored in: zpfn_ret_github_project_version_number
function zpfn_get_github_project_latest_release_version_number {
   local user_and_repo=$1
   local grep_search_pattern=$2
   local github_url=''

   github_url=$(zpfn_get_github_project_latest_release_download_link "${user_and_repo}" "${grep_search_pattern}")
   zpfn_ret_github_project_version_number=$(basename $(dirname "${github_url}"))
   echo "$zpfn_ret_github_project_version_number"
}
export -f zpfn_get_github_project_latest_release_version_number

# Checks if a systemd service exists.
# Returns 0 (OK) when exists, 1 otherwise.
function zpfn_systemd_service_exists {
  local service_name=$1
  if [[ $(systemctl list-units --all -t service --full --no-legend "${service_name}.service" | sed 's/^\s*//g' | cut -f1 -d' ') == ${service_name}.service ]]; then
    return 0
  else
    return 1
  fi
}
export -f zpfn_systemd_service_exists

# ANSI color escape helper. Usage: color 0 31 (dark red)
##################
# Code # Color   #
##################
#  00  # Off     #
#  30  # Black   #
#  31  # Red     #
#  32  # Green   #
#  33  # Yellow  #
#  34  # Blue    #
#  35  # Magenta #
#  36  # Cyan    #
#  37  # White   #
##################
function color {
  echo "\033[$1;$2m"
}
export -f color

# Wrapper that opens $EDITOR with given args.
function zpfn_edit {
    "${EDITOR}" "$@"
}

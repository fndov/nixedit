SCRIPT_DIR=$(dirname "$0")

default_operation() {
  if ! sudo true; then
    exit 1
  fi
  update_search
  "$HOME/.nix-profile/lib/nixedit/nsearch" "$@" > /dev/null
  config
  update_system
  update_search
  rebuild
  upload
  delete
  optimise
}

update() {
  update_system
  update_search
}

update_system() {
  task_with_timer "updating pacakges database" "nix-channel --update > /dev/null" "directory" "failed to update package database." "updating database complete. "
}

update_search() {
  "$HOME/.nix-profile/lib/nixedit/nsearch" --check > /dev/null 2>&1 &
  pid=$!
  start=$(date +%s)
  if ! (sleep 0.00000000001; ps -p $pid > /dev/null); then
    # If the command finishes within 0.25 seconds, skip the output
    wait $pid
    return
  fi
  while ps -p $pid > /dev/null; do
    elapsed=$(( $(date +%s) - start ))
    sec=$(( elapsed % 60 ))
    min=$(( elapsed / 60 ))
    if [ $min -eq 0 ]; then
      printf "\redit: [%2d sec ] updating search..." $sec
    else
      printf "\redit: [ %d min ] updating search..." $min
    fi
    sleep 1
  done
  elapsed=$(( $(date +%s) - start ))
  sec=$(( elapsed % 60 ))
  min=$(( elapsed / 60 ))
  if [ $min -eq 0 ]; then
    printf "\redit: [%2d sec ] updating search complete\n" $sec
  else
    printf "\redit: [ %d min ] updating search complete\n" $min
  fi
}

search() {
  "$HOME/.nix-profile/lib/nixedit/nsearch"
}

config() {
  sudo micro /etc/nixos/configuration.nix
}

rebuild() {
  sudo true
  task_with_timer "rebuilding" "sudo nixos-rebuild switch" "error" "rebuild failed." "rebuild complete.   "
}

upload() {
  cd ~/.config/nixedit/
  cp -f /etc/nixos/configuration.nix ~/.config/nixedit/Configuration/configuration.nix-$(date +%m-%d-%H:%M)
  git add . > /dev/null 2>&1

  git commit -m "NixOS configuration save." > /dev/null 2>&1
  task_with_timer "uploading configuration" "git push -u origin main --force" "error" "upload failed." "upload complete.           "
}

github() {
  mkdir ~/.config/nixedit/ > /dev/null 2>&1 
  mkdir ~/.config/nixedit/Configuration/ > /dev/null 2>&1 
  mkdir ~/.config/nixedit/Flake/ > /dev/null 2>&1 
  mkdir ~/.config/nixedit/Home/ > /dev/null 2>&1 

  rm -rf ~/.config/nixedit/.git > /dev/null 2>&1 
  cd ~/.config/nixedit > /dev/null 2>&1 
  cp -f /etc/nixos/configuration.nix ~/.config/nixedit/Configuration/configuration.nix-$(date +%m-%d-%H:%M)
  
  git init > /dev/null 2>&1
  git config --global user.name "nixedit" > /dev/null 2>&1
  git config --global user.email "miyu@allthingslinux.com" > /dev/null 2>&1
  git add . > /dev/null 2>&1
  git commit -m "NixOS Backup" > /dev/null 2>&1
  
  echo nixedit: Open https://github.com/new and create a new repository.
  read -p "URL: " repo
  
  git remote add origin "$repo" > /dev/null 2>&1
  git checkout -b main > /dev/null 2>&1
  git checkout main origin/main > /dev/null 2>&1
  
  output=$(git push -u origin main --force 2>&1)
  if echo "$output" | grep -q "branch 'main' set up to track 'origin/main'"; then
    echo "nixedit: Configuration synced."
  else
    echo "nixedit: Sync failed! Check URL or token settings."
    exit 1
  fi
}

delete() {
  sudo true
  task_with_timer "deleting old packages" "sudo nix-collect-garbage --delete-older-than 1d" "error" "failed to delete packages." "deleting packages complete"
}

optimise() {
  task_with_timer "optimising storage" "nix-store --optimise" "error" "optimising has failed." "optimising storage complete."
}

task_with_timer() {
  local task_description=$1
  local command=$2
  local error_word=$3
  local error_message=$4
  local success_message=$5

  local start_time=$(date +%s)
  echo -ne "edit: [ 0 sec ] $task_description\r"
  stopwatch "$task_description" &
  local stopwatch_pid=$!
  local output=$($command 2>&1)
  kill "$stopwatch_pid"
  wait "$stopwatch_pid" 2>/dev/null
  local final_time=$(get_elapsed_time "$start_time")

  if echo "$output" | grep -q "$error_word"; then
    printf "\redit: [ %s ] $error_message\n" "$(format_time "$final_time")"
    echo "$output"
    exit 1
  else
    printf "\redit: [ %s ] $success_message   \n" "$(format_time "$final_time")"
  fi
}

format_time() {
  local total_seconds=$1
  if (( total_seconds >= 60 )); then
    local minutes=$((total_seconds / 60))
    printf "%d min" "$minutes"
  else
    printf "%d sec" "$total_seconds"
  fi
}

stopwatch() {
  local task_description=$1
  local start_time=$(date +%s)
  while true; do
    local current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    printf "\redit: [ %s ] %s..." "$(format_time "$elapsed_time")" "$task_description"
    sleep 1
  done
}

get_elapsed_time() {
  local start_time=$1
  local end_time=$(date +%s)
  echo $((end_time - start_time))
}

graph() {
  nix-tree
}

list() {
  sudo true && sudo nix-env -p /nix/var/nix/profiles/system --list-generations 
}

find() {
  if [ -z "$2" ]; then
    echo "Usage: nixedit --find <package-name>"
    exit 1
  fi

  local search_term="$2"
  cd /nix/store && ls | grep "$search_term"
}

version() {
  echo nixedit 1.0
}

help() {
  echo "Usage: nixedit [--OPTION]

    A tool for managing your NixOS Configuration & System. Automate NixOS at every step.
    
    Startup commands:
      --github        Connect your github repository and backup NixOS configuration.
      --update        Update the NixPkgs & search, databases.

    Singular options:
      --help          Show this help message and exit.
      --version       Display current nixedit version.

      --search        Search packages.
      --config        Open configuration.
      --list          List pervious generations
      --upload        Upload configuration.
      --rebuild       Rebuild system.
      --optimise      Optimize Nix storage for performance.
      --delete        Delete older packages.
      --graph         Browse dependency graph
      --find          Find local packages
          
    If no option is provided, the default operation will:
      - Perform a search
      - Open the configuration file for editing
      - List system generations
      - Rebuild the system
      - Upload configuration to repository
      - Delete old packages"
}

# Check which argument was passed
case "$1" in
  --github)
    github
    ;;
  --optimise)
    optimise
    ;;
  --upload)
    upload
    ;;
  --update)
    update
    ;;
  --help)
    help
    ;;
  --version)
    version
    ;;
  --graph)
    graph
    ;;
  --search)
    search
    ;;
  --config)
    config
    ;;
  --rebuild)
    rebuild
    ;;
  --list)
    list
    ;;
  --delete)
    delete
    ;;
  --find)
    find "$@"
    ;;
  --check)
    check
    ;;
  *)
    default_operation
    ;;
esac

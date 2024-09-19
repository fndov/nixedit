SCRIPT_DIR=$(dirname "$0")

stopwatch() {
  local start_time=$(date +%s)
  local status_message="$1"
  while true; do
    local current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    if [ "$elapsed_time" -lt 60 ]; then
      printf "\redit: [ %d sec ] %s" "$elapsed_time" "$status_message"
    else
      local minutes=$((elapsed_time / 60))
      local seconds=$((elapsed_time % 60))
      printf "\redit:                                                         "
      printf "\redit: [ %d min ] %s" "$minutes" "$status_message"
    fi
    
    sleep 1
  done
}

get_elapsed_time() {
  local start_time=$1
  local end_time=$(date +%s)
  echo $((end_time - start_time))
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
    printf "\redit: [ %d sec ] $error_message\n" "$final_time"
    echo "$output"
    exit 1
  else
    printf "\redit: [ %d sec ] $success_message   \n" "$final_time"
  fi
}

default_operation() {
  if ! sudo true; then
    exit 1
  fi
  "$HOME/.nix-profile/lib/nixedit/nsearch" "$@" > /dev/null
  config
  rebuild
  list
  upload
  delete
}

# github setup
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

optimise() {
  task_with_timer "optimising storage..." "nix-store --optimise" "error" "optimising has failed." "optimising storage complete."
}

update() {
  task_with_timer "updating pacakges database..." "nix-channel --update > /dev/null" "error" "failed to update package database." "updated package database. "
  task_with_timer "updating search..." "./nsearch.sh --update > /dev/null" "error" "failed to update search" "updated search."
}

upload() {
  cd ~/.config/nixedit/
  cp -f /etc/nixos/configuration.nix ~/.config/nixedit/Configuration/configuration.nix-$(date +%m-%d-%H:%M)
  git add . > /dev/null 2>&1
  git commit -m "NixOS configuration save." > /dev/null 2>&1
  task_with_timer "uploading configuration..." "git push -u origin main --force" "error" "upload failed." "upload complete.           "
}

delete() {
  sudo true
  task_with_timer "deleting old packages..." "sudo nixos-rebuild switch" "error" "failed to delete packages." "deleted old packages."
}

graph() {
  nix-tree
}

search() {
  "$HOME/.nix-profile/lib/nixedit/nsearch"
}

config() {
  sudo micro /etc/nixos/configuration.nix
}

rebuild() {
  sudo true
  task_with_timer "rebuilding..." "sudo nixos-rebuild switch" "error" "rebuild failed." "rebuild complete.   "
}

list() {
  sudo true && sudo nix-env -p /nix/var/nix/profiles/system --list-generations 
}

find() {
  if [ -z "$2" ]; then
    echo "Usage: nixedit --find <search-term>"
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
  *)
    default_operation
    ;;
esac

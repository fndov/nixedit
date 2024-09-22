SCRIPT_DIR=$(dirname "$0")

nsearch() {
  CACHE_DIR="${NSEARCH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/nixedit}"
  FZF_CMD="${NSEARCH_FZF_CMD:-fzf --multi --preview-window=top,3,wrap}"

  program_check() {
    if ! command -v "$1" >/dev/null; then
      echo "error: $1 is not installed."
      exit 1
    fi
  }

  all_checks() {
    program_check "nix"
    program_check "jq"
    program_check "fzf"
  }

  checks() {
    all_checks
    if [ ! -d "$CACHE_DIR" ]; then
      echo "error: cache directory does not exist."
      mkdir -p "$CACHE_DIR"
      echo "edit: cache directory created."
    fi
    if [ ! -f "$CACHE_DIR/db.json" ]; then
      echo "error: database not available."
      if ! update; then
        echo "error: failed to update database, check network."
        exit 1
      fi
    fi

    if [ $# -eq 1 ]; then
      echo "edit: all checks passed."
    fi
  }

  loading() {
    pid=$!
    i=1
    sp="\|/-"
    printf "%s" "$1"
    while ps -p $pid >/dev/null; do
      printf "\b%c" "${sp:i++%4:1}"
      sleep 0.1
    done
    echo ""
  }

  update() {
    mkdir -p "$CACHE_DIR"
    nix search nixpkgs --json "" 2>/dev/null 1>"$CACHE_DIR/db.json" &
    loading "edit: updating the local Database."
    echo "edit: database updated."
  }

  preview_data() {
    attrs="$(jq -r '. | keys[]' <"$CACHE_DIR/db.json" |
      cut -d \. -f 1-2 |
      uniq |
      head -n1)"

    pname="$(jq -r ".\"$attrs.$1\".pname" <"$CACHE_DIR/db.json")"
    description="$(jq -r ".\"$attrs.$1\".description" <"$CACHE_DIR/db.json")"
    version="$(jq -r ".\"$attrs.$1\".version" <"$CACHE_DIR/db.json")"

    cat <<EOF | fold -s -w $COLUMNS
Package Name: $pname
Version: $version
Description: $description
EOF
  }

  isearch() {
    export CACHE_DIR
    export -f preview_data
    jq -r ". | keys[]" <"$CACHE_DIR/db.json" |
      cut -d \. -f 3- |
      ${FZF_CMD} --preview='bash -c "source <(declare -f preview_data); preview_data {}"' |
      xargs
  }

  # Argument handler
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
    -h | --help)
      help
      exit 0
      ;;
    -u | --update)
      update
      exit 0
      ;;
    -c | --check)
      checks 1
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      help
      exit 1
      ;;
    esac
  done

  # Default behavior if no arguments are provided
  checks
  isearch
}

default_operation() {
  if ! sudo true; then
    exit 1
  fi
  update_search # 
  search "$@" > /dev/null
  config
# list
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
  task_with_timer "updating pacakges database" "nix-channel --update > /dev/null" "error" "failed to update package database" "update database complete"
}

update_search() {
  nsearch --check > /dev/null 2>&1 &
  pid=$!
  start=$(date +%s)

  if ! (sleep 0.00000000001; ps -p $pid > /dev/null); then
    wait $pid
    return
  fi

  while ps -p $pid > /dev/null; do
    elapsed=$(( $(date +%s) - start ))
    sec=$(( elapsed % 60 ))
    min=$(( elapsed / 60 ))

    if [ $min -eq 0 ]; then
      printf "\redit: [ %d sec ] updating search...\033[0K" $sec
    else
      printf "\redit: [ %d min ] updating search...\033[0K" $min
    fi
    
    sleep 1
  done

  elapsed=$(( $(date +%s) - start ))
  sec=$(( elapsed % 60 ))
  min=$(( elapsed / 60 ))

  if [ $min -eq 0 ]; then
    printf "\redit: [ %d sec ] update search complete.\033[0K\n" $sec
  else
    printf "\redit: [ %d min ] update search complete.\033[0K\n" $min
  fi
}

search() {
  update_search 
  nsearch "$@"
}

check() {
  nsearch --check
}

config() {
  sudo micro /etc/nixos/configuration.nix
}

rebuild() {
  sudo true
  task_with_timer "rebuilding" "sudo nixos-rebuild switch" "error" "rebuild failed" "rebuild complete"
}

upload() {
  DIR="$HOME/.nixedit/"
  # Check if the directory exists
  if [ -d "$DIR" ]; then
  cd ~/.nixedit/

  cp -f /etc/nixos/configuration.nix ~/.nixedit/Configuration/configuration.nix-$(date +%m-%d-%H:%M) > /dev/null 2>&1 
  if [ $? -eq 0 ]; then
      true
  else
      echo "edit: [ 0 sec ] upload failed, use --github to get started."
    return
  fi

  git add . > /dev/null 2>&1

  git commit -m "Automatic backup" > /dev/null 2>&1
  task_with_timer "uploading configuration" "git push -u origin main --force" "file" "upload failed, use --github to get started" "upload complete"
  fi
}

github() {
  mkdir ~/.nixedit/ > /dev/null 2>&1 
  mkdir ~/.nixedit/Configuration/ > /dev/null 2>&1 
  mkdir ~/.nixedit/Flake/ > /dev/null 2>&1 
  mkdir ~/.nixedit/Home/ > /dev/null 2>&1 

  rm -rf ~/.nixedit/.git > /dev/null 2>&1 
  cd ~/.nixedit/ > /dev/null 2>&1 
  cp -f /etc/nixos/configuration.nix ~/.nixedit/Configuration/configuration.nix-$(date +%m-%d-%H:%M)
  
  git init > /dev/null 2>&1
  git config --global user.name "nixedit" > /dev/null 2>&1
  git config --global user.email "miyu@allthingslinux.com" > /dev/null 2>&1
  git add . > /dev/null 2>&1
  git commit -m "NixOS Backup" > /dev/null 2>&1
  
  echo "Open https://github.com/new and create a new repository."
  read -p "URL: " repo
  
  git remote add origin "$repo" > /dev/null 2>&1
  git checkout -b main > /dev/null 2>&1
  git checkout main origin/main > /dev/null 2>&1
  
  output=$(git push -u origin main --force 2>&1)
  if echo "$output" | grep -q "branch 'main' set up to track 'origin/main'"; then
    echo "Configuration synced."
  else
    echo "Sync failed, check URL or token settings."
    exit 1
  fi
}

delete() {
  sudo true
  task_with_timer "deleting old packages" "sudo nix-collect-garbage --delete-older-than 1d" "error" "failed to delete packages" "deletion complete"
}

debug() {
  rm -rf ~/.cache/nixedit > /dev/null 2>&1
  rm -rf ~/.nixedit/Home/ ~/.nixedit/Configuration/ ~/.nixedit/Flake/
  echo "debug: nixedit reset complete."
}

optimise() {
  task_with_timer "optimising storage" "nix-store --optimise" "error" "optimising has failed" "optimisation complete"
}

task_with_timer() {
  local task_description=$1
  local command=$2
  local error_word=$3
  local error_message=$4
  local success_message=$5

  local start_time=$(date +%s)
  echo -ne "edit: [ 0 sec ] $task_description\033[0K\r"
  stopwatch "$task_description" &
  local stopwatch_pid=$!
  local output=$($command 2>&1)
  kill "$stopwatch_pid"
  wait "$stopwatch_pid" 2>/dev/null
  local final_time=$(get_elapsed_time "$start_time")

  if echo "$output" | grep -q "$error_word"; then
    printf "\rerror: [ %s ] $error_message.\033[0K\n" "$(format_time "$final_time")"
    echo "$output"
    exit 1
  else
    printf "\redit: [ %s ] $success_message.\033[0K\n" "$(format_time "$final_time")"
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
    printf "\redit: [ %s ] %s...\033[0K" "$(format_time "$elapsed_time")" "$task_description"
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
  echo nixedit 0.8
}

help() {
  echo "Usage: nixedit [--OPTION]

NixOS build automating utility, for your Configuration & System. Streamlined process.

Setup commands:
  --github        Connect your dedicated github repository to store backups.
  
Singular options:
  --help          Show this help message and exit
  --version       Display current nixedit version
  
  --search        Search packages
  --config        Open configuration
  --list          List pervious generations
  --upload        Upload configuration
  --update        Update the nixpkgs & search, databases
  --rebuild       Rebuild system
  --delete        Delete older packages
  --optimise      Optimize Nix storage
  --graph         Browse dependency graph
  --find          Find local packages
        
If no option is provided, the default operation will:
  - Perform a search
  - Open the configuration file for editing
  - Update system packages
  - Rebuild the system
  - Upload configuration to repository
  - Delete old packages
  - Optimise package storage"

#  Development options:
#  --debug         Reset all nixedit data
#  --check         Check search functionality
}

# Check if any arguments were provided
if [ $# -eq 0 ]; then
  default_operation
  exit 0
fi

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
  --debug)
    debug
    ;;
  *)
    echo "Unknown option: '$1'"
    echo "Try 'nixedit --help' for more information."
    exit 1
    ;;
esac

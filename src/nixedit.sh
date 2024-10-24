nsearch() {
  CACHE_DIR="${NSEARCH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/nixedit}"
  FZF_CMD="${NSEARCH_FZF_CMD:-fzf --multi --preview-window=top,3,wrap}"

  program_check() {
    if ! command -v "$1" >/dev/null; then
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
      mkdir -p "$CACHE_DIR"
    fi
    if [ ! -f "$CACHE_DIR/db.json" ]; then
      if ! update; then
        exit 1
      fi
    fi
  }

  loading() {
    pid=$!
    i=1
    sp=""
    printf "%s" "$1"
    while ps -p $pid >/dev/null; do
      sleep 0.1
    done
  }

  update() {
    mkdir -p "$CACHE_DIR"
    nix search nixpkgs --extra-experimental-features nix-command --extra-experimental-features flakes --json "" 2>/dev/null 1>"$CACHE_DIR/db.json" &
    loading "edit: updating the local database."
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
      help
      exit 1
      ;;
    esac
  done

  checks
  isearch > /dev/null
}

default_operation() {

  if [ "$UID" -eq 0 ]; then
  echo "There's no need to use sudo in the command."
  exit 1
  fi
  if ! sudo true; then
    exit 1
  fi
  # Collecition of functions
  search
  configure 0
  update_system
  rebuild
  upload
  delete
  optimise

}

update_system() {
  if [ "$UID" -eq 0 ]; then
  echo "There's no need to use sudo in the command."
  exit 1
  fi
  if ! sudo true; then
    exit 1
  fi
  task_with_timer "updating channel" "sudo nix-channel --update > /dev/null" "error" "failed to update channel" "update channel complete"
}

update_search() {
  nsearch --check &
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
  nsearch 
}

check() {
  nsearch --check
}

configure() {
  if [ "$UID" -eq 0 ]; then
    echo "There's no need to use sudo in the command."
    exit 1
  fi

  if ! sudo true; then
    exit 1
  fi

  if [ "$#" -eq 1 ]; then
    sudo micro /etc/nixos/configuration.nix
  elif [ "$#" -eq 2 ] && [[ "$2" =~ ^[0-9]+$ ]]; then
    sudo micro +$2 /etc/nixos/configuration.nix
  else
    echo "Usage: nixedit --configure/-c <number> open file at line"
    exit 1
  fi
}

rebuild() {
  if [ "$UID" -eq 0 ]; then
    echo "There's no need to use sudo in the command."
    exit 1
  fi

  if ! sudo true; then
    exit 1
  fi

  if [ $# -gt 2 ]; then
    echo "Usage: --rebuild <profile_name>"
    echo "Povided <profile-name> a profile will be built, otherwise a generation will be built."
    exit 1
  fi

  if [ -n "$2" ]; then
    profile_name=$2
    
    if [[ $profile_name =~ ^[0-9] ]]; then
      echo "error: profile name cannot start with a number."
      exit 1
    fi
  
    task_with_timer "rebuilding $profile_name profile" \
      "sudo nixos-rebuild switch --profile-name $profile_name" \
      "error" "rebuild $profile_name profile failed" \
      "rebuild $profile_name profile complete"
  else
    task_with_timer "rebuilding generation" \
      "sudo nixos-rebuild switch" \
      "error" "rebuild failed" "rebuild generation complete"
  fi
}

upload() {
  DIR="$HOME/.nixedit/"
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

update_package_age() {
    local CACHE_DIR="$HOME/.cache/nixedit"
    local CACHE_FILE="$CACHE_DIR/package-age.txt"

    mkdir -p "$CACHE_DIR"

    if [[ ! -f "$CACHE_FILE" ]]; then
      echo "1" > "$CACHE_FILE"
      echo "Created $CACHE_FILE with value 1."
      return 0
    fi

    local CONTENT
    CONTENT=$(<"$CACHE_FILE")

    if [[ -z "$CONTENT" ]]; then
      echo "1" > "$CACHE_FILE"
      echo "Initialized $CACHE_FILE with value 1."
    else
      echo "$CACHE_FILE already contains data: $CONTENT"
      return 0
    fi
}

delete() {
  if [ "$UID" -eq 0 ]; then
    echo "There's no need to use sudo in the command."
    exit 1
  fi
  if ! sudo true; then
    exit 1
  fi

  update_package_age > /dev/null
  PACKAGE_AGE=$(<"$HOME/.cache/nixedit/package-age.txt")

  if [[ -n "$3" ]]; then
    echo "Usage: nixedit --delete/-d <profile-name>/<number> days old packages, default $PACKAGE_AGE"
    exit 1
  fi

  if [[ -z "$2" ]]; then
    days="$PACKAGE_AGE" 
  elif [[ "$2" =~ ^[0-9]+$ ]]; then
    days="$2"
    if [ "$days" -eq 1 ]; then
      day_label="day"
    else
      day_label="days"
    fi
    task_with_timer "deleting packages older than $days $day_label" "sudo nix-collect-garbage --delete-older-than ${days}d" "Permission denied" "failed to delete packages" "deletion complete"
    return 0
  elif [[ "$2" =~ ^[[:alpha:][:punct:]] ]]; then
    if ls /nix/var/nix/profiles/system-[0-9]* &> /dev/null; then
      echo edit: deleted $2 profile.
      sudo rm -rf /nix/var/nix/profiles/system-profiles/$2* > /dev/null
    else
      echo "error: there are no existing generations to fallback on, cannot safely delete profile."
      exit 1
    fi
    return 0  
  fi
  task_with_timer "deleting old packages" "sudo nix-collect-garbage --delete-older-than ${days}d" "error" "failed to delete packages" "deletion complete"
}

debug() {
  rm -rf ~/.cache/nixedit > /dev/null 2>&1
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

generation() {
  if [ "$UID" -eq 0 ]; then
  echo "There's no need to use sudo in the command."
  exit 1
  fi
  if ! sudo true; then
    exit 1
  fi
  sudo nix-env -p /nix/var/nix/profiles/system --list-generations 
}

profile() {
  if [[ $2 =~ ^[0-9] ]]; then
    echo "error: profile name cannot start with a number."
    exit 1
  fi
  if [ $# -eq 0 ]; then
    echo "No arguments provided."
  elif [ $# -eq 1 ]; then
    true
  else
    if [ "$UID" -eq 0 ]; then
    echo "There's no need to use sudo in the command."
    exit 1
    fi
    if ! sudo true; then
      exit 1
    fi
    search > /dev/null
    configure 0
    update_system
    rebuild --rebuild $2
    upload
    delete
    optimise
    exit 0
  fi

  profiles=$(ls /nix/var/nix/profiles/system-profiles/ 2>/dev/null | grep -v '\-link$')

  if [ -z "$profiles" ]; then
    echo "profile: none"
    echo "info: create profiles with 'nixedit --profile/-p <profile-name>'."
  else
    echo "$profiles" | while read -r profile; do
      echo "profile: $profile"
    done
  fi
}

find() {
  if [ -z "$2" ]; then
    echo "Usage: nixedit --find <package-name>"
    exit 1
  fi

  local search_term="$2"
  cd /nix/store && ls | grep "$search_term"
}

add() {
    if [ "$UID" -eq 0 ]; then
  echo "There's no need to use sudo in the command."
  exit 1
  fi
  if ! sudo true; then
    exit 1
  fi
  local CONFIG_FILE="/etc/nixos/configuration.nix"
  
  if [[ "$#" -lt 2 ]]; then
      echo "Usage: --add <package-name> <package-name> ..."
      return 1
  fi
  
  for PACKAGE in "${@:2}"; do

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "error: file not found: $CONFIG_FILE"
        return 1
    fi

    if grep -q "\b$PACKAGE\b" "$CONFIG_FILE"; then
        echo "error: '$PACKAGE' is already present in system package list."
        continue
    fi

    sudo sed -i "/environment\.systemPackages/ s/^  */  /" "$CONFIG_FILE"
    
    sudo sed -i "/environment\.systemPackages/,/\]/ s/\]/  $PACKAGE\n    ]/" "$CONFIG_FILE"

    sudo sed -i "/environment\.systemPackages/,/\]/ s/^\(\s*\]\);$/  ];/" "$CONFIG_FILE"

    echo "edit: '$PACKAGE' added to system package list."

  done
}

remove() {
  if [ "$UID" -eq 0 ]; then
  echo "There's no need to use sudo in the command."
  exit 1
  fi
  if ! sudo true; then
    exit 1
  fi
  local CONFIG_FILE="/etc/nixos/configuration.nix"
  
  if [[ "$#" -lt 2 ]]; then
      echo "Usage: --remove <package-name> <package-name> ..."
      return 1
  fi
  
  for PACKAGE in "${@:2}"; do
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "error: file not found: $CONFIG_FILE"
        return 1
    fi

    if ! grep -q "\b$PACKAGE\b" "$CONFIG_FILE"; then
        echo "error: '$PACKAGE' is not present in system package list."
        continue
    fi

    sudo sed -i "/environment\.systemPackages/,/\]/ s/\b$PACKAGE\b//g" "$CONFIG_FILE"
    
    sudo sed -i "/environment\.systemPackages/,/\]/ s/^ *\([^ ]\)/    \1/" "$CONFIG_FILE"

    sudo sed -i "/environment\.systemPackages/ s/^  */  /" "$CONFIG_FILE"

    sudo sed -i "/environment\.systemPackages/,/\]/ s/^\(\s*\]\);$/  ];/" "$CONFIG_FILE"

    sudo sed -i "/environment\.systemPackages/,/\]/ {/^ *$/d}" "$CONFIG_FILE"

    echo "edit: '$PACKAGE' removed from system package list."

  done
}

install() {
  if [ "$UID" -eq 0 ]; then
  echo "There's no need to use sudo in the command."
  exit 1
  fi
  if ! sudo true; then
    exit 1
  fi
  local CONFIG_FILE="/etc/nixos/configuration.nix"
  local new_packages=()

  PACKAGE="$2"

  if [[ "$#" -eq 2 ]]; then
    if [[ ! -f "$CONFIG_FILE" ]]; then
      echo "error: file not found: $CONFIG_FILE"
      return 1
    fi
    
    if grep -q "\b$PACKAGE\b" "$CONFIG_FILE"; then
      echo "error: '$PACKAGE' is already in system package list."
      return 0  
    fi
    
    new_packages+=("$PACKAGE")
  
    add --add $PACKAGE > /dev/null
    
    if [[ ${#new_packages[@]} -gt 0 ]]; then
      if [[ $profile_name =~ ^[0-9] ]]; then
        echo "error: profile name cannot start with a number."
        exit 1
    fi
      local task_description="installing ${new_packages[*]}"
      local command="sudo nixos-rebuild switch"
      local error_word="error"
      local error_message="installation failed, '$PACKAGE' may not exist"
      local success_message="installed ${new_packages[*]}"
  
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
        remove --remove $PACKAGE > /dev/null
        exit 1
      else
        printf "\redit: [ %s ] $success_message.\033[0K\n" "$(format_time "$final_time")"
      fi
    fi
    return 0
    elif [[ "$#" -eq 3 ]]; then
      if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "error: file not found: $CONFIG_FILE"
        return 1
      fi
    
      if grep -q "\b$PACKAGE\b" "$CONFIG_FILE"; then
        echo "error: '$PACKAGE' is already in system package list."
        return 0  
      fi
    
      new_packages+=("$PACKAGE")
    
      add --add $PACKAGE > /dev/null
    
      if [[ ${#new_packages[@]} -gt 0 ]]; then
          if [[ $profile_name =~ ^[0-9] ]]; then
          echo "error: profile name cannot start with a number."
          exit 1
        fi
        local task_description="installing ${new_packages[*]} to $3 profile."
        local command="sudo nixos-rebuild switch --profile-name $3"
        local error_word="error"
        local error_message="installation failed, '$PACKAGE' may not exist"
        local success_message="installed ${new_packages[*]} to $3 profile."
    
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
          remove --remove $PACKAGE > /dev/null
          exit 1
        else
          printf "\redit: [ %s ] $success_message.\033[0K\n" "$(format_time "$final_time")"
        fi
      fi

    return 0  
  else
    echo "Usage: --install <package-name> <profile-name>"
    return 1
  fi
}

uninstall() {
  local CONFIG_FILE="/etc/nixos/configuration.nix"
  
  local PACKAGE="$2"

  case "$#" in
    2) 
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "error: file not found: $CONFIG_FILE"
        return 1
    fi

    if ! grep -q "\b$PACKAGE\b" "$CONFIG_FILE"; then
        echo "error: '$PACKAGE' is not present in system package list."
        return 0
    fi

    remove --remove $PACKAGE > /dev/null

    task_with_timer "uninstalling $PACKAGE" "sudo nixos-rebuild switch" "error" "uninstall failed" "uninstalled $PACKAGE"
      ;;
    3) 
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "error: file not found: $CONFIG_FILE"
        return 1
    fi

    if ! grep -q "\b$PACKAGE\b" "$CONFIG_FILE"; then
        echo "error: '$PACKAGE' is not present in system package list."
        return 0
    fi

    remove --remove $PACKAGE > /dev/null

    task_with_timer "uninstalling $PACKAGE on $3 profile" "sudo nixos-rebuild switch --profile-name $3" "error" "uninstall failed" "uninstalled $PACKAGE on $3 profiles"
      ;;
    *) 
      echo "Usage: nixedit --uninstall/-u <package-name> <profile-name>"
      ;;
  esac
}

tui() {
  if [ "$UID" -eq 0 ]; then
    echo "There's no need to use sudo in the command."
    exit 1
  fi

  prompt() {
    if [[ -n "$prompt_flag" ]]; then
      echo "Prompt has already been successfully executed. Skipping..."
      return 
    fi
  
    password=$(dialog --insecure --title "Password for Nixedit" --passwordbox "Enter your root password" 8 40 3>&1 1>&2 2>&3)
  
    if [[ -z "$password" ]]; then
      clear; exit 0
    fi
  
    sudo -k
  
    echo -n "$password" | sudo -S true 2>/dev/null
    if [ $? -ne 0 ]; then
      dialog --title "Password Error" --infobox " Incorrect password." 4 26; sleep 2
      clear; exit 0
    fi
  
    prompt_flag="success"
  }

  prompt

  VAR=$(dialog --title "Nixedit" \
    --menu "Select system operation:" 0 0 0 \
      1 "Search packages" \
      2 "Help" \
      3 "Connect Github" \
      4 "Configuration" \
      5 "Backup computer" \
      6 "Install software" \
      7 "Uninstall software" \
      8 "List restore points" \
      9 "Delete restore points" \
      10 "Optimise storage" \
      11 "Rebuild & Reboot" \
      3>&1 1>&2 2>&3)

  case $VAR in
    1)
      # Search packages
      USER_INPUT=$(dialog --title "NixPKG Search" --inputbox "Name the package you're looking for" 8 40 3>&1 1>&2 2>&3 3>&-)
      
      if [[ -z "$USER_INPUT" ]]; then
          tui; exit 0
      fi
      
      tui_search=$(
        {
          nix search nixpkgs 2>/dev/null | 
          grep "$USER_INPUT" | 
          awk -F "legacyPackages.x86_64-linux." '{print $2}' | 
          awk '{print $1}' | 
          sed 's/\..*//' | 
          sort -u | 
          grep -v '^$' | 
          grep "^$USER_INPUT" | 
          sed 's/\x1B\[[0-9;]*[a-zA-Z]//g'
        } 
      )
      
      package_array=()
      menu_items=""
      i=1
      
      if [ -z "$tui_search" ]; then
        dialog --title "NixPKG Install" --msgbox "No results found for '$USER_INPUT'" 6 40
        tui; exit 0
      fi
      
      for item in $tui_search; do
        menu_items+="$i $item "
        package_array+=("$item")
        i=$((i+1))
      done
      
      selected=$(dialog --title "NixPKG Search" --menu "Showing results for: $USER_INPUT" 0 0 0 $menu_items 3>&1 1>&2 2>&3)
      
      if [ $? -eq 1 ]; then
        tui; exit 0
      fi
      
      selected_package="${package_array[$((selected-1))]}"
      
      dialog --title "NixPKG Search" --yes-label "Install" --no-label "Cancel" --extra-button --extra-label "Add Package" --yesno "\nWhat would you like to do with this package?\n\nSelected: $selected_package" 9 54
      
      case $? in
          0)
            dialog --title "NixPKG Install" --infobox "Your system is currently building.\n\nInstalling: $selected_package" 6 40
            output=$(install --install "$selected_package")
            if echo "$output" | grep -q "installed"; then
              dialog --title "NixPKG Install" --msgbox "Your system successfully built.\nInstalled: $selected_package" 7 40
            elif echo "$output" | grep -q "usage"; then
              true
            elif echo "$output" | grep -q "exist"; then
              dialog --title "NixPKG Install" --msgbox "Your system failed to build.\nUnable to install: '$selected_package'\n\n            Package may not exist." 8 50
            elif echo "$output" | grep -q "already"; then
              dialog --title "NixPKG Install" --msgbox "Your system failed to build.\nUnable to install: $selected_package\n\n        Already present package list." 8 50
            fi
            tui
            exit 0
            ;;
          1)  
            tui
            exit 0
            ;;
          3)  
            output=$(add --add "$selected_package")
            if echo "$output" | grep -q "added"; then
              dialog --title "NixPKG Search" --msgbox "         Added package to Configuration.\n\n              pending next build." 7 55
            elif echo "$output" | grep -q "usage"; then
              true
            elif echo "$output" | grep -q "error"; then
              dialog --title "NixPKG Search" --msgbox "       Added package to Configuration.\n\n              pending next build." 7 50
            elif echo "$output" | grep -q "present"; then
              dialog --title "NixPKG Search" --msgbox "             Unable to add package.\n\n       Name already found in package list." 7 53
            fi
            tui
            exit 0
            ;;
      esac
      ;;
    2)
      # Help
      dialog --title "Nixedit Help." --msgbox "
        \nSee 'nixedit --usage'.
        \n
        \nNixOS Multipurpose CLI/TUI Utility.
        \n
        \nSettings:
        \n  --github        Connect your dedicated GitHub repository to store backups
        \n
        \nInfo commands:
        \n  --help          Show this help message and exit
        \n  --version       Display current nixedit version
        \n
        \nTerminal user interface:
        \n  --tui           Open dialog  
        \n
        \nSingular options: (some have short options '"'-i'"') 
        \n  --search        Search packages
        \n  --configure     Open configuration
        \n  --add           Add package to configuration
        \n  --remove        Remove package from configuration
        \n  --install       Install package to systems
        \n  --uninstall     Uninstall package from system
        \n  --upload        Upload configuration
        \n  --update        Update nixpkgs & search, databases
        \n  --rebuild       Rebuild system
        \n  --profile       List existing profiles
        \n  --generation    List existing generations
        \n  --delete        Delete packages & profiles
        \n  --optimise      Optimize Nix storage
        \n  --graph         Browse dependency graph
        \n  --find          Find local packages
        \n        
        \nIf no option is provided, the default operation will:
        \n  - Perform a search
        \n  - Open the configuration file for editing
        \n  - Update channel
        \n  - Rebuild the system
        \n  - Upload configuration
        \n  - Delete old packages
        \n  - Optimise package storage" 0 0
      tui; exit 0
      ;;
    3)
      # Connect Github
      repo=$(dialog --title "Connect GitHub" --inputbox "Link repository for configuration storage.\n\nVisit this link and create a dedicated repository.\nhttps://github.com/new\n\nEvery upload will push here" 14 60 3>&1 1>&2 2>&3)

      if [ -z "$repo" ]; then
        tui; exit 0
      fi
      
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
      
      git remote add origin "$repo" > /dev/null 2>&1
      git checkout -b main > /dev/null 2>&1
      git checkout main origin/main > /dev/null 2>&1
      
      output=$(git push -u origin main --force 2>&1)
      if echo "$output" | grep -q "branch 'main' set up to track 'origin/main'"; then
        dialog --title "Connect GitHub" --msgbox "\n   Configuration Synced with repository.\n\n   $repo" 9 47
        tui; exit 0
      else
        dialog --title "Connect GitHub" --msgbox "\n  Sync failed, Check URL or token settings.\n\n   $repo" 9 49
        tui; exit 0
        fi
      ;;
    4)
      # Configuration
      if 
      echo $password | sudo -S dialog --title "Configuration" --editbox /etc/nixos/configuration.nix 0 0
      then
        dialog --title "Configuration" --infobox "Saved changes, pending next build." 4 40
      sleep 3
      else
        dialog --title "Configuration" --infobox "Changes canceled, nothing new to build." 4 43
      sleep 3
      fi
      tui; exit 0
      ;;
    5)
      # Backup computer
      dialog --title "Backup computer" --infobox "\n Uploading configuration to GitHub..." 6 42
      output=$(upload)
      if echo "$output" | grep -q "complete"; then
        dialog --title "Backup computer" --msgbox "\n Configurations have been uploaded to GitHub." 7 50
      elif echo "$output" | grep -q "failed"; then
        dialog --title "Backup computer" --msgbox "\n        Failed to upload configuration.\n\n  Check network or connect GitHub repository" 10 50
      else
        dialog --title "Backup computer" --msgbox "\n                Upload status unknown.\n\n      No clear indication of success or failure." 9 60
      fi
      tui; exit 0
      ;;
    6)
      # Install software
      USER_INPUT=$(dialog --title "NixPKG Install" --inputbox "Name the package you're trying to install" 8 45 3>&1 1>&2 2>&3 3>&-)
      
      dialog --title "NixPKG Install" --infobox "Your system is currently building.\nInstalling: $USER_INPUT" 4 40

      output=$(install --install $USER_INPUT)
      if echo "$output" | grep -q "complete"; then
          dialog --title "NixPKG Install" --msgbox "Your system successfully built.\nInstalled: $USER_INPUT" 7 40
          tui; exit 0
      elif echo "$output" | grep -q "usage"; then
          tui; exit 0
      elif echo "$output" | grep -q "exist"; then
          dialog --title "NixPKG Install" --msgbox "Your system failed to build.\nUnable to install: '$USER_INPUT'\n\n            Package may not exist." 8 50
          tui; exit 0
      elif echo "$output" | grep -q "already"; then
          dialog --title "NixPKG Install" --msgbox "Your system failed to build.\nUnable to install: $USER_INPUT\n\n        Already present package list." 8 50
          tui ; exit 0
       else
          tui; exit 0
      fi
      ;;
    7)
      # Uninstall software
      USER_INPUT=$(dialog --title "NixPKG Uninstall" --inputbox "Name the package you're trying to uninstall" 8 47 3>&1 1>&2 2>&3 3>&-)
      dialog --title "NixPKG Uninstall" --infobox "Uninstalling package '$USER_INPUT'. Your system is currently building..." 4 74

      output=$(uninstall --uninstall $USER_INPUT)
      if echo "$output" | grep -q "uninstalled"; then
          dialog --title "NixPKG Uninstall" --msgbox "Successfully uninstalled '$USER_INPUT'." 5 40
          tui; exit 0
      elif echo "$output" | grep -q "usage"; then
          tui; exit 0
      elif echo "$output" | grep -q "list"; then
          dialog --title "NixPKG Uninstall" --msgbox "Failed to uninstall '$USER_INPUT'. Not found in package list." 5 65
          tui; exit 0
       else
          tui; exit 0
      fi
      ;;
    8)
      # List restore points
      output=""
      while IFS= read -r line; do
          output+="$line\n\n"  
      done < <(generation --generation)
      
      dialog --title "List restore points" --msgbox "    Configurations can be found in\n        .nixedit/Configuration \n\n$output" 0 0
      tui; exit 0
      ;;
    9)
      # Delete restore points
      USER_INPUT=$(dialog --title "Delete restore points" --rangebox "Select the maximum age for restore points (1-30 days)" 9 57 1 30 7 3>&1 1>&2 2>&3 3>&-)
      
      if [[ -z "$USER_INPUT" ]]; then
          tui; exit 0
      fi
      
      if [[ "$USER_INPUT" -eq 1 ]]; then
          message="Are you sure you want to delete all restore points older than $USER_INPUT day?"
      else
          message="Are you sure you want to delete all restore points older than $USER_INPUT days?"
      fi
      
      dialog --title "Delete restore points" --yesno "$message" 7 40
      
      if [[ $? -ne 0 ]]; then
          tui; exit 0
      fi

      echo "$USER_INPUT" > ~/.cache/nixedit/package-age.txt

      dialog --title "Delete restore points" --infobox "Deleting outdated restore points..." 4 39
      output=$(delete --delete)
      
      if echo "$output" | grep -q "complete"; then
          dialog --title "Delete restore points" --msgbox "Successfully deleted restore points" 6 40
          tui; exit 0
      elif echo "$output" | grep -q "usage"; then
          tui; exit 0
      elif echo "$output" | grep -q "failed"; then
          dialog --title "Delete restore points" --msgbox "Failed to delete outdated restore points" 6 45
          tui; exit 0
      else
          tui; exit 0
      fi
      ;;
    10)
      # Optimise storage 
      dialog --title "Optimise storage" --infobox "\n  Currently working on system symlinks.\n\n  This may take 5-10 minutes." 8 50
      output=$(optimise --optimise)

      "error" "optimising has failed" "optimisation complete"

      if echo "$output" | grep -q "complete"; then
        dialog --title "Optimise storage" --msgbox "\n  System symlinks have been optimised.\n\n  Operation complete." 8 50
        tui; exit 0
      elif echo "$output" | grep -q "usage"; then
        tui; exit 0
      elif echo "$output" | grep -q "failed"; then
        dialog --title "Optimise storage" --msgbox "\n  Failed to optimise system symlinks.\n\n  Unable to complete operation. Unknown error." 8 50
      tui; exit 0
      else
          tui; exit 0
      fi
      ;;
    11)
      # Rebuild & Reboot
      dialog --title "Rebuild & Reboot" --infobox "\n  Rebuilding system, computer will automatically reboot when done. \n\n  This may take 1-3 minutes. depending if the kernel is compiling." 8 72
      output=$(optimise --optimise)

      if echo "$output" | grep -q "complete"; then
        dialog --title "Rebuild & Reboot" --infobox "\n  Rebuild complete, computer will automatically reboot when done. \n\n  Last phases: Update Upload Delete Optimise | ~1 minute left." 8 72

        update_system > /dev/null
        upload > /dev/null
        delete > /dev/null
        optimise > /dev/null

        reboot
        
        tui; exit 0
      elif echo "$output" | grep -q "error"; then
        tui; exit 0
      elif echo "$output" | grep -q "failed"; then
        dialog --title "Rebuild & Reboot" --msgbox "\n  Rebuild failed, computer unable to proceed with reboot safely. \n\n  Check Network & Configuration." 8 72
      tui; exit 0
      else
          tui; exit 0
      fi
      ;;
esac
clear
}

version() {
  echo "version 1.0.2."
}

usage() {
  echo "Nixedit command usage
  --search/-s: open search.
  --configure/-c: open configuration.
  --add <package-name> <package-name> ...
  --remove <package-name> <package-name> ...
  --install/-i <package-name> <profile-name>.
  --uninstall/-u <package-name> <profile-name>.
  --upload: upload configuration.
  --update: update system.
  --rebuild/-r <profile-name>.
  --profile/-p <profile-name>/no option: list profiles.
  --generation/-g: lists generations.
  --delete/-d <profile-name>/<number> days old packages.
  --optimise: optimise storage.
  --graph: open store graph.
  --find <package-name>."
}

help() { echo "See 'nixedit --usage'.

NixOS Multipurpose CLI/TUI Utility.

Settings:
  --github        Connect your dedicated GitHub repository to store backups

Info commands:
  --help          Show this help message and exit
  --version       Display current nixedit version

Terminal user interface:
  --tui           Open dialog  

Singular options: (some have short options '"'-i'"') 
  --search        Search packages
  --configure     Open configuration
  --add           Add package to configuration
  --remove        Remove package from configuration
  --install       Install package to systems
  --uninstall     Uninstall package from system
  --upload        Upload configuration
  --update        Update nixpkgs & search, databases
  --rebuild       Rebuild system
  --profile       List existing profiles
  --generation    List existing generations
  --delete        Delete packages & profiles
  --optimise      Optimize Nix storage
  --graph         Browse dependency graph
  --find          Find local packages
        
If no option is provided, the default operation will:
  - Perform a search
  - Open the configuration file for editing
  - Update channel
  - Rebuild the system
  - Upload configuration
  - Delete old packages
  - Optimise package storage"
  
#  Development options:
#  --debug         Reset nixedit cache
#  --check         Check search functionality
}

if [ $# -eq 0 ]; then
  default_operation
  exit 0
fi

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
    update_system
    ;;
  --help)
    help
    ;;
  -h)
    help
    ;;
  --usage)
    usage
    ;;
  --version)
    version
    ;;
  -v)
    version
    ;;
  --graph)
    graph
    ;;
  --search)
    search 
    ;;
  -s)
    search
    ;;
  --configure)
    configure "$@"
    ;;
  -c)
    configure "$@"
    ;;
  --rebuild)
    rebuild "$@"
    ;;
  -r)
    rebuild "$@"
    ;;
  --generation)
    generation
    ;;
  -g)
    generation
    ;;
  --profile)
    profile "$@"
    ;;
  -p)
    profile "$@"
    ;;
  --delete)
    delete "$@"
    ;;
  -d)
    delete "$@"
    ;;
  --find)
    find "$@"
    ;;
  --add)
    add "$@"
    ;;
  --remove)
    remove "$@"
    ;;
  --install)
    install "$@"
    ;;
  -i)
    install "$@"
    ;;
  --uninstall)
    uninstall "$@"
    ;;
  -u)
    uninstall "$@"
    ;;
  --tui)
    tui
    ;;
  -t)
    tui
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

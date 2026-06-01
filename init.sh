#!/bin/bash
# Final Szmelc Commander - init.sh
# Bootstrap / installer / updater / portable launcher
# TUI baseline borrowed from Interface/ExileConstruct/direct.sh

tput civis
trap "tput cnorm; clear; exit" EXIT

SZMELC_REPO="https://github.com/Szmelc-INC/Final-Szmelc-Commander"
SZMELC_HOME_DIR="$HOME/.szmelc"
SZMELC_TMP_DIR="/tmp/.szmelc"
SZMELC_SUBDIR="Final-Szmelc-Commander"

# ANSI color escapes
cyan=$'\e[36m'
green=$'\e[32m'
red=$'\e[31m'
yellow=$'\e[33m'
reset=$'\e[0m'

# ---- Detection ---------------------------------------------------------------
detect_szmelc() {
    SZMELC_FOUND=0
    SZMELC_VERSION=""

    [ -d "$SZMELC_HOME_DIR" ] && SZMELC_FOUND=1

    if alias szmelc >/dev/null 2>&1; then
        SZMELC_FOUND=1
    fi

    if [ -n "${SZMELC:-}" ]; then
        SZMELC_FOUND=1
        SZMELC_VERSION="$SZMELC"
    fi

    if [ -z "$SZMELC_VERSION" ] && [ -f "$SZMELC_HOME_DIR/$SZMELC_SUBDIR/VERSION" ]; then
        SZMELC_VERSION="$(cat "$SZMELC_HOME_DIR/$SZMELC_SUBDIR/VERSION" 2>/dev/null)"
    fi

    [ -z "$SZMELC_VERSION" ] && SZMELC_VERSION="unknown"
}

# ---- TUI ---------------------------------------------------------------------
draw_menu() {
    local title="$1"
    shift
    local -a labels=("$@")
    local count=${#labels[@]}
    local cursor_local=$cursor

    clear
    term_width=$(tput cols)

    max_len=${#title}
    for ((i=0; i<count; i++)); do
        len=${#labels[i]}
        (( len > max_len )) && max_len=$len
    done

    line_len=$((4 + max_len))
    box_width=$((line_len + 4))
    padding=$(( (term_width - box_width) / 2 ))
    (( padding < 0 )) && padding=0

    echo -e "\n\n"

    title_len=${#title}
    title_pad=$(( (line_len - title_len) / 2 ))

    printf "%*s┌" "$padding" ""
    printf '─%.0s' $(seq 1 $line_len)
    printf '┐\n'

    printf "%*s│" "$padding" ""
    printf "%*s%s%*s" "$title_pad" "" "$title" "$((line_len - title_pad - title_len))" ""
    printf "│\n"

    printf "%*s└" "$padding" ""
    printf '─%.0s' $(seq 1 $line_len)
    printf '┘\n'

    printf "%*s┌" "$padding" ""
    printf '─%.0s' $(seq 1 $line_len)
    printf '┐\n'

    for ((i=0; i<count; i++)); do
        label="${labels[i]}"
        padded_label=$(printf "%-${max_len}s" "$label")
        prefix="  "
        [[ $i -eq $cursor_local ]] && prefix="${cyan}> ${reset}"
        printf "%*s│ %s%s │\n" "$padding" "" "$prefix" "$padded_label"
    done

    printf "%*s└" "$padding" ""
    printf '─%.0s' $(seq 1 $line_len)
    printf '┘\n'

    echo -e "\n\n\n"
}

# Returns chosen index via global $CHOICE; -1 if user escapes.
run_menu() {
    local title="$1"
    shift
    local -a labels=("$@")
    local count=${#labels[@]}
    cursor=0
    CHOICE=-1

    while true; do
        draw_menu "$title" "${labels[@]}"
        IFS= read -rsn1 key

        if [[ $key == $'\x1b' ]]; then
            read -rsn2 -t 0.01 rest
            case "$rest" in
                "[A") ((cursor > 0)) && ((cursor--)) ;;
                "[B") ((cursor < count - 1)) && ((cursor++)) ;;
                *) CHOICE=-1; return ;;
            esac
        elif [[ $key == $'\n' || $key == "" ]]; then
            CHOICE=$cursor
            return
        fi
    done
}

# ---- Helpers -----------------------------------------------------------------
require_git_or_prompt() {
    if command -v git >/dev/null 2>&1; then
        return 0
    fi

    tput cnorm
    clear
    echo
    echo "  ${red}[!]${reset} ${yellow}git${reset} is not installed."
    echo "      Szmelc needs git to fetch the commander."
    echo
    echo "      Install git first, for example:"
    echo "        Debian/Ubuntu : sudo apt install git"
    echo "        Arch          : sudo pacman -S git"
    echo "        Fedora        : sudo dnf install git"
    echo "        macOS         : brew install git"
    echo
    printf "      Press Enter to exit..."
    read -r _
    exit 1
}

clone_into() {
    local target_root="$1"
    local target_dir="$target_root/$SZMELC_SUBDIR"

    mkdir -p "$target_root" || {
        echo "${red}[!]${reset} Could not create $target_root"
        return 1
    }

    if [ -d "$target_dir/.git" ]; then
        echo "${yellow}[•]${reset} Existing checkout found at $target_dir — pulling latest..."
        ( cd "$target_dir" && git pull --ff-only ) || return 1
    else
        rm -rf "$target_dir"
        ( cd "$target_root" && git clone "$SZMELC_REPO" ) || return 1
    fi

    INSTALLED_PATH="$target_dir"
    return 0
}

# Move contents of <clone>/szmelc/ into $HOME/.szmelc/ (including dotfiles).
# Used during install and update so runtime files (e.g. .szmelcrc) live at
# the root of ~/.szmelc/ while the cloned repo stays under
# ~/.szmelc/Final-Szmelc-Commander/.
sync_szmelc_payload() {
    local src="$INSTALLED_PATH/szmelc"
    if [ ! -d "$src" ]; then
        echo "${yellow}[•]${reset} No 'szmelc/' payload directory in clone — skipping sync."
        return 0
    fi

    mkdir -p "$SZMELC_HOME_DIR" || return 1
    # 'src/.' copies contents including hidden files without needing dotglob.
    cp -af "$src/." "$SZMELC_HOME_DIR/" || {
        echo "${red}[!]${reset} Failed to sync szmelc/ payload into $SZMELC_HOME_DIR"
        return 1
    }
    echo "${green}[✓]${reset} Synced szmelc/ payload into $SZMELC_HOME_DIR"
    return 0
}

# Append `source $HOME/.szmelc/.szmelcrc` to the user's shell rc file if it
# isn't already sourced there. Uses the exact pattern the user specified:
#   >> $HOME/.${SHELL##*/}rc
ensure_rc_sourced() {
    local rc_file="$HOME/.${SHELL##*/}rc"
    local src_line='source $HOME/.szmelc/.szmelcrc'

    # Only touch the rc if the payload actually delivered a .szmelcrc.
    if [ ! -f "$SZMELC_HOME_DIR/.szmelcrc" ]; then
        return 0
    fi

    if [ ! -e "$rc_file" ]; then
        : > "$rc_file" || {
            echo "${red}[!]${reset} Could not create $rc_file"
            return 1
        }
    fi

    if grep -Fq '.szmelc/.szmelcrc' "$rc_file" 2>/dev/null; then
        echo "${yellow}[•]${reset} $rc_file already sources .szmelcrc — leaving it alone."
        return 0
    fi

    printf '%s\n' "$src_line" >> "$rc_file" || {
        echo "${red}[!]${reset} Could not append to $rc_file"
        return 1
    }
    echo "${green}[✓]${reset} Appended source line to $rc_file"
    echo "      Restart your shell or run: source \"$rc_file\""
    return 0
}

prompt_launch_and_run() {
    local main_script="$INSTALLED_PATH/main.sh"

    tput cnorm
    echo
    printf "  Start szmelc now? [Y/n] "
    read -r answer
    case "$answer" in
        ""|y|Y|yes|YES)
            if [ -x "$main_script" ] || [ -f "$main_script" ]; then
                clear
                bash "$main_script"
            else
                echo "${red}[!]${reset} main.sh not found at $main_script"
                exit 1
            fi
            ;;
        *)
            echo "${yellow}[•]${reset} Skipping launch. You can run it later:"
            echo "      bash \"$main_script\""
            ;;
    esac
}

# ---- Actions -----------------------------------------------------------------
action_install() {
    require_git_or_prompt
    tput cnorm
    clear
    echo "${cyan}>>> Installing Szmelc to $SZMELC_HOME_DIR${reset}"
    clone_into "$SZMELC_HOME_DIR" || { echo "${red}Install failed.${reset}"; exit 1; }
    sync_szmelc_payload || { echo "${red}Install failed during payload sync.${reset}"; exit 1; }
    ensure_rc_sourced
    echo "${green}[✓]${reset} Szmelc installed at $INSTALLED_PATH"
    prompt_launch_and_run
}

action_portable() {
    require_git_or_prompt
    tput cnorm
    clear
    echo "${cyan}>>> Running portable Szmelc from $SZMELC_TMP_DIR${reset}"
    clone_into "$SZMELC_TMP_DIR" || { echo "${red}Portable run failed.${reset}"; exit 1; }
    echo "${green}[✓]${reset} Szmelc ready at $INSTALLED_PATH"
    prompt_launch_and_run
}

action_update() {
    require_git_or_prompt
    tput cnorm
    clear
    echo "${cyan}>>> Updating Szmelc in $SZMELC_HOME_DIR${reset}"
    clone_into "$SZMELC_HOME_DIR" || { echo "${red}Update failed.${reset}"; exit 1; }
    sync_szmelc_payload || { echo "${red}Update failed during payload sync.${reset}"; exit 1; }
    ensure_rc_sourced
    echo "${green}[✓]${reset} Szmelc updated at $INSTALLED_PATH"
    prompt_launch_and_run
}

action_start() {
    local main_script="$SZMELC_HOME_DIR/$SZMELC_SUBDIR/main.sh"
    tput cnorm
    clear
    if [ -f "$main_script" ]; then
        bash "$main_script"
    else
        echo "${red}[!]${reset} main.sh not found at $main_script"
        echo "      Try Update Szmelc to restore it."
        exit 1
    fi
}

action_remove() {
    tput cnorm
    clear
    echo "${red}>>> Removing $SZMELC_HOME_DIR${reset}"
    rm -fr "$SZMELC_HOME_DIR"
    echo "${green}[✓]${reset} Removed."
    echo
    echo "  Note: shell alias 'szmelc', \$SZMELC env var, and the"
    echo "        'source \$HOME/.szmelc/.szmelcrc' line in your shell rc"
    echo "        were NOT touched — remove them manually if desired."
    exit 0
}

# ---- Main --------------------------------------------------------------------
main() {
    detect_szmelc

    if [ "$SZMELC_FOUND" -eq 1 ]; then
        local title=" Szmelc $SZMELC_VERSION "
        local -a labels=("Start szmelc commander" "Update Szmelc" "Remove Szmelc")
        run_menu "$title" "${labels[@]}"
        case "$CHOICE" in
            0) action_start ;;
            1) action_update ;;
            2) action_remove ;;
            *) exit 0 ;;
        esac
    else
        local title=" Szmelc Not Found. "
        local -a labels=("Install Szmelc" "Run Portable")
        run_menu "$title" "${labels[@]}"
        case "$CHOICE" in
            0) action_install ;;
            1) action_portable ;;
            *) exit 0 ;;
        esac
    fi
}

main

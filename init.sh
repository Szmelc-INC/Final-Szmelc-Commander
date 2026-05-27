#!/bin/sh
# =============================================================================
# Final Szmelc Commander - init.sh (Loader & Environment Bootstrap)
# "ostateczny szmelc commander szmelc commanderów!!!"
#
# Purpose:
#   - Universal POSIX-compatible bootstrap for any Unix-like system
#     (Linux, macOS/Darwin, BSD, containers, WSL, Termux, sandboxes, emulators)
#   - Rapid host fingerprinting: OS, distro, user, shell, architecture, containerization
#   - Detection of package managers + essential networking/build tools + versions
#   - Generates /tmp/.host-info (sourceable shell vars + human-readable comments)
#   - Prepares environment for modular "loaders" and upcoming TUI/commander components
#   - Safe, non-destructive, internet-aware but gracefully degrades
#
# Usage (as designed for GitHub raw):
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/Szmelc-INC/Final-Szmelc-Commander/refs/heads/main/init.sh)"
#
# After sourcing in other scripts:
#   . /tmp/.host-info
#   echo "$DETECTED_PACKAGE_MANAGERS"
#
# Style: Move fast, break nothing critical. Brutal pragmatism. Szmelc way.
# =============================================================================

set -euf
# Note: -euf for safety; some ancient sh may complain about -u on unset, but modern POSIX ok.
# If issues on very old systems, comment out.

# --- Globals & Constants ------------------------------------------------------
INFO_FILE="/tmp/.host-info"
SCRIPT_VERSION="0.9.0-snapshot"
START_TIME=$(date '+%s' 2>/dev/null || echo 0)

# Colors if terminal supports (graceful fallback)
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    BOLD=$(tput bold 2>/dev/null || echo "")
    RESET=$(tput sgr0 2>/dev/null || echo "")
    GREEN=$(tput setaf 2 2>/dev/null || echo "")
    YELLOW=$(tput setaf 3 2>/dev/null || echo "")
    RED=$(tput setaf 1 2>/dev/null || echo "")
    CYAN=$(tput setaf 6 2>/dev/null || echo "")
else
    BOLD=""
    RESET=""
    GREEN=""
    YELLOW=""
    RED=""
    CYAN=""
fi

# --- Helper Functions ---------------------------------------------------------
print_header() {
    printf "\n%s%s=== %s ===%s\n" "$BOLD" "$CYAN" "$1" "$RESET"
}

print_success() {
    printf "%s[✓]%s %s\n" "$GREEN" "$RESET" "$1"
}

print_info() {
    printf "%s[•]%s %s\n" "$YELLOW" "$RESET" "$1"
}

print_status() {
    # Usage: print_status "Label" "Value" "ok|warn|error|info"
    label="$1"
    value="$2"
    status="${3:-info}"
    case "$status" in
        ok|found|yes|true)   color="$GREEN" ;;
        error|notfound|no|false) color="$RED" ;;
        warn)                color="$YELLOW" ;;
        *)                   color="$CYAN" ;;
    esac
    printf "  %s%s:%s %s%s%s\n" "$BOLD" "$label" "$RESET" "$color" "$value" "$RESET"
}

# Safe command existence check (pure POSIX)
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Safe version grabber (first line, cleaned)
get_version() {
    cmd="$1"
    shift
    # Try common flags, fallback to first line of output or "present"
    if command_exists "$cmd"; then
        ver="$($cmd "$@" 2>/dev/null | head -n 1 | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)"
        if [ -z "$ver" ]; then
            ver="$($cmd -v 2>/dev/null | head -n 1 | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)"
        fi
        if [ -z "$ver" ]; then
            ver="$($cmd --version 2>/dev/null | head -n 1 | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)"
        fi
        printf "%s" "${ver:-present}"
    else
        printf "not-found"
    fi
}

# --- Main Detection Logic -----------------------------------------------------
clear 2>/dev/null || printf "\033c" 2>/dev/null || true

printf "%s%s" "$BOLD" "$GREEN"
cat << 'ASCII_ART'
 _______                        __
|     __|.-----.--------.-----.|  |.----.
|__     ||-- __|        |  -__||  ||  __|
|_______||_____|__|__|__|_____||__||____|
 ______                                         __
|      |.-----.--------.--------.---.-.-----.--|  |.-----.----.
|   ---||  _  |        |        |  _  |     |  _  ||  -__|   _|
|______||_____|__|__|__|__|__|__|___._|__|__|_____||_____|__|      [v1]
ASCII_ART
printf "%s\n" "$RESET"

printf "%sFinal Szmelc Commander%s %s(v%s)%s — ultimate loader initializing...\n\n" \
    "$BOLD" "$RESET" "$CYAN" "$SCRIPT_VERSION" "$RESET"

print_header "HOST FINGERPRINTING"

# 1. Core System (uname is universally available)
KERNEL=$(uname -s 2>/dev/null || echo "unknown")
KERNEL_RELEASE=$(uname -r 2>/dev/null || echo "unknown")
ARCH=$(uname -m 2>/dev/null || echo "unknown")
HOSTNAME=$(uname -n 2>/dev/null || hostname 2>/dev/null || echo "unknown")

print_info "Kernel: $KERNEL $KERNEL_RELEASE ($ARCH)"
print_info "Hostname: $HOSTNAME"

# 2. Distribution / OS identification (Linux focus, graceful on others)
DISTRO_ID="unknown"
DISTRO_NAME="unknown"
DISTRO_VERSION="unknown"
DISTRO_LIKE=""

if [ -r /etc/os-release ]; then
    # Source safely (only extract what we need; trusted file)
    . /etc/os-release 2>/dev/null || true
    DISTRO_ID="${ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-${NAME:-unknown}}"
    DISTRO_VERSION="${VERSION:-${VERSION_ID:-unknown}}"
    DISTRO_LIKE="${ID_LIKE:-}"
    print_success "Distro: $DISTRO_NAME ($DISTRO_ID $DISTRO_VERSION)"
elif [ -r /etc/lsb-release ]; then
    . /etc/lsb-release 2>/dev/null || true
    DISTRO_NAME="${DISTRIB_DESCRIPTION:-unknown}"
    DISTRO_ID="${DISTRIB_ID:-unknown}"
    print_info "Distro (lsb): $DISTRO_NAME"
else
    # Fallbacks for BSD/macOS etc.
    case "$KERNEL" in
        Darwin) DISTRO_NAME="macOS $(sw_vers -productVersion 2>/dev/null || echo)" ;;
        FreeBSD|OpenBSD|NetBSD) DISTRO_NAME="$KERNEL $(uname -r)" ;;
        *) DISTRO_NAME="$KERNEL (generic Unix-like)" ;;
    esac
    print_info "OS: $DISTRO_NAME (no /etc/os-release)"
fi

# 3. User & Shell context
USER_NAME=$(id -un 2>/dev/null || whoami 2>/dev/null || echo "${USER:-unknown}")
USER_UID=$(id -u 2>/dev/null || echo "0")
USER_HOME="${HOME:-/tmp}"
CURRENT_SHELL="${SHELL:-/bin/sh}"
SHELL_NAME=$(basename "$CURRENT_SHELL" 2>/dev/null || echo "sh")

print_info "User: $USER_NAME (uid:$USER_UID)  Home: $USER_HOME"
print_info "Shell: $SHELL_NAME ($CURRENT_SHELL)"

# Superuser check
if [ "$USER_UID" -eq 0 ] 2>/dev/null; then
    IS_SUPERUSER="Yes (root)"
    print_status "Superuser" "$IS_SUPERUSER" "ok"
else
    IS_SUPERUSER="No"
    print_status "Superuser" "$IS_SUPERUSER" "info"
fi

# 4. Container / Virtualization / Special env detection
CONTAINER_ENV="bare-metal"
if [ -f /.dockerenv ] 2>/dev/null || [ -f /.containerenv ] 2>/dev/null; then
    CONTAINER_ENV="docker-or-podman"
elif [ -n "${container:-}" ] 2>/dev/null; then
    CONTAINER_ENV="${container}"
elif grep -qE '(docker|lxc|kubepods|libpod)' /proc/1/cgroup 2>/dev/null; then
    CONTAINER_ENV="container-runtime"
fi

# WSL detection
if [ -r /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
    CONTAINER_ENV="wsl"
fi

# Termux (Android)
if [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux ]; then
    CONTAINER_ENV="termux"
fi

print_info "Environment: $CONTAINER_ENV"

# --- System Resources: Uptime + Hardware + Disk (short, no fastfetch) ---
print_header "SYSTEM RESOURCES"

# Uptime
if command_exists uptime; then
    UPTIME=$(uptime | sed 's/.*up //;s/,.*user.*//' | tr -d '\n' 2>/dev/null || echo "unknown")
    print_status "Uptime" "$UPTIME" "info"
else
    UPTIME="unavailable"
fi

# CPU (short)
CPU_MODEL="unknown"
CPU_CORES="?"
if [ -r /proc/cpuinfo ]; then
    CPU_MODEL=$(grep -m1 "^model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^[ \t]*//' | head -c 60)
    CPU_CORES=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || nproc 2>/dev/null || echo "?")
elif command_exists sysctl; then
    CPU_MODEL=$(sysctl -n hw.model 2>/dev/null | head -c 50 || echo "unknown")
    CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo "?")
fi
print_status "CPU" "${CPU_MODEL:-unknown} (${CPU_CORES:-?} cores)" "info"

# Memory (short human readable)
if [ -r /proc/meminfo ]; then
    MEM_TOTAL_KB=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
    if [ -n "$MEM_TOTAL_KB" ]; then
        MEM_TOTAL_MB=$((MEM_TOTAL_KB / 1024))
        MEM_TOTAL_GB=$((MEM_TOTAL_MB / 1024))
        if [ "$MEM_TOTAL_GB" -gt 0 ]; then
            TOTAL_RAM="${MEM_TOTAL_GB} GB"
        else
            TOTAL_RAM="${MEM_TOTAL_MB} MB"
        fi
    else
        TOTAL_RAM="unknown"
    fi
elif command_exists free; then
    TOTAL_RAM=$(free -h 2>/dev/null | awk '/Mem:/ {print $2}' | head -1 || echo "unknown")
else
    TOTAL_RAM="unavailable"
fi
print_status "Memory (total)" "$TOTAL_RAM" "info"

# Disk usage summary (focused, fast)
if command_exists df; then
    DISK_ROOT=$(df -h / 2>/dev/null | awk 'NR==2 {print $3"/"$2" ("$5" used)"}' || echo "n/a")
    DISK_SUMMARY="$DISK_ROOT"
    print_status "Disk (root /)" "$DISK_SUMMARY" "info"
else
    DISK_SUMMARY="unavailable"
fi

# 5. Package Managers Detection (as per spec + comprehensive list)
print_header "PACKAGE MANAGERS & TOOLCHAIN"

PM_LIST=""
PM_COUNT=0

# Extended practical list for real-world coverage
for pm in apt apt-get dnf yum pacman yay paru pikaur apk snap flatpak \
          brew portage zypper emerge nix guix xbps-install opkg; do
    if command_exists "$pm"; then
        PM_COUNT=$((PM_COUNT + 1))
        PM_LIST="$PM_LIST $pm"

        # Version extraction tailored per tool (non-interactive, safe)
        case "$pm" in
            apt|apt-get)
                ver=$(get_version "$pm" --version | awk '{print $2}' | head -1)
                ;;
            pacman|paru|yay|pikaur)
                ver=$(get_version "$pm" --version | awk '{print $NF}' | head -1)
                ;;
            apk)
                ver=$(get_version "$pm" --version | awk '{print $NF}' | head -1)
                ;;
            dnf|yum)
                ver=$(get_version "$pm" --version | awk '{print $3}' | head -1)
                ;;
            snap)
                ver=$(get_version "$pm" version | awk '{print $2}' | head -1)
                ;;
            flatpak)
                ver=$(get_version "$pm" --version | awk '{print $2}' | head -1)
                ;;
            brew)
                ver=$(get_version "$pm" --version | head -1)
                ;;
            zypper)
                ver=$(get_version "$pm" --version | awk '{print $3}' | head -1)
                ;;
            *)
                ver=$(get_version "$pm" --version)
                ;;
        esac

        # Package count per manager (best-effort, non-blocking)
        PKG_COUNT="?"
        case "$pm" in
            apt|apt-get)
                if command_exists dpkg-query; then
                    PKG_COUNT=$(dpkg-query -f '.\n' -W 2>/dev/null | wc -l | tr -d ' ')
                fi
                ;;
            dnf|yum)
                if command_exists rpm; then
                    PKG_COUNT=$(rpm -qa 2>/dev/null | wc -l | tr -d ' ')
                fi
                ;;
            pacman|paru|yay|pikaur)
                PKG_COUNT=$(pacman -Q 2>/dev/null | wc -l | tr -d ' ' || echo "?")
                ;;
            apk)
                PKG_COUNT=$(apk info 2>/dev/null | wc -l | tr -d ' ' || echo "?")
                ;;
            snap)
                if command_exists snap; then
                    PKG_COUNT=$(snap list 2>/dev/null | wc -l | tr -d ' ' || echo "?")
                fi
                ;;
            flatpak)
                if command_exists flatpak; then
                    PKG_COUNT=$(flatpak list 2>/dev/null | wc -l | tr -d ' ' || echo "?")
                fi
                ;;
            brew)
                if command_exists brew; then
                    PKG_COUNT=$(brew list 2>/dev/null | wc -l | tr -d ' ' || echo "?")
                fi
                ;;
            *)
                PKG_COUNT="?"
                ;;
        esac

        if [ "$PKG_COUNT" != "?" ] && [ -n "$PKG_COUNT" ]; then
            printf "  %s[+]%s %-12s %s  %s(%s packages)%s\n" \
                "$GREEN" "$RESET" "$pm" "${ver:-detected}" "$CYAN" "$PKG_COUNT" "$RESET"
        else
            printf "  %s[+]%s %-12s %s\n" "$GREEN" "$RESET" "$pm" "${ver:-detected}"
        fi
    fi
done

if [ $PM_COUNT -eq 0 ]; then
    print_info "No common package managers detected (source build or minimal container?)"
else
    print_success "Detected $PM_COUNT package manager(s):${PM_LIST}"
fi

# 6. Networking, Download & Dev Tools (as per request: curl, wget, git etc.)
print_header "NETWORKING & ESSENTIAL TOOLS"

NET_TOOLS="curl wget git"
ESSENTIAL_TOOLS="tar gzip gunzip xz unzip bzip2 rsync ssh scp nc netcat ping dig nslookup whois make gcc python3 node npm docker podman"

DETECTED_NET=""
DETECTED_ESSENTIAL=""

for tool in $NET_TOOLS $ESSENTIAL_TOOLS; do
    if command_exists "$tool"; then
        if echo "$NET_TOOLS" | grep -qw "$tool"; then
            DETECTED_NET="$DETECTED_NET $tool"
        else
            DETECTED_ESSENTIAL="$DETECTED_ESSENTIAL $tool"
        fi
        # Store individual HAS_ vars later in file
    fi
done

print_info "Networking tools: ${DETECTED_NET# }"
print_info "Essential tools:  ${DETECTED_ESSENTIAL# }"

# 7. Internet connectivity test (quick, 3-4s max)
print_header "CONNECTIVITY CHECK"

INTERNET_CONNECTED="false"
PUBLIC_IP="unavailable"

if command_exists curl; then
    if curl -fsSL --max-time 4 --connect-timeout 3 -o /dev/null \
       https://raw.githubusercontent.com 2>/dev/null; then
        INTERNET_CONNECTED="true"
        print_success "Internet reachable via curl"
        # Public IP (best effort, cached feel)
        PUBLIC_IP=$(curl -s --max-time 3 https://ifconfig.me 2>/dev/null || \
                    curl -s --max-time 3 https://api.ipify.org 2>/dev/null || \
                    echo "unknown")
    fi
elif command_exists wget; then
    if wget -q --timeout=4 --tries=1 -O /dev/null \
       https://raw.githubusercontent.com 2>/dev/null; then
        INTERNET_CONNECTED="true"
        print_success "Internet reachable via wget"
    fi
fi

if [ "$INTERNET_CONNECTED" = "true" ]; then
    print_info "Public IP (approx): $PUBLIC_IP"
else
    print_info "No internet or connectivity test failed (offline mode)"
fi

# --- Network Interfaces: Local IPv4 + IPv6 (detailed) ---
print_header "NETWORK INTERFACES (Local IPv4 / IPv6)"

IPV4_ADDRS=""
IPV6_ADDRS=""

if command_exists ip; then
    IPV4_ADDRS=$(ip -4 addr show scope global 2>/dev/null | grep -oP 'inet \K[\d.]+(/[0-9]+)?' | tr '\n' ' ' | sed 's/ $//')
    IPV6_ADDRS=$(ip -6 addr show scope global 2>/dev/null | grep -oP 'inet6 \K[0-9a-f:]+(/[0-9]+)?' | grep -v '^fe80' | tr '\n' ' ' | sed 's/ $//')
elif command_exists ifconfig; then
    IPV4_ADDRS=$(ifconfig 2>/dev/null | grep -oE 'inet [0-9.]+' | awk '{print $2}' | tr '\n' ' ' | sed 's/ $//')
    IPV6_ADDRS=$(ifconfig 2>/dev/null | grep -oE 'inet6 [0-9a-f:]+' | awk '{print $2}' | grep -v '^fe80' | tr '\n' ' ' | sed 's/ $//')
fi

if [ -n "$IPV4_ADDRS" ]; then
    print_status "IPv4 (global scope)" "$IPV4_ADDRS" "ok"
else
    print_status "IPv4 (global scope)" "none detected on interfaces" "warn"
fi

if [ -n "$IPV6_ADDRS" ]; then
    print_status "IPv6 (global scope)" "$IPV6_ADDRS" "ok"
else
    print_status "IPv6 (global scope)" "none detected on interfaces" "warn"
fi

# --- Write /tmp/.host-info (sourceable profile) --------------------------------
print_header "WRITING HOST PROFILE"

# Truncate/create the file
: > "$INFO_FILE" 2>/dev/null || {
    print_info "Cannot write $INFO_FILE (permissions?) — using /tmp/host-info-fallback"
    INFO_FILE="/tmp/host-info-fallback"
    : > "$INFO_FILE"
}

{
    echo "#!/bin/sh"
    echo "# ==============================================================================="
    echo "# Final Szmelc Commander - Host Environment Profile"
    echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || date)"
    echo "# Script: init.sh v$SCRIPT_VERSION"
    echo "# Host: $HOSTNAME | User: $USER_NAME"
    echo "# ==============================================================================="
    echo ""
    echo "# --- Core System ---"
    echo "export KERNEL=\"$KERNEL\""
    echo "export KERNEL_RELEASE=\"$KERNEL_RELEASE\""
    echo "export ARCH=\"$ARCH\""
    echo "export HOSTNAME=\"$HOSTNAME\""
    echo ""
    echo "# --- Distribution ---"
    echo "export DISTRO_ID=\"$DISTRO_ID\""
    echo "export DISTRO_NAME=\"$DISTRO_NAME\""
    echo "export DISTRO_VERSION=\"$DISTRO_VERSION\""
    echo "export DISTRO_LIKE=\"$DISTRO_LIKE\""
    echo ""
    echo "# --- User & Shell ---"
    echo "export USER=\"$USER_NAME\""
    echo "export UID=\"$USER_UID\""
    echo "export HOME=\"$USER_HOME\""
    echo "export SHELL=\"$CURRENT_SHELL\""
    echo "export SHELL_NAME=\"$SHELL_NAME\""
    echo ""
    echo "# --- Runtime Environment ---"
    echo "export CONTAINER_ENV=\"$CONTAINER_ENV\""
    echo "export INTERNET_CONNECTED=\"$INTERNET_CONNECTED\""
    echo "export PUBLIC_IP=\"$PUBLIC_IP\""
    echo ""
    echo "# --- System Resources ---"
    echo "export UPTIME=\"$UPTIME\""
    echo "export CPU_MODEL=\"$CPU_MODEL\""
    echo "export CPU_CORES=\"$CPU_CORES\""
    echo "export TOTAL_RAM=\"$TOTAL_RAM\""
    echo "export DISK_SUMMARY=\"$DISK_SUMMARY\""
    echo "export IS_SUPERUSER=\"$IS_SUPERUSER\""
    echo ""
    echo "# --- Network Addresses ---"
    echo "export IPV4_ADDRS=\"$IPV4_ADDRS\""
    echo "export IPV6_ADDRS=\"$IPV6_ADDRS\""
    echo ""
    echo "# --- Package Managers (space-separated list + individual versions) ---"
    echo "export DETECTED_PACKAGE_MANAGERS=\"${PM_LIST# }\""
    echo "export PM_COUNT=\"$PM_COUNT\""
} >> "$INFO_FILE"

# Append individual PM versions (only for detected ones)
for pm in $PM_LIST; do
    # Re-detect version for the file (already printed, but to be precise)
    case "$pm" in
        apt|apt-get) ver=$(get_version "$pm" --version | awk '{print $2}' | head -1) ;;
        pacman|paru|yay|pikaur) ver=$(get_version "$pm" --version | awk '{print $NF}' | head -1) ;;
        apk) ver=$(get_version "$pm" --version | awk '{print $NF}' | head -1) ;;
        dnf|yum) ver=$(get_version "$pm" --version | awk '{print $3}' | head -1) ;;
        snap) ver=$(get_version "$pm" version | awk '{print $2}' | head -1) ;;
        flatpak) ver=$(get_version "$pm" --version | awk '{print $2}' | head -1) ;;
        brew) ver=$(get_version "$pm" --version | head -1) ;;
        zypper) ver=$(get_version "$pm" --version | awk '{print $3}' | head -1) ;;
        *) ver=$(get_version "$pm" --version) ;;
    esac
    printf "export PM_VERSION_%s=\"%s\"\n" "$pm" "$ver" >> "$INFO_FILE"
done

{
    echo ""
    echo "# --- Networking & Tools Presence (boolean flags) ---"
} >> "$INFO_FILE"

# Add HAS_ flags for key tools
for tool in curl wget git tar gzip xz unzip rsync ssh scp nc make gcc python3 node docker podman sudo doas; do
    if command_exists "$tool"; then
        upper=$(echo "$tool" | tr '[:lower:]' '[:upper:]' | tr -cd '[:alnum:]_')
        printf "export HAS_%s=\"true\"\n" "$upper" >> "$INFO_FILE"
        tver=$(get_version "$tool" --version)
        printf "export %s_VERSION=\"%s\"\n" "$upper" "$tver" >> "$INFO_FILE"
    else
        upper=$(echo "$tool" | tr '[:lower:]' '[:upper:]' | tr -cd '[:alnum:]_')
        printf "export HAS_%s=\"false\"\n" "$upper" >> "$INFO_FILE"
    fi
done

{
    echo ""
    echo "# --- Quick raw diagnostics (for debugging) ---"
    echo "# uname -a: $(uname -a 2>/dev/null || echo n/a)"
    echo "# os-release excerpt available in original file if present"
    echo ""
    echo "# To reload in another script:"
    echo "#   . $INFO_FILE"
    echo "#   echo \"Package managers available: \$DETECTED_PACKAGE_MANAGERS\""
    echo ""
    echo "# End of host profile — Szmelc Commander ready."
} >> "$INFO_FILE"

chmod 644 "$INFO_FILE" 2>/dev/null || true

print_success "Host profile written to: $INFO_FILE"
print_info "Inspect with: cat $INFO_FILE"
print_info "Load variables: . $INFO_FILE   (or source $INFO_FILE)"

# --- Summary & Next Steps -----------------------------------------------------
print_header "SUMMARY & READINESS"

ELAPSED=$(($(date '+%s' 2>/dev/null || echo 0) - START_TIME))
printf "Detection completed in ~%ss\n\n" "$ELAPSED"

printf "%sEnvironment ready for Szmelc Commander modules and loaders.%s\n" "$GREEN" "$RESET"
printf "Detected package managers will be used by upcoming scripts for install/update paths.\n\n"

# Placeholder for TUI / main commander launch (expand in future versions)
if command_exists whiptail || command_exists dialog; then
    print_info "TUI tools (whiptail/dialog) available — full interactive mode ready for v1.x"
else
    print_info "Text mode active (install whiptail/dialog for enhanced TUI)"
fi

printf "\n%s[ Szmelc Commander initialized — move fast, break nothing important ]%s\n\n" "$BOLD" "$RESET"

# Optional: source the profile ourselves for any post-actions
# . "$INFO_FILE" 2>/dev/null || true

exit 0

#!/usr/bin/env bash
# Coding club workstation setup for Fedora (dnf5).
# Idempotent: `init` and `update` apply the same state, so every PC converges
# to whatever is on the main branch of this repo.
set -uo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/Sebb57/fedora_conf_coding_club/main/install.sh"
CONF_FILE="/etc/coding-club.conf"
STATE_DIR="/var/lib/coding-club"
LOG_FILE="/var/log/coding-club.log"
UPDATE_CMD="/usr/local/bin/club-update"

# Log in automatically and never lock the screen (workshop machines).
AUTOLOGIN=1

PACKAGES=(
    # C / C++
    gcc gcc-c++ make cmake clang clang-tools-extra gdb valgrind
    # Python
    python3 python3-pip python3-devel python3-virtualenv python3-tkinter
    # man pages
    man-db man-pages man-pages-fr
    # CLI tools
    git curl wget unzip tar
    htop btop tmux neovim vim
    ripgrep fd-find fzf bat
    nodejs npm
    zsh zsh-autosuggestions zsh-syntax-highlighting
    flatpak
    asciiquarium
)

DNF_GROUPS=(
    @development-tools
    @c-development
)

VSCODE_EXTENSIONS=(
    ms-python.python
    ms-python.vscode-pylance
    ms-vscode.cpptools
    esbenp.prettier-vscode
    dbaeumer.vscode-eslint
    eamodio.gitlens
    streetsidesoftware.code-spell-checker
    usernamehw.errorlens
)

FAILED=()

log() { echo -e "\n==> $1"; }
warn() { echo -e "[WARN] $1"; }
ok() { echo -e "[OK] $1"; }
die() { echo -e "[ERROR] $1" >&2; exit 1; }

run() {
    local desc="$1"
    shift
    echo ""
    echo "---- $desc ----"
    if ! "$@"; then
        warn "Step failed: $desc"
        FAILED+=("$desc")
    fi
}

dnf_install() {
    dnf install -y --skip-unavailable "$@"
}

as_user() {
    sudo -u "$TARGET_USER" -H -- "$@"
}

# ---------------------------------------------------------------------------
# Target user: the human who will use the PC, not root.
# ---------------------------------------------------------------------------

detect_user() {
    local u=""

    if [[ -n "${TARGET_USER:-}" ]]; then
        u="$TARGET_USER"
    elif [[ -f "$CONF_FILE" ]]; then
        u="$(. "$CONF_FILE"; echo "${TARGET_USER:-}")"
    fi

    if [[ -z "$u" && -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]]; then
        u="$SUDO_USER"
    fi

    if [[ -z "$u" ]]; then
        u="$(logname 2>/dev/null || true)"
        [[ "$u" == root ]] && u=""
    fi

    if [[ -z "$u" ]]; then
        u="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')"
    fi

    [[ -n "$u" ]] || die "No regular user found. Run with: TARGET_USER=<name> $0 init"
    id "$u" &>/dev/null || die "User '$u' does not exist"

    TARGET_USER="$u"
    TARGET_HOME="$(getent passwd "$u" | cut -d: -f6)"
}

save_conf() {
    cat > "$CONF_FILE" <<EOF
# Managed by coding club install.sh
TARGET_USER=$TARGET_USER
EOF
}

# ---------------------------------------------------------------------------
# System
# ---------------------------------------------------------------------------

setup_repos() {
    rpm --import https://packages.microsoft.com/keys/microsoft.asc || return 1
    cat > /etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
}

system_packages() {
    run "System upgrade" dnf upgrade --refresh -y
    run "Development groups" dnf_install "${DNF_GROUPS[@]}"
    run "Packages" dnf_install "${PACKAGES[@]}" code
}

passwordless() {
    usermod -aG wheel "$TARGET_USER" || return 1

    # sudo without password
    local sudoers="/etc/sudoers.d/90-coding-club"
    local tmp
    tmp="$(mktemp)"
    echo "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" > "$tmp"
    if visudo -cf "$tmp" >/dev/null; then
        install -m 0440 -o root -g root "$tmp" "$sudoers"
        rm -f "$tmp"
    else
        rm -f "$tmp"
        return 1
    fi

    # Graphical admin prompts (GNOME Software, settings...) without password
    cat > /etc/polkit-1/rules.d/49-coding-club-nopasswd.rules <<EOF
polkit.addRule(function(action, subject) {
    if (subject.user == "$TARGET_USER") {
        return polkit.Result.YES;
    }
});
EOF
}

autologin() {
    if [[ -d /etc/gdm ]]; then
        cat > /etc/gdm/custom.conf <<EOF
# Managed by coding club install.sh
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=$TARGET_USER

[security]

[xdmcp]

[chooser]

[debug]
EOF
    fi

    if [[ -d /etc/sddm.conf.d ]] || command -v sddm &>/dev/null; then
        mkdir -p /etc/sddm.conf.d
        cat > /etc/sddm.conf.d/90-coding-club-autologin.conf <<EOF
[Autologin]
User=$TARGET_USER
Session=plasma
EOF
    fi

    # GNOME: no lock screen, no screen blanking
    if command -v dconf &>/dev/null; then
        mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
        if [[ ! -f /etc/dconf/profile/user ]] || ! grep -q '^system-db:local' /etc/dconf/profile/user; then
            printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
        fi
        cat > /etc/dconf/db/local.d/00-coding-club <<'EOF'
[org/gnome/desktop/screensaver]
lock-enabled=false

[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/desktop/lockdown]
disable-lock-screen=true
EOF
        dconf update
    fi
}

flatpaks() {
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &&
        flatpak remote-modify --enable flathub &&
        flatpak update -y --noninteractive
}

install_update_cmd() {
    cat > "$UPDATE_CMD" <<EOF
#!/usr/bin/env bash
# Pulls the latest coding club config from GitHub and applies it.
set -euo pipefail
tmp="\$(mktemp --suffix=.sh)"
trap 'rm -f "\$tmp"' EXIT
curl -fsSL "$SCRIPT_URL" -o "\$tmp"
if [[ \$EUID -eq 0 ]]; then
    bash "\$tmp" update
else
    sudo bash "\$tmp" update
fi
EOF
    chmod 0755 "$UPDATE_CMD"
}

# ---------------------------------------------------------------------------
# User environment
# ---------------------------------------------------------------------------

zsh_setup() {
    if [[ -d "$TARGET_HOME/.oh-my-zsh/.git" ]]; then
        as_user git -C "$TARGET_HOME/.oh-my-zsh" pull --ff-only -q || return 1
    else
        rm -rf "$TARGET_HOME/.oh-my-zsh"
        as_user git clone -q --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$TARGET_HOME/.oh-my-zsh" || return 1
    fi

    # Overwritten on every update; personal tweaks go in ~/.zshrc.local
    cat > "$TARGET_HOME/.zshrc" <<'EOF'
# Managed by the coding club script: this file is overwritten by `update-conf`.
# Put your own config in ~/.zshrc.local

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="af-magic"
DISABLE_AUTO_UPDATE=true
plugins=(git)
source "$ZSH/oh-my-zsh.sh"

[[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY

bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# conda (base env is not activated by default)
if [[ -x "$HOME/miniforge3/bin/conda" ]]; then
    eval "$("$HOME/miniforge3/bin/conda" shell.zsh hook)"
fi

alias ls="ls -lah --color=auto"
alias bat="bat --paging=never"
alias update-conf="club-update"

[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
EOF
    chown "$TARGET_USER:" "$TARGET_HOME/.zshrc"

    usermod -s "$(command -v zsh)" "$TARGET_USER"
}

conda_setup() {
    local dir="$TARGET_HOME/miniforge3"

    if [[ ! -x "$dir/bin/conda" ]]; then
        as_user bash -c '
            set -e
            f="$(mktemp --suffix=.sh)"
            curl -fsSL -o "$f" "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-$(uname -m).sh"
            bash "$f" -b -p "$HOME/miniforge3"
            rm -f "$f"
        ' || return 1
    fi

    as_user "$dir/bin/conda" config --set auto_activate false 2>/dev/null ||
        as_user "$dir/bin/conda" config --set auto_activate_base false
}

vscode_setup() {
    local ext
    for ext in "${VSCODE_EXTENSIONS[@]}"; do
        as_user code --install-extension "$ext" --force >/dev/null ||
            warn "Extension $ext failed"
    done

    local settings_dir="$TARGET_HOME/.config/Code/User"
    as_user mkdir -p "$settings_dir"

    # Merge our settings into the existing file (keeps user's other settings)
    as_user python3 - "$settings_dir/settings.json" <<'EOF'
import json, sys, os

path = sys.argv[1]
managed = {
    "files.autoSave": "onFocusChange",
    "files.trimTrailingWhitespace": True,
    "files.insertFinalNewline": True,
    "editor.tabSize": 4,
    "editor.renderWhitespace": "boundary",
    "editor.minimap.enabled": False,
    "security.workspace.trust.enabled": False,
    "telemetry.telemetryLevel": "off",
    "update.mode": "none",
    "workbench.startupEditor": "none",
    "terminal.integrated.defaultProfile.linux": "zsh",
    "python.defaultInterpreterPath": "/usr/bin/python3",
    "C_Cpp.default.compilerPath": "/usr/bin/gcc",
    "git.openRepositoryInParentFolders": "always",
}

settings = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            settings = json.load(f)
    except (ValueError, OSError):
        os.replace(path, path + ".bak")

settings.update(managed)
with open(path, "w") as f:
    json.dump(settings, f, indent=4)
    f.write("\n")
EOF
}

# ---------------------------------------------------------------------------

apply() {
    log "Target user: $TARGET_USER ($TARGET_HOME)"

    run "VS Code repo" setup_repos
    system_packages
    run "Passwordless sudo" passwordless
    if [[ "$AUTOLOGIN" == 1 ]]; then
        run "Autologin / no lock screen" autologin
    fi
    run "Flatpak" flatpaks
    run "Update command" install_update_cmd
    run "Zsh" zsh_setup
    run "Conda (Miniforge)" conda_setup
    run "VS Code config" vscode_setup

    mkdir -p "$STATE_DIR"
    date -Iseconds > "$STATE_DIR/last-sync"

    echo ""
    if ((${#FAILED[@]})); then
        warn "Finished with ${#FAILED[@]} failed step(s):"
        printf '  - %s\n' "${FAILED[@]}"
        echo "Full log: $LOG_FILE"
        exit 1
    fi
    ok "Everything is up to date. Log: $LOG_FILE"
}

main() {
    local cmd="${1:-}"
    case "$cmd" in
        init | update) ;;
        *)
            echo "Usage: $0 [init|update]"
            exit 1
            ;;
    esac

    [[ $EUID -eq 0 ]] || die "Must be run as root (or use 'update-conf' once installed)"

    exec > >(tee -a "$LOG_FILE") 2>&1
    log "$(date -Iseconds) coding club $cmd"

    detect_user
    save_conf
    apply
}

main "$@"

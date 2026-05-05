#!/usr/bin/env bash
set -euo pipefail

INIT_DIR="$HOME/.local/state/fedora-init"
mkdir -p "$INIT_DIR"

log() { echo -e "\n==> $1"; }
warn() { echo -e "\n[WARN] $1"; }
ok() { echo -e "[OK] $1"; }

run() {
    echo ""
    echo "---- $1 ----"
    shift
    "$@" || warn "Step failed: $*"
}

setup_repos() {
    run "System update" sudo dnf update -y

    run "Base tools" sudo dnf install -y \
        dnf-plugins-core \
        git curl wget zsh util-linux-user

    if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
        run "Adding VS Code repo" sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<EOF
[code]
name=VS Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    fi
}

base_packages() {
    run "Base packages" sudo dnf install -y \
        gcc gcc-c++ make cmake clang \
        python3 python3-pip python3-devel \
        git curl wget unzip tar \
        htop btop tmux neovim vim \
        ripgrep fd-find fzf bat \
        nodejs npm \
        man-db man-pages \
        flatpak
}

dev_tools() {
    run "Development Tools group" sudo dnf groupinstall -y "Development Tools"
}

vscode() {
    run "Installing VS Code" sudo dnf install -y code

    local extensions=(
        ms-python.python
        ms-python.vscode-pylance
        ms-vscode.cpptools
        esbenp.prettier-vscode
        dbaeumer.vscode-eslint
        eamodio.gitlens
        streetsidesoftware.code-spell-checker
        usernamehw.errorlens
    )

    for ext in "${extensions[@]}"; do
        run "Installing extension $ext" code --install-extension "$ext"
    done
}

zsh_setup() {
    run "Installing oh-my-zsh" bash -c '
        if [ ! -d "$HOME/.oh-my-zsh" ]; then
            RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        fi
    '

    run "Zsh plugins" bash -c '
        mkdir -p ~/.oh-my-zsh/custom/plugins
        git clone https://github.com/zsh-users/zsh-autosuggestions \
            ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions 2>/dev/null || true

        git clone https://github.com/zsh-users/zsh-syntax-highlighting \
            ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting 2>/dev/null || true
    '

    run "Writing .zshrc" bash -c "cat > ~/.zshrc <<'EOF'
export ZSH=\"\$HOME/.oh-my-zsh\"

ZSH_THEME=\"agnoster\"

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source \$ZSH/oh-my-zsh.sh

HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY

bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

alias ls=\"ls -lah\"
EOF"

    run "Changing default shell" chsh -s "$(which zsh)" "$USER"
}

conda_setup() {
    if [ ! -d "$HOME/miniconda" ]; then
        run "Installing Miniconda" bash -c '
            cd /tmp
            curl -LO https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
            bash Miniconda3-latest-Linux-x86_64.sh -b -p "$HOME/miniconda"
        '
        run "Init conda for zsh" "$HOME/miniconda/bin/conda" init zsh
    else
        ok "Miniconda already installed"
    fi
}

flatpaks() {
    run "Flatpak setup" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    run "Installing flatpaks" flatpak install -y flathub \
        com.spotify.Client \
        org.telegram.desktop \
        org.signal.Signal
}

init() {
    log "STARTING FULL SETUP"

    setup_repos
    dev_tools
    base_packages
    vscode
    zsh_setup
    conda_setup
    flatpaks

    touch "$INIT_DIR/done"
    ok "SETUP COMPLETE"
}

update() {
    log "UPDATING SYSTEM"

    run "System upgrade" sudo dnf upgrade -y

    run "Extra tools" sudo dnf install -y vim

    run "Flatpak update" flatpak update -y

    ok "UPDATE COMPLETE"
}

case "${1:-}" in
    init) init ;;
    update) update ;;
    *) echo "Usage: $0 [init|update]" ;;
esac

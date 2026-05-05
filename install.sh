#!/usr/bin/env bash
set -euo pipefail

INIT_DIR="$HOME/.local/state/fedora-init"
mkdir -p "$INIT_DIR"

log() { echo -e "\n==> $1"; }

setup_repos() {
    sudo dnf update -y

    sudo dnf install -y \
        dnf-plugins-core \
        git curl wget zsh util-linux-user

    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

    sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<EOF
[code]
name=VS Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
}

base_packages() {
    sudo dnf install -y \
        gcc gcc-c++ make cmake clang \
        python3 python3-pip python3-devel \
        git curl wget unzip tar \
        htop btop tmux neovim \
        ripgrep fd-find fzf bat \
        nodejs npm \
        man-db man-pages \
        flatpak
}

dev_tools() {
    sudo dnf5 install dnf5-commands -y
}

vscode() {
    sudo dnf install -y code

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
        code --install-extension "$ext" || true
    done
}

zsh_setup() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi

    git clone https://github.com/zsh-users/zsh-autosuggestions \
        ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions 2>/dev/null || true

    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting 2>/dev/null || true

    cat > ~/.zshrc <<'EOF'
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnoster"

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY

bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

alias ls="ls -lah"
alias updateConf="bash <(curl -fsSL https://raw.githubusercontent.com/Sebb57/fedora_conf_coding_club/main/install.sh) update"
EOF

    chsh -s "$(which zsh)" || true
}

conda_setup() {
    if [ ! -d "$HOME/miniconda" ]; then
        log "Installing Miniconda"
        cd /tmp
        curl -LO https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        bash Miniconda3-latest-Linux-x86_64.sh -b -p "$HOME/miniconda"
        "$HOME/miniconda/bin/conda" init zsh
        rm -f Miniconda3-latest-Linux-x86_64.sh
    fi
}

flatpaks() {
    log "Setting up Flatpak"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    flatpak install -y flathub \
        com.spotify.Client \
        org.telegram.desktop \
        org.signal.Signal || true
}

init() {
    log "INIT: base system setup"
    setup_repos
    dev_tools
    base_packages
    vscode
    zsh_setup
    conda_setup
    flatpaks

    touch "$INIT_DIR/done"
    log "INIT complete"
}

update() {
    log "UPDATE: extra packages"

    sudo dnf upgrade -y

    sudo dnf install -y \
        vim

    flatpak update -y || true

    log "UPDATE complete"
}

usage() {
    cat <<EOF
Usage: $0 [init|update]

init   -> full system setup
update -> additional packages + upgrades
EOF
}

case "${1:-}" in
    init) init ;;
    update) update ;;
    *) usage ;;
esac

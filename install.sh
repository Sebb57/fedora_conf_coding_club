#!/usr/bin/env bash

set -e

echo "Updating system"
sudo dnf update -y

echo "Installing base development tools"
sudo dnf groupinstall -y "Development Tools"

echo "Installing essentials"
sudo dnf install -y \
    python3 python3-pip \
    gcc gcc-c++ make \
    man-db man-pages \
    git curl wget \
    nodejs npm \
    zsh util-linux-user

# -----------------------
# VS CODE INSTALL
# -----------------------
echo "Installing VScode"
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo tee /etc/yum.repos.d/vscode.repo <<EOF
[code]
name=VS Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

sudo dnf install -y code

# -----------------------
# VSCODE EXTENSIONS
# -----------------------
echo "Installing VScode extensions"

extensions=(
    # Python
    ms-python.python
    ms-python.vscode-pylance

    # C/C++
    ms-vscode.cpptools

    # Web
    esbenp.prettier-vscode
    dbaeumer.vscode-eslint
    ritwickdey.liveserver

    # Git
    eamodio.gitlens

    # General
    streetsidesoftware.code-spell-checker
    usernamehw.errorlens
)

for ext in "${extensions[@]}"; do
    code --install-extension $ext || true
done

# -----------------------
# VSCODE SETTINGS
# -----------------------
echo "Configuring VS Code settings..."

mkdir -p ~/.config/Code/User

cat > ~/.config/Code/User/settings.json <<EOF
{
    "files.autoSave": "onFocusChange",
    "editor.formatOnSave": true,
    "editor.tabSize": 4,
    "editor.minimap.enabled": false,
    "workbench.startupEditor": "none",
    "editor.fontSize": 14,
    "editor.wordWrap": "on",
    "terminal.integrated.defaultProfile.linux": "zsh"
}
EOF

# -----------------------
# MINICONDA INSTALL
# -----------------------
echo "Installing Miniconda..."
cd /tmp
curl -LO https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda
$HOME/miniconda/bin/conda init
rm -f Miniconda3-latest-Linux-x86_64.sh

# -----------------------
# ZSH + OH MY ZSH
# -----------------------
echo "Installing Oh My Zsh..."
RUNZSH=no CHSH=no sh -c \
"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Plugins
echo "Installing Zsh plugins..."

git clone https://github.com/zsh-users/zsh-autosuggestions \
    ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# -----------------------
# ZSH CONFIG
# -----------------------
echo "Configuring .zshrc..."

cat > ~/.zshrc <<'EOF'
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnoster"

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Better history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY

# Autocomplete tweaks
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# Aliases
alias ls="ls -lah"
EOF

# -----------------------
# SET ZSH DEFAULT
# -----------------------
echo "Setting Zsh as default shell"
chsh -s $(which zsh)

echo "Done. Reboot or run: exec zsh"

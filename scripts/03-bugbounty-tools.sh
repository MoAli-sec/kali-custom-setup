#!/usr/bin/env bash
# 03-bugbounty-tools.sh — recon, fuzzing, and web-app testing toolkit
#
# Most of Burp Suite, nmap, sqlmap, gobuster etc. ship with Kali already.
# This script fills the gaps with the ProjectDiscovery suite and a few
# other tools that live-and-die on HackerOne-style workflows.
set -uo pipefail

GOPATH_BIN="$HOME/go/bin"
mkdir -p "$HOME/tools/bugbounty"

# ---- Go toolchain (needed for most modern recon tools) ---------------------
if ! command -v go &>/dev/null; then
    echo "[*] Installing Go..."
    sudo apt update
    sudo apt install -y golang-go
else
    echo "[=] Go already installed: $(go version)"
fi

# make sure ~/go/bin is on PATH for this script's own use
export PATH="$PATH:$GOPATH_BIN"

install_go_tool() {
    local module="$1"
    local binname="$2"
    if command -v "$binname" &>/dev/null; then
        echo "    [=] $binname already installed"
    else
        echo "    [+] installing $binname"
        go install "$module@latest" || echo "    [!] failed to install $binname — skipping"
    fi
}

echo "[*] Installing ProjectDiscovery + recon tooling (via go install)..."
install_go_tool "github.com/projectdiscovery/subfinder/v2/cmd/subfinder"   subfinder
install_go_tool "github.com/projectdiscovery/httpx/cmd/httpx"              httpx
install_go_tool "github.com/projectdiscovery/nuclei/v3/cmd/nuclei"         nuclei
install_go_tool "github.com/projectdiscovery/naabu/v2/cmd/naabu"           naabu
install_go_tool "github.com/projectdiscovery/notify/cmd/notify"            notify
install_go_tool "github.com/projectdiscovery/katana/cmd/katana"            katana
install_go_tool "github.com/tomnomnom/waybackurls"                        waybackurls
install_go_tool "github.com/tomnomnom/anew"                               anew
install_go_tool "github.com/tomnomnom/assetfinder"                        assetfinder
install_go_tool "github.com/lc/gau/v2/cmd/gau"                             gau
install_go_tool "github.com/ffuf/ffuf/v2"                                  ffuf
install_go_tool "github.com/hahwul/dalfox/v2"                              dalfox
install_go_tool "github.com/OJ/gobuster/v3"                                gobuster

# ---- apt packages that are also core to bug bounty work --------------------
APT_PACKAGES=(
    nmap
    sqlmap
    burpsuite
    whatweb
    nikto
    wpscan
    seclists
    amass
    hydra
)

echo "[*] Installing apt-based bug bounty packages..."
sudo apt update
for pkg in "${APT_PACKAGES[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo "    [=] $pkg already installed"
    else
        echo "    [+] installing $pkg"
        sudo apt install -y "$pkg" || echo "    [!] failed to install $pkg — skipping"
    fi
done

# ---- nuclei templates -------------------------------------------------------
if command -v nuclei &>/dev/null; then
    echo "[*] Updating nuclei templates..."
    nuclei -update-templates -silent || true
fi

echo "[+] Bug bounty toolkit installed."
echo "    Make sure \$HOME/go/bin is on your PATH (handled by dotfiles/zsh/exports.zsh)."
echo
echo "    Burp Suite extensions worth adding manually (BApp Store, inside Burp):"
echo "      - Logger++      — better request/response logging and filtering"
echo "      - ActiveScan++  — extends the active scanner's checks"
echo "      - Autorize      — automated authorization/access-control testing"
echo "      - Param Miner   — finds hidden parameters and cache-poisoning issues"

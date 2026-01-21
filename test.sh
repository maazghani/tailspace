#!/bin/bash
# Tailspace Dev Container - Consolidated Test & Setup Script
# This script runs all verifications and setup

set -e

echo "=============================================="
echo "Tailspace Dev Container - Verification"
echo "=============================================="
echo ""

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASSED=0
FAILED=0

test_cmd() {
    local description="$1"
    local command="$2"
    
    echo -n "Testing: $description... "
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((FAILED++))
    fi
}

# ============================================================================
# SECTION 1: Verify Files Exist
# ============================================================================
echo "File Verification"
echo "=============================================="
test_cmd "devcontainer.json exists" "[ -f .devcontainer/devcontainer.json ]"
test_cmd "devcontainer-setup.sh exists" "[ -f .devcontainer/devcontainer-setup.sh ]"
test_cmd "starship.toml exists" "[ -f .devcontainer/starship.toml ]"
test_cmd "nvim_init.lua exists" "[ -f .devcontainer/nvim_init.lua ]"
test_cmd "Makefile exists" "[ -f Makefile ]"
echo ""

# ============================================================================
# SECTION 2: Verify Devcontainer Configuration
# ============================================================================
echo "Devcontainer Configuration"
echo "=============================================="
test_cmd "Docker-in-Docker enabled" "grep -q 'docker-in-docker' .devcontainer/devcontainer.json"
test_cmd "SSHD enabled" "grep -q 'sshd' .devcontainer/devcontainer.json"
test_cmd "Port 22 forwarded" "grep -q '22' .devcontainer/devcontainer.json"
test_cmd "Port 6443 forwarded" "grep -q '6443' .devcontainer/devcontainer.json"
test_cmd "Remote user vscode" "grep -q 'vscode' .devcontainer/devcontainer.json"
test_cmd "postCreateCommand set" "grep -q 'devcontainer-setup.sh' .devcontainer/devcontainer.json"
test_cmd "postStartCommand set" "grep -q 'kind create cluster' .devcontainer/devcontainer.json"
test_cmd "Privileged mode enabled" "grep -q 'privileged' .devcontainer/devcontainer.json"
echo ""

# ============================================================================
# SECTION 3: Verify Setup Script Content
# ============================================================================
echo "Setup Script Content"
echo "=============================================="
test_cmd "APT packages section" "grep -q 'APT PACKAGES' .devcontainer/devcontainer-setup.sh"
test_cmd "Node.js installation" "grep -q 'NODEJS' .devcontainer/devcontainer-setup.sh"
test_cmd "Python3 installation" "grep -q 'PYTHON3' .devcontainer/devcontainer-setup.sh"
test_cmd "Docker CLI installation" "grep -q 'DOCKER CLI' .devcontainer/devcontainer-setup.sh"
test_cmd "kubectl installation" "grep -q 'KUBECTL' .devcontainer/devcontainer-setup.sh"
test_cmd "Kind installation" "grep -q 'KIND' .devcontainer/devcontainer-setup.sh"
test_cmd "Starship installation" "grep -q 'STARSHIP' .devcontainer/devcontainer-setup.sh"
test_cmd "Neovim installation" "grep -q 'NEOVIM' .devcontainer/devcontainer-setup.sh"
test_cmd "kubectl aliases" "grep -q 'kubectl-aliases' .devcontainer/devcontainer-setup.sh"
test_cmd "Kind cluster creation" "grep -q 'kind create cluster' .devcontainer/devcontainer-setup.sh"
test_cmd "Idempotency checks" "grep -q 'command -v' .devcontainer/devcontainer-setup.sh"
echo ""

# ============================================================================
# SECTION 4: Verify Starship Configuration
# ============================================================================
echo "Starship Configuration"
echo "=============================================="
test_cmd "Catppuccin theme" "grep -q 'catppuccin' .devcontainer/starship.toml"
test_cmd "Macchiato flavor" "grep -q 'macchiato' .devcontainer/starship.toml"
test_cmd "Git integration" "grep -q 'git_branch' .devcontainer/starship.toml"
echo ""

# ============================================================================
# SECTION 5: Verify Neovim Configuration
# ============================================================================
echo "Neovim Configuration"
echo "=============================================="
test_cmd "Lazy.nvim bootstrap" "grep -q 'lazy.nvim' .devcontainer/nvim_init.lua"
test_cmd "Catppuccin plugin" "grep -q 'catppuccin' .devcontainer/nvim_init.lua"
test_cmd "Mason plugin" "grep -q 'mason' .devcontainer/nvim_init.lua"
test_cmd "LSPConfig plugin" "grep -q 'nvim-lspconfig' .devcontainer/nvim_init.lua"
test_cmd "Treesitter plugin" "grep -q 'nvim-treesitter' .devcontainer/nvim_init.lua"
test_cmd "Completion plugin" "grep -q 'nvim-cmp' .devcontainer/nvim_init.lua"
test_cmd "LSP servers configured" "grep -q 'lua_ls' .devcontainer/nvim_init.lua"
echo ""

# ============================================================================
# SECTION 6: Verify Makefile
# ============================================================================
echo "Makefile Targets"
echo "=============================================="
test_cmd "help target" "grep -q 'help:' Makefile"
test_cmd "install-local target" "grep -q 'install-local:' Makefile"
test_cmd "build target" "grep -q 'build:' Makefile"
test_cmd "test target" "grep -q 'test:' Makefile"
test_cmd "clean target" "grep -q 'clean:' Makefile"
echo ""

# ============================================================================
# SUMMARY
# ============================================================================
TOTAL=$((PASSED + FAILED))
echo "=============================================="
echo "Results: $PASSED/$TOTAL passed"
echo "=============================================="

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. chmod +x .devcontainer/devcontainer-setup.sh"
    echo "  2. bash .devcontainer/devcontainer-setup.sh"
    echo "  3. Verify tools: command -v kubectl kind starship nvim docker"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi

#!/bin/bash
set -e

# Idempotent dev container setup script
# Installs all prerequisites, tools, and configurations for the dev environment

LOG_PREFIX="[devcontainer-setup]"

log_info() {
    echo "${LOG_PREFIX} INFO: $*" >&2
}

log_error() {
    echo "${LOG_PREFIX} ERROR: $*" >&2
}

log_success() {
    echo "${LOG_PREFIX} SUCCESS: $*" >&2
}

# Set repo user (vscode when running in container, fall back to current user)
REPO_USER="${REMOTE_USER:-vscode}"
REPO_GROUP="${REPO_USER}"

log_info "Starting dev container setup for user: $REPO_USER"

# ============================================================================
# 1. APT PACKAGES
# ============================================================================
log_info "Installing APT packages..."
apt-get update || log_error "Failed to update apt"

# Core build tools and utilities
APT_PACKAGES="curl git ca-certificates build-essential pkg-config cmake unzip ripgrep"

# Install apt packages (skip if already present)
for pkg in $APT_PACKAGES; do
    if ! dpkg -l | grep -q "^ii  $pkg"; then
        log_info "Installing $pkg..."
        apt-get install -y "$pkg" 2>/dev/null || log_error "Failed to install $pkg"
    else
        log_info "Package $pkg already installed"
    fi
done

# ============================================================================
# 2. NODEJS & NPM
# ============================================================================
if ! command -v node &> /dev/null; then
    log_info "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - || log_error "Failed to add Node.js repo"
    apt-get install -y nodejs || log_error "Failed to install Node.js"
else
    log_info "Node.js already installed: $(node --version)"
fi

# ============================================================================
# 3. PYTHON3
# ============================================================================
if ! command -v python3 &> /dev/null; then
    log_info "Installing python3..."
    apt-get install -y python3 python3-pip || log_error "Failed to install python3"
else
    log_info "Python3 already installed: $(python3 --version)"
fi

# ============================================================================
# 4. DOCKER CLI
# ============================================================================
if ! command -v docker &> /dev/null; then
    log_info "Installing Docker CLI..."
    apt-get install -y docker.io || log_error "Failed to install docker.io"
    # Add vscode user to docker group
    usermod -aG docker "$REPO_USER" 2>/dev/null || true
else
    log_info "Docker CLI already installed"
fi

# ============================================================================
# 5. KUBECTL
# ============================================================================
if ! command -v kubectl &> /dev/null; then
    log_info "Installing kubectl (latest stable)..."
    KUBECTL_VERSION=$(curl -s https://dl.k8s.io/release/stable.txt)
    curl -L "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
        -o /usr/local/bin/kubectl || log_error "Failed to download kubectl"
    chmod +x /usr/local/bin/kubectl
    log_success "Installed kubectl: $KUBECTL_VERSION"
else
    log_info "kubectl already installed: $(kubectl version --client --short 2>/dev/null || echo 'installed')"
fi

# ============================================================================
# 6. KIND
# ============================================================================
if ! command -v kind &> /dev/null; then
    log_info "Installing Kind..."
    curl -L https://github.com/kubernetes-sigs/kind/releases/download/v0.20.0/kind-linux-amd64 \
        -o /usr/local/bin/kind || log_error "Failed to download kind"
    chmod +x /usr/local/bin/kind
    log_success "Installed Kind v0.20.0"
else
    log_info "Kind already installed: $(kind version)"
fi

# ============================================================================
# 7. STARSHIP
# ============================================================================
if ! command -v starship &> /dev/null; then
    log_info "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes || log_error "Failed to install starship"
    log_success "Installed Starship"
else
    log_info "Starship already installed: $(starship --version)"
fi

# ============================================================================
# 8. NEOVIM
# ============================================================================
if ! command -v nvim &> /dev/null; then
    log_info "Installing Neovim..."
    apt-get install -y neovim || log_error "Failed to install neovim"
    log_success "Installed Neovim"
else
    log_info "Neovim already installed: $(nvim --version | head -1)"
fi

# ============================================================================
# 9. STARSHIP CONFIG
# ============================================================================
log_info "Configuring Starship..."
STARSHIP_CONFIG_DIR="/home/$REPO_USER/.config"
STARSHIP_CONFIG_FILE="$STARSHIP_CONFIG_DIR/starship.toml"

mkdir -p "$STARSHIP_CONFIG_DIR"

# Copy starship config if it exists in repo
if [ -f "/workspaces/tailspace/.devcontainer/starship.toml" ]; then
    cp /workspaces/tailspace/.devcontainer/starship.toml "$STARSHIP_CONFIG_FILE"
    log_info "Copied starship.toml from repo"
elif [ ! -f "$STARSHIP_CONFIG_FILE" ]; then
    # Create default starship config
    cat > "$STARSHIP_CONFIG_FILE" <<'EOF'
format = """
[┌───────────────────>](bold green)
[│](bold green) $username@$hostname in $directory$git_branch$git_status
[└─>](bold green) $character """

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

[username]
show_always = true
format = "[$user]($style)"

[hostname]
ssh_only = false
format = "[$hostname]($style)"

[directory]
truncation_length = 3
format = "[$path]($style)"

[git_branch]
format = "on [$symbol$branch]($style) "

[git_status]
format = "[\\($all_status$ahead_behind\\)]($style) "

[nodejs]
format = "via [$symbol($version )]($style)"

[python]
format = "via [$symbol($version )]($style)"

[docker_context]
format = "via [$symbol$context]($style) "

[kubernetes]
format = "via [$symbol$context( \\($namespace\\))]($style) "
disabled = false
EOF
    log_info "Created default starship.toml"
fi

if id "$REPO_USER" &>/dev/null; then
    chown "$REPO_USER:$REPO_GROUP" "$STARSHIP_CONFIG_FILE" || log_error "Failed to chown starship config"
fi

# Ensure starship init is loaded in bashrc
BASHRC_PATH="/home/$REPO_USER/.bashrc"
if [ -f "$BASHRC_PATH" ]; then
    if ! grep -q 'eval "$(starship init bash)"' "$BASHRC_PATH"; then
        echo 'eval "$(starship init bash)"' >> "$BASHRC_PATH"
        log_info "Added starship to bashrc"
    fi
fi

# ============================================================================
# 10. KUBECTL ALIASES
# ============================================================================
log_info "Setting up kubectl aliases..."
ALIASES_FILE="/etc/profile.d/kubectl-aliases.sh"

cat > "$ALIASES_FILE" <<'EOF'
# kubectl aliases
alias k='kubectl'
alias kg='kubectl get'
alias kgp='kubectl get pods'
alias kgpo='kubectl get pods'
alias kga='kubectl get all'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias kctx='kubectl config current-context'
EOF

chmod 644 "$ALIASES_FILE"
log_info "Installed kubectl aliases in $ALIASES_FILE"

# ============================================================================
# 11. NEOVIM CONFIG
# ============================================================================
log_info "Configuring Neovim..."
NVIM_CONFIG_DIR="/home/$REPO_USER/.config/nvim"
NVIM_CONFIG_FILE="$NVIM_CONFIG_DIR/init.lua"

mkdir -p "$NVIM_CONFIG_DIR"

# Copy nvim config if it exists in repo
if [ -f "/workspaces/tailspace/.devcontainer/nvim_init.lua" ]; then
    cp /workspaces/tailspace/.devcontainer/nvim_init.lua "$NVIM_CONFIG_FILE"
    log_info "Copied nvim config from repo"
elif [ ! -f "$NVIM_CONFIG_FILE" ]; then
    # Create default neovim config with Catppuccin and LSP/Treesitter/CMP setup
    cat > "$NVIM_CONFIG_FILE" <<'EOF'
-- Neovim init.lua configuration
-- Bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Basic vim settings
vim.o.termguicolors = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.tabstop = 2
vim.o.smartindent = true
vim.o.wrap = false
vim.o.ignorecase = true
vim.o.smartcase = true

-- Plugins
local plugins = {
  -- Catppuccin colorscheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "macchiato",
        transparent_background = false,
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- LSP Configuration
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "pyright", "ts_ls" },
      })

      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local servers = { "lua_ls", "pyright", "ts_ls" }
      for _, server in ipairs(servers) do
        lspconfig[server].setup({
          capabilities = capabilities,
        })
      end
    end,
  },

  -- Treesitter for syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "lua", "python", "javascript", "typescript", "bash", "json" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- Completion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
        }, {
          { name = "buffer" },
        }),
      })

      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = "path" },
        }, {
          { name = "cmdline" },
        }),
      })
    end,
  },
}

require("lazy").setup(plugins, {
  checker = { enabled = false },
})

-- Additional keymaps
local map = vim.keymap.set
map("n", "<leader>e", vim.diagnostic.open_float, { noremap = true, silent = true })
map("n", "[d", vim.diagnostic.goto_prev, { noremap = true, silent = true })
map("n", "]d", vim.diagnostic.goto_next, { noremap = true, silent = true })
EOF
    log_info "Created default neovim config"
fi

if id "$REPO_USER" &>/dev/null; then
    chown -R "$REPO_USER:$REPO_GROUP" "$NVIM_CONFIG_DIR" || log_error "Failed to chown nvim config"
fi

# ============================================================================
# 12. DOCKER READINESS CHECK
# ============================================================================
log_info "Checking Docker daemon..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if docker info &> /dev/null; then
        log_success "Docker is ready"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
        log_info "Docker not ready, waiting... ($ATTEMPT/$MAX_ATTEMPTS)"
        sleep 2
    fi
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    log_error "Docker did not become ready within timeout"
else
    log_success "Docker is responsive"
fi

# ============================================================================
# 13. KIND CLUSTER
# ============================================================================
log_info "Setting up Kind cluster..."

if docker info &> /dev/null; then
    if kind get clusters 2>/dev/null | grep -q "^dev$"; then
        log_info "Kind cluster 'dev' already exists"
    else
        log_info "Creating Kind cluster 'dev'..."
        if kind create cluster --name dev --wait 5m 2>&1 | tee /tmp/kind-create.log; then
            log_success "Kind cluster 'dev' created successfully"
        else
            log_error "Failed to create Kind cluster (see /tmp/kind-create.log)"
        fi
    fi
else
    log_error "Docker is not available, skipping Kind cluster creation"
fi

# ============================================================================
# 14. SET PERMISSIONS
# ============================================================================
log_info "Setting repo file ownership to $REPO_USER:$REPO_GROUP..."
if id "$REPO_USER" &>/dev/null && [ -d "/workspaces/tailspace" ]; then
    chown -R "$REPO_USER:$REPO_GROUP" /workspaces/tailspace || log_error "Failed to chown repo"
else
    log_info "Skipping chown (user $REPO_USER does not exist or repo not found)"
fi

log_success "Dev container setup completed"

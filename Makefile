# dotfiles — one-command setup for a new macOS device
# Usage:
#   make deps      # install all brew dependencies + fonts
#   make install   # symlink/copy all configs into place
#   make all       # deps + install
#   make uninstall # remove symlinks (leaves deps installed)

SHELL := /bin/bash
HOME_DIR := $(HOME)

# ── Dependency installation ──────────────────────────────────────

.PHONY: deps deps-brew deps-font deps-cask

deps: deps-brew deps-font deps-cask
	@echo "✓ All dependencies installed"

deps-brew:
	@echo "Installing brew packages..."
	@command -v brew >/dev/null || (echo "Error: Homebrew not installed. Install from https://brew.sh" && exit 1)
	brew install starship tmux jq

deps-font:
	@echo "Installing JetBrainsMono Nerd Font..."
	brew install --cask font-jetbrains-mono-nerd-font 2>/dev/null || true

deps-cask:
	@echo "Installing cask apps (ghostty, cmux)..."
	brew install --cask ghostty 2>/dev/null || echo "  ghostty: install manually if not in brew"
	brew install --cask cmux 2>/dev/null || echo "  cmux: install manually from https://github.com/manaflow-ai/cmux"

# ── Config installation ──────────────────────────────────────────

.PHONY: install install-starship install-ghostty install-tmux install-cmux install-claude-real install-moltis

install: install-starship install-ghostty install-tmux install-cmux install-claude-real install-moltis
	@echo "✓ All configs installed"

install-starship:
	@echo "Installing starship config..."
	@mkdir -p $(HOME_DIR)/.config
	@ln -sf $(CURDIR)/starship/starship.toml $(HOME_DIR)/.config/starship.toml

install-ghostty:
	@echo "Installing ghostty config..."
	@mkdir -p $(HOME_DIR)/.config/ghostty
	@ln -sf $(CURDIR)/ghostty/config $(HOME_DIR)/.config/ghostty/config

install-tmux:
	@echo "Installing tmux config..."
	@ln -sf $(CURDIR)/tmux/.tmux.conf $(HOME_DIR)/.tmux.conf

install-cmux:
	@echo "Installing cmux config..."
	@mkdir -p $(HOME_DIR)/.config/cmux
	@ln -sf $(CURDIR)/cmux/settings.json $(HOME_DIR)/.config/cmux/settings.json

install-claude-real:
	@echo "Installing claude-real config..."
	@mkdir -p $(HOME_DIR)/.claude-real
	@mkdir -p $(HOME_DIR)/.config/ccstatusline
	@cp $(CURDIR)/claude-real/statusline.sh $(HOME_DIR)/.config/ccstatusline/statusline.sh
	@chmod +x $(HOME_DIR)/.config/ccstatusline/statusline.sh
	@# Render settings.json with correct HOME path for statusline
	@sed 's|/Users/yufanfei|$(HOME_DIR)|g' $(CURDIR)/claude-real/settings.json \
		> $(HOME_DIR)/.claude-real/settings.json
	@cp -n $(CURDIR)/claude-real/CLAUDE.md $(HOME_DIR)/.claude-real/CLAUDE.md 2>/dev/null || true

install-moltis:
	@echo "Installing moltis config..."
	@mkdir -p $(HOME_DIR)/.config/moltis
	@if [ ! -f .env ]; then \
		echo "  ⚠ No .env file found. Copy .env.example to .env and fill in secrets first."; \
		echo "    cp .env.example .env && $$EDITOR .env"; \
		exit 1; \
	fi
	@# Source .env and render template
	@set -a && . ./.env && set +a && \
		sed \
			-e "s|\$${TELEGRAM_BOT_TOKEN}|$$TELEGRAM_BOT_TOKEN|g" \
			-e "s|\$${TELEGRAM_USER_ID}|$$TELEGRAM_USER_ID|g" \
			-e "s|\$${HOME}|$(HOME_DIR)|g" \
			$(CURDIR)/moltis/moltis.toml.template \
			> $(HOME_DIR)/.config/moltis/moltis.toml
	@echo "  ✓ moltis.toml rendered with secrets from .env"

# ── Convenience ──────────────────────────────────────────────────

.PHONY: all uninstall

all: deps install

uninstall:
	@echo "Removing symlinks..."
	@rm -f $(HOME_DIR)/.config/starship.toml
	@rm -f $(HOME_DIR)/.config/ghostty/config
	@rm -f $(HOME_DIR)/.tmux.conf
	@rm -f $(HOME_DIR)/.config/cmux/settings.json
	@rm -f $(HOME_DIR)/.config/ccstatusline/statusline.sh
	@echo "✓ Symlinks removed (claude-real and moltis configs left intact — remove manually if needed)"

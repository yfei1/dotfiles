# dotfiles — one-command setup for a new macOS device
# Usage:
#   make all            # full bootstrap: brew, deps, build, configs, shell
#   make deps           # install all brew dependencies + fonts + apps
#   make build-moltis   # clone and cargo build moltis from fork
#   make install        # symlink/copy all configs into place
#   make shell          # inject aliases into ~/.zshrc
#   make uninstall      # remove symlinks (leaves deps/binaries installed)

SHELL := /bin/bash
HOME_DIR := $(HOME)
MOLTIS_SRC := $(HOME_DIR)/src/moltis
MOLTIS_REPO := git@github.com:yfei1/moltis.git

# ══════════════════════════════════════════════════════════════════
# Full bootstrap
# ══════════════════════════════════════════════════════════════════

.PHONY: all
all: deps build-moltis install shell
	@echo ""
	@echo "✓ All done. Restart your shell or run: exec zsh"

# ══════════════════════════════════════════════════════════════════
# Dependencies
# ══════════════════════════════════════════════════════════════════

.PHONY: deps deps-homebrew deps-brew deps-font deps-cask deps-rust deps-voice

deps: deps-homebrew deps-brew deps-font deps-cask deps-rust deps-voice
	@echo "✓ All dependencies installed"

deps-homebrew:
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
		eval "$$(/opt/homebrew/bin/brew shellenv)"; \
	else \
		echo "Homebrew already installed"; \
	fi

deps-brew: deps-homebrew
	@echo "Installing brew packages..."
	brew install starship tmux jq git

deps-font: deps-homebrew
	@echo "Installing JetBrainsMono Nerd Font..."
	brew install --cask font-jetbrains-mono-nerd-font 2>/dev/null || true

deps-cask: deps-homebrew
	@echo "Installing cask apps..."
	brew install --cask ghostty 2>/dev/null || echo "  ghostty: install manually if not in brew"
	brew install --cask cmux 2>/dev/null || echo "  cmux: install manually from https://github.com/manaflow-ai/cmux"

deps-rust:
	@if ! command -v cargo >/dev/null 2>&1; then \
		echo "Installing Rust toolchain..."; \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; \
		. "$(HOME_DIR)/.cargo/env"; \
	else \
		echo "Rust toolchain already installed"; \
	fi

deps-voice: deps-homebrew
	@echo "Installing voice dependencies (whisper-cpp)..."
	brew install whisper-cpp 2>/dev/null || true
	@# Download whisper large-v3 model if not present
	@mkdir -p $(HOME_DIR)/.local/share/whisper-cpp/models
	@if [ ! -f $(HOME_DIR)/.local/share/whisper-cpp/models/ggml-large-v3.bin ]; then \
		echo "Downloading whisper large-v3 model (~3GB)..."; \
		curl -L -o $(HOME_DIR)/.local/share/whisper-cpp/models/ggml-large-v3.bin \
			"https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"; \
	else \
		echo "Whisper model already present"; \
	fi

# ══════════════════════════════════════════════════════════════════
# Build moltis from fork
# ══════════════════════════════════════════════════════════════════

.PHONY: build-moltis

build-moltis: deps-rust
	@mkdir -p $(HOME_DIR)/src
	@if [ ! -d $(MOLTIS_SRC) ]; then \
		echo "Cloning moltis fork..."; \
		git clone $(MOLTIS_REPO) $(MOLTIS_SRC); \
	else \
		echo "Updating moltis fork..."; \
		cd $(MOLTIS_SRC) && git pull --ff-only; \
	fi
	@echo "Building moltis (release)..."
	cd $(MOLTIS_SRC) && cargo build --release
	@mkdir -p $(HOME_DIR)/.local/bin
	@cp $(MOLTIS_SRC)/target/release/moltis $(HOME_DIR)/.local/bin/moltis
	@echo "✓ moltis installed to ~/.local/bin/moltis"

# ══════════════════════════════════════════════════════════════════
# Config installation
# ══════════════════════════════════════════════════════════════════

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

# ══════════════════════════════════════════════════════════════════
# Shell aliases
# ══════════════════════════════════════════════════════════════════

.PHONY: shell

ZSHRC := $(HOME_DIR)/.zshrc
MARKER := \# --- dotfiles-managed ---

shell:
	@echo "Injecting shell config into ~/.zshrc..."
	@if grep -q 'dotfiles-managed' $(ZSHRC) 2>/dev/null; then \
		echo "  Shell aliases already present, skipping"; \
	else \
		printf '\n# --- dotfiles-managed ---\n' >> $(ZSHRC); \
		printf '# Starship prompt\n' >> $(ZSHRC); \
		printf 'eval "$$(starship init zsh)"\n\n' >> $(ZSHRC); \
		printf '# Claude aliases\n' >> $(ZSHRC); \
		printf 'alias claude-real='"'"'CLAUDE_CONFIG_DIR=~/.claude-real ~/.local/bin/claude-real'"'"'\n' >> $(ZSHRC); \
		printf 'alias claude='"'"'echo "Use claude-real or claude-apple"'"'"'\n\n' >> $(ZSHRC); \
		printf '# PATH: local binaries\n' >> $(ZSHRC); \
		printf '[[ :$$PATH: == *:$$HOME/.local/bin:* ]] || export PATH="$$HOME/.local/bin:$$PATH"\n' >> $(ZSHRC); \
		printf '# --- dotfiles-managed ---\n' >> $(ZSHRC); \
		echo "  ✓ Aliases added to ~/.zshrc"; \
	fi

# ══════════════════════════════════════════════════════════════════
# Cleanup
# ══════════════════════════════════════════════════════════════════

.PHONY: uninstall

uninstall:
	@echo "Removing symlinks..."
	@rm -f $(HOME_DIR)/.config/starship.toml
	@rm -f $(HOME_DIR)/.config/ghostty/config
	@rm -f $(HOME_DIR)/.tmux.conf
	@rm -f $(HOME_DIR)/.config/cmux/settings.json
	@rm -f $(HOME_DIR)/.config/ccstatusline/statusline.sh
	@echo "✓ Symlinks removed (claude-real/moltis configs and binaries left intact)"

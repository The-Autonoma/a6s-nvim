.PHONY: help install lint test test-coverage clean doc dev check all

PLENARY_DIR ?= /tmp/nvim/site/pack/plenary/start/plenary.nvim

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install test dependencies (plenary.nvim)
	@mkdir -p $(dir $(PLENARY_DIR))
	@if [ ! -d "$(PLENARY_DIR)" ]; then \
		echo "Cloning plenary.nvim into $(PLENARY_DIR)"; \
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(PLENARY_DIR); \
	else \
		echo "plenary.nvim already installed at $(PLENARY_DIR)"; \
	fi

lint: ## Run luacheck
	@command -v luacheck >/dev/null 2>&1 || { echo "luacheck not found (install via luarocks)"; exit 0; }
	@luacheck lua/ tests/ --globals vim describe it before_each after_each assert --no-max-line-length

test: install ## Run plenary busted tests
	@PLENARY_PATH=$(PLENARY_DIR) nvim --headless --noplugin \
		-u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua', sequential = true }" \
		-c "qall!"

test-coverage: install ## Run tests with luacov and enforce >=80% line coverage
	@command -v luacov >/dev/null 2>&1 || { echo "luacov not installed (install via luarocks)"; exit 1; }
	@rm -f luacov.stats.out luacov.report.out
	@PLENARY_PATH=$(PLENARY_DIR) LUA_PATH="./lua/?.lua;./lua/?/init.lua;;" \
		nvim --headless --noplugin \
		-u tests/minimal_init.lua \
		-c "lua require('luacov')" \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua', sequential = true }" \
		-c "qall!"
	@luacov
	@tail -20 luacov.report.out
	@awk '/^Total/ {pct=$$NF; gsub("%","",pct); if (pct+0 < 80) { printf "FAIL: coverage %s%% < 80%%\n", pct; exit 1 } else { printf "OK: coverage %s%%\n", pct } }' luacov.report.out

clean: ## Clean generated files
	@rm -f doc/tags luacov.stats.out luacov.report.out
	@find . -name "*.luac" -delete

doc: ## Generate help tags
	@nvim --headless -c "helptags doc" -c "qall!"

dev: ## Start nvim with minimal config
	@nvim -u tests/minimal_init.lua

check: lint test ## Run lint and tests

all: clean lint test doc ## Run all checks

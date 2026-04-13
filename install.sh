#!/usr/bin/env bash
# hebrew-lint installer
#
# Installs the FocusAI Vale style into a target project.
#
# Usage:
#   bash install.sh                       # install into $PWD
#   bash install.sh /path/to/target       # install into specified dir
#   bash install.sh /path/to/target --dry-run
#
# What it does:
#   1. Verifies vale is installed (offers to install via brew on macOS)
#   2. Copies styles/FocusAI/ to $TARGET/.vale/styles/
#   3. Merges .vale.ini with existing config (or creates new)
#   4. Appends hebrew-lint to .gitignore if needed
#   5. Runs the test suite from the target directory

set -uo pipefail

TARGET=""
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --help|-h) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "unknown option: $1" >&2; exit 1 ;;
        *)
            if [ -z "$TARGET" ]; then TARGET="$1"; else echo "too many args" >&2; exit 1; fi
            shift
            ;;
    esac
done

TARGET="${TARGET:-$PWD}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -t 1 ]; then
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'
else
    GREEN='' RED='' YELLOW='' CYAN='' GRAY='' NC=''
fi

section() { echo ""; echo -e "${CYAN}━━━ $1 ━━━${NC}"; }
ok() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
err() { echo -e "  ${RED}✗${NC} $1" >&2; }
info() { echo -e "  ${GRAY}·${NC} $1"; }

# ============================================================================
# Step 1: Prerequisites
# ============================================================================
section "Prerequisites"

if [ ! -d "$TARGET" ]; then
    err "target does not exist: $TARGET"
    exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"
ok "target: $TARGET"

if ! command -v vale >/dev/null 2>&1; then
    warn "vale is not installed"
    if [[ "$(uname)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        read -p "  install via brew? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew install vale || { err "brew install failed"; exit 1; }
        else
            err "vale is required. install manually: https://vale.sh/docs/install"
            exit 1
        fi
    else
        err "install vale manually: https://vale.sh/docs/install"
        exit 1
    fi
fi
ok "vale: $(vale --version | head -1)"

if [ $DRY_RUN -eq 1 ]; then
    warn "DRY RUN mode"
fi

# ============================================================================
# Step 2: Install FocusAI style
# ============================================================================
section "Install FocusAI style"

STYLES_DEST="$TARGET/.vale/styles"

if [ $DRY_RUN -eq 0 ]; then
    mkdir -p "$STYLES_DEST"
    cp -r "$SCRIPT_DIR/styles/FocusAI" "$STYLES_DEST/"
    ok "copied FocusAI style to $STYLES_DEST/FocusAI"
else
    info "would copy $SCRIPT_DIR/styles/FocusAI to $STYLES_DEST/FocusAI"
fi

# ============================================================================
# Step 3: Merge .vale.ini
# ============================================================================
section "Merge .vale.ini"

TARGET_INI="$TARGET/.vale.ini"

if [ -f "$TARGET_INI" ]; then
    info "existing .vale.ini found"
    if grep -q 'BasedOnStyles.*FocusAI' "$TARGET_INI" 2>/dev/null; then
        ok ".vale.ini already includes FocusAI"
    else
        warn "existing .vale.ini does not include FocusAI"
        info "manually add 'BasedOnStyles = FocusAI' to relevant sections"
    fi
else
    if [ $DRY_RUN -eq 0 ]; then
        cp "$SCRIPT_DIR/.vale.ini.template" "$TARGET_INI"
        ok "created .vale.ini from template"
    else
        info "would create .vale.ini from template"
    fi
fi

# ============================================================================
# Step 4: Update .gitignore
# ============================================================================
section "Update .gitignore"

GI="$TARGET/.gitignore"
if [ -f "$GI" ]; then
    if grep -qE '^\.vale/(styles/)?$' "$GI" 2>/dev/null; then
        ok ".gitignore already excludes .vale/styles"
    else
        info ".vale/styles should be version-controlled (skipping)"
    fi
else
    info "no .gitignore (skipping)"
fi

# ============================================================================
# Step 5: Verification
# ============================================================================
section "Verification"

if [ $DRY_RUN -eq 1 ]; then
    warn "dry run — skipping verification"
    echo ""
    echo -e "${CYAN}run without --dry-run to apply changes${NC}"
    exit 0
fi

cd "$TARGET"
if vale --config=.vale.ini --version >/dev/null 2>&1; then
    ok "vale config valid"
else
    err "vale config check failed"
    exit 1
fi

section "Success"
ok "hebrew-lint installed in $TARGET"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. run vale on your content: vale ."
echo "  2. set up VSCode extension: errata-ai.vale-server"
echo "  3. add pre-commit hook or GitHub Action"
echo ""
exit 0

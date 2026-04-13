#!/usr/bin/env bash
# hebrew-lint test suite
# Verifies that each file in tests/fail/ produces at least one error,
# and each file in tests/pass/ produces zero errors.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -t 1 ]; then
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    GREEN='' RED='' YELLOW='' CYAN='' NC=''
fi

section() { echo ""; echo -e "${CYAN}━━━ $1 ━━━${NC}"; }
ok() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

if ! command -v vale >/dev/null 2>&1; then
    echo -e "${RED}error:${NC} vale is not installed"
    echo "  install with: brew install vale"
    exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

run_vale() {
    local file="$1"
    (cd "$LINT_DIR" && vale --no-exit --output=line --config=./.vale.ini --minAlertLevel=suggestion "$file" 2>&1)
}

# A "real" lint hit has a line matching: <file>:<line>:<col>:<Rule>:<message>
has_real_hits() {
    echo "$1" | grep -qE ':[0-9]+:[0-9]+:FocusAI\.'
}

# ============================================================================
# Fail fixtures — should produce at least one FocusAI hit
# ============================================================================
section "Fail fixtures (should trigger lint errors)"

while IFS= read -r -d '' file; do
    output=$(run_vale "$file")
    if has_real_hits "$output"; then
        ok "$(basename "$file") — errors raised as expected"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        fail "$(basename "$file") — expected FocusAI hits but none raised"
        echo "$output" | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done < <(find "$SCRIPT_DIR/fail" -name "*.md" -type f -print0 2>/dev/null)

# ============================================================================
# Pass fixtures — should produce NO FocusAI hits
# ============================================================================
section "Pass fixtures (should be clean)"

while IFS= read -r -d '' file; do
    output=$(run_vale "$file")
    if has_real_hits "$output"; then
        fail "$(basename "$file") — unexpected FocusAI hits"
        echo "$output" | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        ok "$(basename "$file") — clean"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
done < <(find "$SCRIPT_DIR/pass" -name "*.md" -type f -print0 2>/dev/null)

# ============================================================================
# Results
# ============================================================================
section "Results"
echo "  passed: $PASS_COUNT"
echo "  failed: $FAIL_COUNT"

if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi
exit 0

#!/usr/bin/env bash
# hebrew-lint — fleet installer
#
# Installs or syncs the FocusAI Vale style across ALL projects that already
# have it, or across all subdirectories of a parent directory.
#
# Usage:
#   bash install-fleet.sh [parent-dir] [options]
#
# Parent dir defaults to ~/Development if not specified.
#
# Options:
#   --dry-run            Show what would happen, do nothing
#   --sync               Default. Only sync projects that already have hebrew-lint installed
#   --missing            Only install in projects that do NOT have hebrew-lint installed
#   --all                Install in every subdirectory (mixed; typically not needed)
#   --force              Skip confirmation prompts
#   --skip NAME,NAME...  Comma-separated project names to skip
#   --extra-dir PATH     Additional directory outside parent to also consider (can be repeated)
#   --help               Show this help
#
# Typical workflows:
#
#   # See which projects have hebrew-lint and whether they're in sync
#   bash install-fleet.sh --dry-run
#
#   # Sync all projects that already have hebrew-lint to the latest rules
#   bash install-fleet.sh --sync --force
#
#   # Add to a project outside ~/Development
#   bash install-fleet.sh --sync --force --extra-dir "/Users/shahar/some-other-project"

set -uo pipefail

# ============================================================================
# Args + constants
# ============================================================================

PARENT_DIR=""
DRY_RUN=0
MODE="sync"
FORCE=0
SKIP_LIST=""
EXTRA_DIRS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --sync) MODE="sync"; shift ;;
        --missing) MODE="missing"; shift ;;
        --all) MODE="all"; shift ;;
        --force) FORCE=1; shift ;;
        --skip) SKIP_LIST="$2"; shift 2 ;;
        --extra-dir) EXTRA_DIRS+=("$2"); shift 2 ;;
        --help|-h)
            sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*)
            echo "unknown option: $1" >&2
            exit 1
            ;;
        *)
            if [ -z "$PARENT_DIR" ]; then
                PARENT_DIR="$1"
            else
                echo "too many positional args" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

PARENT_DIR="${PARENT_DIR:-$HOME/Development}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
STYLES_SOURCE="$SCRIPT_DIR/styles/FocusAI"

if [ ! -d "$PARENT_DIR" ]; then
    echo "parent directory not found: $PARENT_DIR" >&2
    exit 1
fi

if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo "install.sh not found at: $INSTALL_SCRIPT" >&2
    exit 1
fi

if [ ! -d "$STYLES_SOURCE" ]; then
    echo "styles/FocusAI not found at: $STYLES_SOURCE" >&2
    exit 1
fi

if [ -t 1 ]; then
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'
else
    GREEN='' RED='' YELLOW='' CYAN='' GRAY='' NC=''
fi

# ============================================================================
# State detection per project
# ============================================================================

# "installed+synced" = has .vale/styles/FocusAI and all rule files match central
# "installed+outdated" = has .vale/styles/FocusAI but some rules differ
# "none" = no .vale/styles/FocusAI
detect_state() {
    local dir="$1"
    local target="$dir/.vale/styles/FocusAI"
    if [ ! -d "$target" ]; then
        echo "none"
        return
    fi
    # Compare rule yml files only (ignore meta.json, vocabulary which are per-project)
    local out_of_sync=0
    while IFS= read -r -d '' src_rule; do
        local rule_name
        rule_name=$(basename "$src_rule")
        local dst_rule="$target/$rule_name"
        if [ ! -f "$dst_rule" ]; then
            out_of_sync=1
            break
        fi
        if ! cmp -s "$src_rule" "$dst_rule"; then
            out_of_sync=1
            break
        fi
    done < <(find "$STYLES_SOURCE" -maxdepth 1 -name "*.yml" -print0)
    if [ $out_of_sync -eq 1 ]; then
        echo "outdated"
    else
        echo "synced"
    fi
}

should_skip() {
    local name="$1"
    # Always skip the source repo itself
    [ "$name" = "hebrew-lint" ] && return 0
    if [ -n "$SKIP_LIST" ]; then
        case ",$SKIP_LIST," in
            *",$name,"*) return 0 ;;
        esac
    fi
    return 1
}

project_matches_mode() {
    local state="$1"
    case "$MODE" in
        sync)
            # sync: only touch projects that already have hebrew-lint
            [ "$state" = "outdated" ] && return 0
            return 1
            ;;
        missing)
            [ "$state" = "none" ] && return 0
            return 1
            ;;
        all)
            return 0
            ;;
    esac
    return 1
}

# ============================================================================
# Main
# ============================================================================

echo ""
echo -e "${CYAN}━━━ hebrew-lint — Fleet Installer ━━━${NC}"
echo ""
echo -e "  parent:      ${CYAN}$PARENT_DIR${NC}"
echo -e "  mode:        ${CYAN}$MODE${NC}"
echo -e "  dry-run:     ${CYAN}$([ $DRY_RUN -eq 1 ] && echo yes || echo no)${NC}"
echo -e "  install.sh:  ${CYAN}$INSTALL_SCRIPT${NC}"
if [ ${#EXTRA_DIRS[@]} -gt 0 ]; then
    echo -e "  extra dirs:  ${CYAN}${EXTRA_DIRS[*]}${NC}"
fi
if [ -n "$SKIP_LIST" ]; then
    echo -e "  skip list:   ${CYAN}$SKIP_LIST${NC}"
fi
echo ""

# Build list of candidate directories
CANDIDATES=()
for dir in "$PARENT_DIR"/*/; do
    [ -d "$dir" ] || continue
    CANDIDATES+=("${dir%/}")
done
for extra in "${EXTRA_DIRS[@]+"${EXTRA_DIRS[@]}"}"; do
    if [ -d "$extra" ]; then
        CANDIDATES+=("${extra%/}")
    else
        echo -e "  ${YELLOW}!${NC} extra dir does not exist: $extra" >&2
    fi
done

echo -e "${CYAN}━━━ Scan ━━━${NC}"
echo ""
printf "  %-48s %s\n" "PROJECT" "STATE"
printf "  %-48s %s\n" "-------" "-----"

TO_INSTALL=()
TO_SKIP=()
SYNCED_ALREADY=()

for dir in "${CANDIDATES[@]}"; do
    name=$(basename "$dir")

    if should_skip "$name"; then
        TO_SKIP+=("$name")
        continue
    fi

    state=$(detect_state "$dir")

    case "$state" in
        synced)     state_display="${GREEN}synced${NC}" ;;
        outdated)   state_display="${YELLOW}outdated${NC}" ;;
        none)       state_display="${GRAY}none${NC}" ;;
    esac

    printf "  %-48s %b\n" "${name:0:48}" "$state_display"

    if [ "$state" = "synced" ]; then
        SYNCED_ALREADY+=("$name")
        continue
    fi

    if project_matches_mode "$state"; then
        TO_INSTALL+=("$name|$dir")
    fi
done

echo ""
echo -e "  ${GREEN}targets:${NC}            ${#TO_INSTALL[@]} projects"
echo -e "  ${GRAY}already synced:${NC}     ${#SYNCED_ALREADY[@]} projects"
echo -e "  ${GRAY}skipped:${NC}            ${#TO_SKIP[@]} projects"
echo ""

if [ ${#TO_INSTALL[@]} -eq 0 ]; then
    echo -e "${YELLOW}nothing to do.${NC}"
    exit 0
fi

if [ $DRY_RUN -eq 1 ]; then
    echo -e "${CYAN}━━━ Dry run — would install in: ━━━${NC}"
    for entry in "${TO_INSTALL[@]}"; do
        name="${entry%%|*}"
        echo "  - $name"
    done
    echo ""
    echo -e "${YELLOW}dry run — no changes made${NC}"
    exit 0
fi

if [ $FORCE -eq 0 ]; then
    echo -e "${YELLOW}This will install/sync hebrew-lint in ${#TO_INSTALL[@]} projects.${NC}"
    printf "Continue? [y/N] "
    read -r answer
    case "$answer" in
        [yY]|[yY][eE][sS]) ;;
        *)
            echo "aborted"
            exit 0
            ;;
    esac
fi

echo ""
echo -e "${CYAN}━━━ Installing ━━━${NC}"

SUCCESS=0
FAILED=0
FAILED_LIST=()

for entry in "${TO_INSTALL[@]}"; do
    name="${entry%%|*}"
    dir="${entry#*|}"
    echo ""
    echo -e "  ${CYAN}→ $name${NC}"

    if bash "$INSTALL_SCRIPT" "$dir" >/tmp/hebrew-lint-fleet-$$.log 2>&1; then
        echo -e "    ${GREEN}✓ synced${NC}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo -e "    ${RED}✗ failed — log tail below${NC}"
        tail -15 /tmp/hebrew-lint-fleet-$$.log | sed 's/^/      /'
        FAILED=$((FAILED + 1))
        FAILED_LIST+=("$name")
    fi
done
rm -f /tmp/hebrew-lint-fleet-$$.log

echo ""
echo -e "${CYAN}━━━ Summary ━━━${NC}"
echo ""
echo -e "  ${GREEN}success:${NC}  $SUCCESS"
echo -e "  ${RED}failed:${NC}   $FAILED"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed projects:${NC}"
    for n in "${FAILED_LIST[@]}"; do
        echo -e "  ${RED}✗${NC} $n"
    done
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Fleet sync complete. $SUCCESS projects updated.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
exit 0

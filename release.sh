#!/usr/bin/env bash
# ==============================================================================
# Nirakase: release.sh
# Description: Semantic versioning, changelog generator, and Git release helper.
# License: MIT License | Copyright (c) 2026-present rbailon
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

VERSION_FILE="$REPO_DIR/VERSION"
CHANGELOG_FILE="$REPO_DIR/CHANGELOG.md"

usage() {
    cat <<EOF
${PURPLE}========================================================================${NC}
${CYAN}                     Nirakase Release Manager                           ${NC}
${PURPLE}========================================================================${NC}

${YELLOW}Usage:${NC}
  ./release.sh <patch|minor|major|X.Y.Z> [options]

${YELLOW}Arguments:${NC}
  patch              Increment PATCH version (e.g. 2.0.0 -> 2.0.1) for bug fixes
  minor              Increment MINOR version (e.g. 2.0.0 -> 2.1.0) for new features
  major              Increment MAJOR version (e.g. 2.0.0 -> 3.0.0) for breaking changes
  X.Y.Z              Set an explicit version number (e.g. 2.5.0)

${YELLOW}Options:${NC}
  -m, --message TEXT Add a custom summary note to the release & changelog
  -n, --no-push      Create commit and Git tag locally without pushing to GitHub
  -d, --dry-run      Preview the next version and changelog entry without changes
  -y, --yes          Skip interactive confirmation prompt
  -h, --help         Show this help message

${YELLOW}Examples:${NC}
  ./release.sh patch -m "Corregido icono de batería y ajustes en Niri"
  ./release.sh minor
  ./release.sh major --no-push
  ./release.sh patch --dry-run
EOF
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

BUMP_TYPE=""
CUSTOM_MSG=""
DO_PUSH=true
DRY_RUN=false
AUTO_YES=false

while [ $# -gt 0 ]; do
    case "$1" in
        patch|minor|major)
            BUMP_TYPE="$1"
            shift
            ;;
        [0-9]*.[0-9]*.[0-9]*)
            BUMP_TYPE="$1"
            shift
            ;;
        -m|--message)
            CUSTOM_MSG="${2:-}"
            if [ -z "$CUSTOM_MSG" ]; then
                echo -e "${RED}[Error] Option $1 requires a message argument.${NC}"
                exit 1
            fi
            shift 2
            ;;
        -n|--no-push)
            DO_PUSH=false
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}[Error] Unknown argument: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

if [ -z "$BUMP_TYPE" ]; then
    echo -e "${RED}[Error] Please specify a version bump type: patch, minor, major, or X.Y.Z${NC}"
    exit 1
fi

# 1. Read current version
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(tr -d '[:space:]v' < "$VERSION_FILE")
else
    CURRENT_VERSION="0.0.0"
fi

IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "$CURRENT_VERSION"

# 2. Compute new version
case "$BUMP_TYPE" in
    major)
        NEW_VERSION="$((V_MAJOR + 1)).0.0"
        ;;
    minor)
        NEW_VERSION="${V_MAJOR}.$((V_MINOR + 1)).0"
        ;;
    patch)
        NEW_VERSION="${V_MAJOR}.${V_MINOR}.$((V_PATCH + 1))"
        ;;
    *)
        NEW_VERSION="${BUMP_TYPE#v}"
        ;;
esac

TAG_NAME="v${NEW_VERSION}"
RELEASE_DATE=$(date +%Y-%m-%d)

# Verify tag does not already exist
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo -e "${RED}[Error] Git tag '$TAG_NAME' already exists!${NC}"
    exit 1
fi

# 3. Collect changes since last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

ADDED_ITEMS=""
FIXED_ITEMS=""
CHANGED_ITEMS=""
REMOVED_ITEMS=""

if [ -n "$CUSTOM_MSG" ]; then
    # Classify custom message based on bump type
    if [ "$BUMP_TYPE" = "patch" ]; then
        FIXED_ITEMS+="- ${CUSTOM_MSG}"$'\n'
    elif [ "$BUMP_TYPE" = "minor" ]; then
        ADDED_ITEMS+="- ${CUSTOM_MSG}"$'\n'
    else
        CHANGED_ITEMS+="- ${CUSTOM_MSG}"$'\n'
    fi
fi

if [ -n "$LAST_TAG" ]; then
    COMMIT_RANGE="${LAST_TAG}..HEAD"
else
    COMMIT_RANGE="HEAD"
fi

while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    # Skip release commits
    if [[ "$line" =~ ^chore\(release\): ]]; then
        continue
    fi

    if [[ "$line" =~ ^feat(\(.*\))?!?:[[:space:]]*(.*) ]] || [[ "$line" =~ ^\[feat\][[:space:]]*(.*) ]]; then
        msg="${BASH_REMATCH[2]:-${BASH_REMATCH[1]}}"
        ADDED_ITEMS+="- ${msg}"$'\n'
    elif [[ "$line" =~ ^fix(\(.*\))?!?:[[:space:]]*(.*) ]] || [[ "$line" =~ ^\[fix\][[:space:]]*(.*) ]]; then
        msg="${BASH_REMATCH[2]:-${BASH_REMATCH[1]}}"
        FIXED_ITEMS+="- ${msg}"$'\n'
    elif [[ "$line" =~ ^(remove|del|revert)(\(.*\))?!?:[[:space:]]*(.*) ]]; then
        msg="${BASH_REMATCH[3]}"
        REMOVED_ITEMS+="- ${msg}"$'\n'
    else
        clean_msg=$(echo "$line" | sed -E 's/^[a-z]+(\([^)]+\))?!?:[[:space:]]*//')
        CHANGED_ITEMS+="- ${clean_msg}"$'\n'
    fi
done < <(git log "$COMMIT_RANGE" --format="%s" 2>/dev/null || true)

# Fallback if no commits since last tag and no custom message was provided
if [ -z "$ADDED_ITEMS" ] && [ -z "$FIXED_ITEMS" ] && [ -z "$CHANGED_ITEMS" ] && [ -z "$REMOVED_ITEMS" ]; then
    CHANGED_ITEMS="- General system configuration and desktop environment updates."$'\n'
fi

# Build Changelog block
CHANGELOG_ENTRY="## [${NEW_VERSION}] - ${RELEASE_DATE}"$'\n'

if [ -n "$ADDED_ITEMS" ]; then
    CHANGELOG_ENTRY+=$'\n'"### Added"$'\n'"${ADDED_ITEMS}"
fi
if [ -n "$CHANGED_ITEMS" ]; then
    CHANGELOG_ENTRY+=$'\n'"### Changed"$'\n'"${CHANGED_ITEMS}"
fi
if [ -n "$FIXED_ITEMS" ]; then
    CHANGELOG_ENTRY+=$'\n'"### Fixed"$'\n'"${FIXED_ITEMS}"
fi
if [ -n "$REMOVED_ITEMS" ]; then
    CHANGELOG_ENTRY+=$'\n'"### Removed"$'\n'"${REMOVED_ITEMS}"
fi

echo -e "${PURPLE}========================================================================${NC}"
echo -e "${CYAN}                     Nirakase Release Summary                           ${NC}"
echo -e "${PURPLE}========================================================================${NC}"
echo -e "  ${BLUE}Current Version:${NC} v${CURRENT_VERSION}"
echo -e "  ${GREEN}New Version:${NC}     ${TAG_NAME} (${BUMP_TYPE})"
echo -e "  ${BLUE}Push to GitHub:${NC}  ${DO_PUSH}"
echo -e "\n${YELLOW}--- Generated Changelog Entry ---${NC}"
echo "$CHANGELOG_ENTRY"
echo -e "${YELLOW}---------------------------------${NC}\n"

if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}[Dry Run] No files were modified and no Git tags were created.${NC}"
    exit 0
fi

if [ "$AUTO_YES" = false ]; then
    read -rp "$(echo -e "${GREEN}Proceed with release ${TAG_NAME}? [Y/n]: ${NC}")" confirm
    confirm="$(echo "$confirm" | xargs | tr '[:upper:]' '[:lower:]')"
    if [ -n "$confirm" ] && [[ ! "$confirm" =~ ^(y|yes|s|si)$ ]]; then
        echo -e "${RED}Release cancelled.${NC}"
        exit 0
    fi
fi

# 4. Update VERSION file
echo "$NEW_VERSION" > "$VERSION_FILE"
echo -e "  ${GREEN}[✔]${NC} Updated VERSION to ${NEW_VERSION}"

# 5. Update CHANGELOG.md
if [ -f "$CHANGELOG_FILE" ]; then
    awk -v entry="$CHANGELOG_ENTRY" '
        !inserted && /^## \[/ {
            print entry
            inserted=1
        }
        { print }
        END {
            if (!inserted) {
                print ""
                print entry
            }
        }
    ' "$CHANGELOG_FILE" > "${CHANGELOG_FILE}.tmp"
    mv "${CHANGELOG_FILE}.tmp" "$CHANGELOG_FILE"
else
    cat <<EOF > "$CHANGELOG_FILE"
# Changelog

All notable changes to the **Nirakase** project will be documented in this file.

$CHANGELOG_ENTRY
EOF
fi
echo -e "  ${GREEN}[✔]${NC} Updated CHANGELOG.md"

# 6. Stage all changes, commit, and create annotated tag
git add -A

COMMIT_TITLE="chore(release): ${TAG_NAME}"
if [ -n "$CUSTOM_MSG" ]; then
    COMMIT_TITLE="chore(release): ${TAG_NAME} - ${CUSTOM_MSG}"
fi

git commit -m "$COMMIT_TITLE"
echo -e "  ${GREEN}[✔]${NC} Created release commit: ${COMMIT_TITLE}"

TAG_ANNOTATION="Release ${TAG_NAME} (${RELEASE_DATE})"
if [ -n "$CUSTOM_MSG" ]; then
    TAG_ANNOTATION="${TAG_ANNOTATION}: ${CUSTOM_MSG}"
fi

git tag -a "$TAG_NAME" -m "$TAG_ANNOTATION"
echo -e "  ${GREEN}[✔]${NC} Created annotated Git tag: ${TAG_NAME}"

# 7. Push to remote if enabled
if [ "$DO_PUSH" = true ]; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    echo -e "  ${BLUE}[Git]${NC} Pushing branch '${CURRENT_BRANCH}' and tags to origin..."
    git push origin "$CURRENT_BRANCH" --follow-tags
    echo -e "  ${GREEN}[✔]${NC} Successfully pushed ${TAG_NAME} to GitHub!"
else
    echo -e "  ${YELLOW}[i]${NC} Skipped push (--no-push). Run 'git push origin main --follow-tags' when ready."
fi

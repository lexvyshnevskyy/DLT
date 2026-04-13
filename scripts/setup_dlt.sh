#!/bin/bash
# ================================================
# Setup DLT project: clone main repo + all submodules
# Target directory: ~/dlt
# ================================================

set -e  # Exit on any error

TARGET_DIR="$HOME/dlt"
MAIN_REPO="git@github.com:lexvyshnevskyy/DLT_database.git"

echo "=== DLT Setup Script ==="
echo "Target directory: $TARGET_DIR"
echo "Main repository: $MAIN_REPO"
echo

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

cd "$TARGET_DIR"

# 1. Clone or pull the main repository
if [ ! -d ".git" ]; then
    echo "→ Cloning main repository into ~/dlt ..."
    git clone "$MAIN_REPO" .
else
    echo "→ Main repository already exists. Pulling latest changes..."
    git pull --ff-only
fi

# 2. Initialize and update all submodules (including setting the correct branches)
echo
echo "→ Initializing and updating submodules..."

# This is the most reliable way when submodules specify a branch
git submodule update --init --recursive

# Optional but recommended: switch each submodule to its tracked branch and pull latest
echo
echo "→ Checking out 'main' branch and pulling latest in each submodule..."
git submodule foreach --recursive '
    echo "→ Processing submodule: $path"
    git fetch origin
    if git ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
        git checkout main
        git pull --ff-only origin main
    else
        echo "   Warning: main branch not found, staying on current commit"
    fi
'

echo
echo "✅ Done!"
echo "Main project and all submodules are now in ~/dlt"
echo
echo "Submodule paths:"
echo "   src/hmi"
echo "   src/database"
echo "   src/measure_device"
echo "   src/core"
echo
ls -la src/
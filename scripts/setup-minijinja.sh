#!/usr/bin/env bash
# Setup script to download and build minijinja-cabi library  
# Usage: ./scripts/setup-minijinja.sh [--force]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" 
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FORCE_UPDATE=0

MINIJINJA_REPO="https://github.com/mitsuhiko/minijinja.git" 
MINIJINJA_CLONE="$PROJECT_ROOT/minijinja"
CABI_SRC="$MINIJINJA_CLONE/minijinja-cabi"
LIB_PATH="$MINIJINJA_CLONE/target/release/libminijinja_cabi.so"

echo "=== MiniJinja Perl XS - Setup Script ==="
echo ""

# Check for required tools
command -v git >/dev/null 2>&1 || { echo "ERROR: git is not installed"; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "ERROR: cargo (Rust) is not installed. Visit https://rustup.rs/"; exit 1; }  

# Clone or update the minijinja repository  
if [ "$FORCE_UPDATE" -eq 1 ] || [ ! -d "$MINIJINJA_CLONE/.git" ]; then
    if [ -d "$MINIJINJA_CLONE/.git" ]; then
        echo "[UPDATE] Fetching latest changes..."
        cd "$MINIJINJA_CLONE"  
        git fetch origin --tags --force
        git reset --hard origin/main
    else
        echo "[CLONE] Cloning minijinja repository..."
        git clone --depth=1 "$MINIJINJA_REPO" "$MINIJINJA_CLONE" 
    fi
fi

# Build minijinja-cabi library 
echo "[BUILD] Building minijinja-cabi..."
cd "$CABI_SRC" 
cargo build --release

if [ ! -f "$LIB_PATH" ]; then
    echo "ERROR: Failed to build libminijinja_cabi.so"
    echo "Expected at: $LIB_PATH"
    exit 1
fi  

HEADER_DIR="$CABI_SRC/include"

echo ""
echo "=== Setup Complete ==="
echo "Library: $LIB_PATH" 
echo "Headers: $HEADER_DIR/"  
echo ""
echo "You can now build the Perl module with:"
echo "  export MINIJINJA_BUILD=\$(pwd)/../target/release"
echo "  export MINIJINJA_SRC=\$(pwd)/.."
echo "  cd ../perl-minijinja-xs.git"
echo "  perl Makefile.PL && make && make test"

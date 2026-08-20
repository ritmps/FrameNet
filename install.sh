#!/usr/bin/env bash
# ==============================================================================
# FrameNet Setup & Installation Script
# Supports Linux and macOS
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for terminal output
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

info() {
    echo -e "${BLUE}${BOLD}[INFO]${RESET} $1"
}

success() {
    echo -e "${GREEN}${BOLD}[SUCCESS]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}${BOLD}[WARNING]${RESET} $1"
}

error() {
    echo -e "${RED}${BOLD}[ERROR]${RESET} $1"
}

show_help() {
    cat << EOF
FrameNet Installer

Usage:
    ./install.sh [OPTIONS]

Options:
    -h, --help              Show this help message
    --check                 Run diagnostic check on existing environment without reinstalling
    --no-cuda               Force CPU-only PyTorch install on Linux
    --paclet                Register the Wolfram Paclet directory
    --build-paclet          Build a standalone .paclet archive (via build_paclet.wl)
    --clean                 Remove existing .venv before installing

Examples:
    ./install.sh            # Standard installation (auto-detects uv / python / CUDA / MPS)
    ./install.sh --check    # Check existing installation
EOF
}

CHECK_ONLY=false
FORCE_CPU=false
CLEAN_INSTALL=false
REGISTER_PACLET=false
BUILD_PACLET=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --no-cuda)
            FORCE_CPU=true
            shift
            ;;
        --clean)
            CLEAN_INSTALL=true
            shift
            ;;
        --paclet)
            REGISTER_PACLET=true
            shift
            ;;
        --build-paclet)
            BUILD_PACLET=true
            shift
            ;;
        *)
            warn "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo -e "${BOLD}======================================================${RESET}"
echo -e "${BOLD}              FrameNet Package Installer             ${RESET}"
echo -e "${BOLD}======================================================${RESET}"

# Clean install if requested
if [ "$CLEAN_INSTALL" = true ] && [ -d ".venv" ]; then
    info "Removing existing .venv as requested by --clean..."
    rm -rf .venv
fi

# 1. Check Only Mode
if [ "$CHECK_ONLY" = true ]; then
    info "Running diagnostic check..."
    PYTHON_EXEC=""
    if [ -f ".venv/bin/python" ]; then
        PYTHON_EXEC=".venv/bin/python"
    elif [ -f ".venv/Scripts/python.exe" ]; then
        PYTHON_EXEC=".venv/Scripts/python.exe"
    elif command -v python3 &>/dev/null; then
        PYTHON_EXEC="$(command -v python3)"
    fi

    if [ -n "$PYTHON_EXEC" ]; then
        info "Using Python: $PYTHON_EXEC"
        "$PYTHON_EXEC" -c "
import sys
print(f'Python Version: {sys.version}')
try:
    import torch
    print(f'PyTorch Version: {torch.__version__}')
    print(f'CUDA Available: {torch.cuda.is_available()}')
    if torch.cuda.is_available():
        print(f'CUDA Device: {torch.cuda.get_device_name(0)}')
    if hasattr(torch.backends, 'mps'):
        print(f'MPS Available: {torch.backends.mps.is_available()}')
except ImportError:
    print('PyTorch: NOT INSTALLED')

try:
    import wolframclient
    print('WolframClient: INSTALLED')
except ImportError:
    print('WolframClient: NOT INSTALLED')
"
        success "Diagnostic check complete."
        exit 0
    else
        error "No Python executable found to check."
        exit 1
    fi
fi

# 2. Environment Setup (uv or standard python3 venv)
OS_TYPE="$(uname -s)"
info "Detected OS: $OS_TYPE"

HAS_NVIDIA=false
if [ "$OS_TYPE" = "Linux" ] && [ "$FORCE_CPU" = false ]; then
    if command -v nvidia-smi &>/dev/null; then
        if nvidia-smi &>/dev/null; then
            HAS_NVIDIA=true
            info "NVIDIA GPU detected via nvidia-smi."
        fi
    fi
fi

if command -v uv &>/dev/null; then
    info "Found 'uv' package manager. Using uv for fast installation..."
    if [ "$HAS_NVIDIA" = true ]; then
        info "Syncing dependencies with CUDA support..."
    fi
    uv sync
    success "Virtual environment (.venv) successfully created/synced with uv."
else
    info "'uv' not found. Falling back to standard python3 venv..."
    if ! command -v python3 &>/dev/null; then
        error "python3 is not installed or not in PATH. Please install Python 3.11."
        exit 1
    fi

    PY_VER="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
    info "Detected Python version: $PY_VER"

    if [ ! -d ".venv" ]; then
        info "Creating virtual environment in .venv..."
        python3 -m venv .venv
    fi

    VENV_PIP=".venv/bin/pip"
    VENV_PY=".venv/bin/python"

    info "Upgrading pip, setuptools, wheel..."
    "$VENV_PIP" install --upgrade pip setuptools wheel

    if [ "$HAS_NVIDIA" = true ]; then
        info "Installing PyTorch with CUDA 12.6 support..."
        "$VENV_PIP" install torch torchvision --index-url https://download.pytorch.org/whl/cu126
    else
        info "Installing standard PyTorch..."
        "$VENV_PIP" install torch torchvision
    fi

    info "Installing project dependencies..."
    "$VENV_PIP" install numpy scipy scikit-image opencv-python tensorboardx pillow pyzmq wolframclient openexr
    success "Virtual environment (.venv) successfully configured."
fi

# 3. Verify Installation
info "Verifying PyTorch and bridge setup..."
VENV_PY=".venv/bin/python"
if [ ! -f "$VENV_PY" ] && [ -f ".venv/Scripts/python.exe" ]; then
    VENV_PY=".venv/Scripts/python.exe"
fi

if [ -f "$VENV_PY" ]; then
    "$VENV_PY" -c "
import torch, torchvision, numpy, PIL
print(' PyTorch:', torch.__version__)
if torch.cuda.is_available():
    print(' Hardware Acceleration: CUDA (', torch.cuda.get_device_name(0), ')')
elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
    print(' Hardware Acceleration: Apple Silicon MPS')
else:
    print(' Hardware Acceleration: CPU')
"
fi

# 4. Paclet Handling / Optional Registration & Build
if command -v wolframscript &>/dev/null; then
    info "Found wolframscript."
    if [ "$REGISTER_PACLET" = true ]; then
        info "Registering Paclet directory with Wolfram Language..."
        wolframscript -code 'PacletDirectoryLoad["'$SCRIPT_DIR'"]; Print["Paclet loaded: ", PacletObject["FrameNet"]];'
    fi
    if [ "$BUILD_PACLET" = true ]; then
        info "Building standalone .paclet archive..."
        wolframscript -file "$SCRIPT_DIR/build_paclet.wl"
    fi
else
    if [ "$REGISTER_PACLET" = true ] || [ "$BUILD_PACLET" = true ]; then
        warn "wolframscript not found; skipping Paclet registration/build."
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}======================================================${RESET}"
echo -e "${GREEN}${BOLD}            FrameNet is Ready to Use!                ${RESET}"
echo -e "${GREEN}${BOLD}======================================================${RESET}"
echo ""
echo -e "To use in ${BOLD}Wolfram Language / Mathematica${RESET}:"
echo ""
echo -e "  ${BOLD}Method 1 (Paclet Directory Load - Recommended):${RESET}"
echo -e "    PacletDirectoryLoad[\"$SCRIPT_DIR\"];"
echo -e "    Needs[\"FrameNet\`\"];"
echo -e "    FrameNetDoctor[] (* Verify environment *)"
echo ""
echo -e "  ${BOLD}Method 2 (Direct File Get):${RESET}"
echo -e "    Get[\"$SCRIPT_DIR/FrameNet.wl\"];"
echo ""
echo -e "  ${BOLD}Method 3 (Permanent Paclet Install):${RESET}"
echo -e "    PacletInstall[\"$SCRIPT_DIR\"];"
echo -e "    Needs[\"FrameNet\`\"];"
echo ""

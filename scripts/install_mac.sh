#!/usr/bin/env bash

set -e

# check prerequisites
command -v conda >/dev/null 2>&1 || { echo >&2 "conda not found. Please install Miniconda from https://docs.conda.io/en/latest/miniconda.html"; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "git not found. Please install Git (e.g. xcode-select --install or brew install git)."; exit 1; }

source scripts/settings.sh

source $(conda info --base)/etc/profile.d/conda.sh

CLIENT_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --client-only)
            CLIENT_ONLY=1
            ;;
    esac
done

# Use Python 3.9 (widely compatible with Apple Silicon and Intel)
conda create -y -n $CONDA_ENV_NAME python=3.9
conda activate $CONDA_ENV_NAME

if [[ $CLIENT_ONLY == 1 ]]; then
    echo "--- Installing client-only dependencies ---"
    pip install -r requirements_client.txt
else
    echo "--- Installing full local mode dependencies ---"

    # Detect Apple Silicon vs Intel
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        echo "Detected Apple Silicon (arm64). PyTorch will use MPS backend for GPU acceleration."
    else
        echo "Detected Intel Mac. PyTorch will run on CPU."
    fi

    # Install PyTorch (pip handles platform detection automatically)
    pip install torch torchvision

    # Clone First Order Motion Model
    if [ ! -d "fomm" ]; then
        git clone https://github.com/alievk/first-order-model.git fomm
    else
        echo "fomm directory already exists, skipping clone."
    fi

    # Install main requirements (includes face-alignment, opencv, etc.)
    pip install -r requirements.txt

    # Download model weights if not present
    if [ ! -f "vox-adv-cpk.pth.tar" ]; then
        echo "--- Downloading model weights ---"
        bash scripts/download_data.sh
    else
        echo "Model weights already present, skipping download."
    fi
fi

echo ""
echo "=== Installation complete ==="
if [[ $CLIENT_ONLY == 1 ]]; then
    echo "Client-only mode installed. Use run_mac.sh --is-client to connect to a remote GPU server."
else
    echo "Full local mode installed. Use run_mac.sh to run locally."
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        echo "Apple Silicon detected: MPS GPU acceleration will be used automatically."
    else
        echo "Intel Mac detected: running on CPU. For better performance, consider using --is-client with a remote GPU."
    fi
fi

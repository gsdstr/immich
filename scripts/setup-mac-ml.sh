#!/usr/bin/env bash
set -euo pipefail

# Setup script for native high-performance immich-machine-learning on macOS with Apple Silicon

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ML_DIR="$SCRIPT_DIR/../machine-learning"

echo "Setting up Python environment for native ML on macOS..."
cd "$ML_DIR"

if [ ! -d ".venv" ]; then
  python3 -m venv .venv
  echo "Virtual environment created at $ML_DIR/.venv"
fi

source .venv/bin/activate
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Ensure PyTorch supports Apple Silicon Metal Performance Shaders (MPS)
pip install torch torchvision

echo "=========================================================="
echo "Setup complete! To run the ML server natively:"
echo "  cd machine-learning"
echo "  source .venv/bin/activate"
echo "  uvicorn app.main:app --host 0.0.0.0 --port 3003 --reload"
echo "=========================================================="

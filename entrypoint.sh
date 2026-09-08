#!/usr/bin/env bash
set -e
cd /data/ComfyUI

# Custom nodes live on a volume so Manager installs persist. Seed it on first run.
if [ -z "$(ls -A custom_nodes 2>/dev/null)" ]; then
  echo "[entrypoint] seeding custom_nodes volume"
  cp -r /data/ComfyUI/.custom_nodes_seed/. custom_nodes/ 2>/dev/null || true
fi

echo "[entrypoint] GPU: $(python -c 'import torch;print(torch.cuda.get_device_name(0), torch.cuda.get_device_capability(0))')"
exec python main.py ${COMFY_ARGS}

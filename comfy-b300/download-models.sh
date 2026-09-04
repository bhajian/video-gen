#!/usr/bin/env bash
# Run on the host after `docker compose up -d`. Pulls full-precision weights (B300 has 288GB, skip quants).
set -e
DL="docker compose exec comfyui hf download"
M=/data/ComfyUI/models

# Wan 2.2 (T2V/I2V A14B, high+low noise, text encoder, VAE)
$DL Comfy-Org/Wan_2.2_ComfyUI_Repackaged --local-dir $M \
  --include "split_files/diffusion_models/wan2.2_i2v_*14B*fp16*" \
            "split_files/diffusion_models/wan2.2_t2v_*14B*fp16*" \
            "split_files/text_encoders/*" "split_files/vae/*"

# Wan-S2V and InfiniteTalk (audio-driven avatar) via Kijai's repack
$DL Kijai/WanVideo_comfy --local-dir $M/diffusion_models --include "*S2V*" "*InfiniteTalk*"
$DL Kijai/wav2vec2_safetensors --local-dir $M/wav2vec2

# LTX-2.5 (native audio+video)
$DL Lightricks/LTX-2.5 --local-dir $M/checkpoints --include "*.safetensors"

# HunyuanVideo 1.5 (optional)
# $DL Comfy-Org/HunyuanVideo_1.5_repackaged --local-dir $M

# Flatten Comfy-Org split_files/ layout into ComfyUI folders
docker compose exec comfyui bash -c "cd $M && [ -d split_files ] && cp -rn split_files/* . && rm -rf split_files || true"
echo "done. Restart comfyui to pick up new models: docker compose restart comfyui"

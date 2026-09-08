#!/usr/bin/env bash
# Run on the host after `docker compose up -d`. Pulls full-precision weights (B300 has 288GB, skip quants).
set -e
DL="docker compose exec comfyui hf download"
M=/data/ComfyUI/models

# Wan 2.2 (T2V/I2V/S2V A14B, high+low noise, text encoder, VAE, wav2vec2 audio encoder)
# hf >= 1.0 takes one pattern per --include; extra tokens become literal filenames.
# S2V + its audio encoder feed ComfyUI's built-in "Wan 2.2 S2V" template.
$DL Comfy-Org/Wan_2.2_ComfyUI_Repackaged --local-dir $M \
  --include "split_files/diffusion_models/wan2.2_i2v_*14B*fp16*" \
  --include "split_files/diffusion_models/wan2.2_t2v_*14B*fp16*" \
  --include "split_files/diffusion_models/wan2.2_s2v_14B_bf16*" \
  --include "split_files/audio_encoders/*" \
  --include "split_files/text_encoders/*" \
  --include "split_files/vae/*" \
  --include "split_files/loras/wan2.2_*lightx2v*"

# Expose the Comfy-Org split_files/ layout in ComfyUI's folders via relative symlinks.
# Files stay where hf put them, so re-runs skip them instead of re-downloading 167GB;
# ComfyUI's model scan follows symlinks. Done right away so a failure in a later
# (gated) download can't leave the Wan models where ComfyUI won't look.
docker compose exec comfyui bash -c '
  cd '"$M"' && [ -d split_files ] || exit 0
  for d in split_files/*/; do
    t=$(basename "$d"); mkdir -p "$t"
    for f in "$d"*; do
      b=$(basename "$f")
      # never replace a real file the user put there; refresh symlinks freely
      if [ -e "$t/$b" ] && [ ! -L "$t/$b" ]; then continue; fi
      ln -sfn "../$f" "$t/$b"
    done
  done'

# InfiniteTalk (audio-driven avatar) via Kijai's repack, for the WanVideoWrapper workflows.
# (Kijai's repo has no Wan 2.2 S2V; its only *S2V* file is an experimental Kaleido model.)
$DL Kijai/WanVideo_comfy --local-dir $M/diffusion_models --include "*InfiniteTalk*"
$DL Kijai/wav2vec2_safetensors --local-dir $M/wav2vec2

# LTX-2.5 (native audio+video). Repo already uses ComfyUI's models/ layout
# (diffusion_models/, text_encoders/, vae/, loras/, ...), so land it in $M directly.
# Skip the int8/nvfp4 quants (~77GB); we run bf16.
# Gated (auto-approve): click "Agree and access repository" once, logged in as the
# HF_TOKEN account, at https://huggingface.co/Lightricks/LTX-2.5 - then re-run.
# Don't let a missing agreement abort the rest of the script.
$DL Lightricks/LTX-2.5 --local-dir $M --include "*.safetensors" \
  --exclude "*int8*" --exclude "*nvfp4*" \
  || echo "[warn] LTX-2.5 skipped (access not yet approved); everything else is in place."

# HunyuanVideo 1.5 (optional)
# $DL Comfy-Org/HunyuanVideo_1.5_repackaged --local-dir $M

echo "done. Restart comfyui to pick up new models: docker compose restart comfyui"

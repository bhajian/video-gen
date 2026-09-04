# ComfyUI on B300 (docker compose)

## Host prerequisites
- NVIDIA driver 580+ (`nvidia-smi` shows CUDA 13.x)
- Docker 24+ and NVIDIA Container Toolkit:
  `sudo apt install nvidia-container-toolkit && sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker`
- `docker login nvcr.io` (free NGC account) to pull the base image

## Bring up
```bash
cp .env.example .env            # add HF_TOKEN if you need gated repos
mkdir -p data/{models,input,output,custom_nodes,user,hf-cache}
docker compose build            # ~10 min, builds SageAttention for sm_103
docker compose up -d comfyui
docker compose logs -f comfyui  # wait for "GPU: NVIDIA B300 (10, 3)" and "To see the GUI go to"
./download-models.sh            # ~150GB, run once
docker compose restart comfyui
docker compose up -d tts        # optional Chatterbox UI on :7860
```

## Access
SSH tunnel from your laptop, do not expose 8188 publicly (no auth):
```bash
ssh -N -L 8188:localhost:8188 -L 7860:localhost:7860 user@<vm-ip>
```
ComfyUI: http://localhost:8188  TTS: http://localhost:7860

## First workflows
- In ComfyUI: Workflow > Browse Templates > Video > Wan 2.2 I2V. Drop a studio still into `data/input`.
- Avatar: load `custom_nodes/ComfyUI-WanVideoWrapper/example_workflows/wanvideo_S2V_*.json`,
  point the audio loader at a WAV from the TTS service (already in `data/input`).
- Video-to-video restyle: `..._VACE_*.json` in the same folder.
- LTX-2.5: `custom_nodes/ComfyUI-LTXVideo/example_workflows/`.

## Notes
- custom_nodes is a volume so Manager installs persist across image rebuilds.
- If SageAttention fails to import, drop `--use-sage-attention` from COMFY_ARGS in compose; ~30% slower, still fine.
- Do not use GGUF/fp8 quants; run bf16/fp16 for quality, VRAM is not a constraint here.
- Update: `docker compose build --pull && docker compose up -d`
# video-gen

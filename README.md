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
- Avatar (speech-to-video): Workflow > Browse Templates > Video > Wan 2.2 S2V,
  point the audio loader at a WAV from the TTS service (already in `data/input`).
- Avatar (InfiniteTalk): `custom_nodes/ComfyUI-WanVideoWrapper/example_workflows/*InfiniteTalk*.json`.
  These also expect Kijai-format Wan 2.1 I2V weights, `clip_vision_h`, and the Lightx2v LoRA,
  which `download-models.sh` does not fetch; grab them from `Kijai/WanVideo_comfy` as needed.
- Video-to-video restyle: `..._VACE_*.json` in the same folder.
- LTX-2.5: `custom_nodes/ComfyUI-LTXVideo/example_workflows/`.

## Notes
- The image preserves NVIDIA's PyTorch and TorchVision versions, builds TorchAudio
  2.8.0 against that PyTorch, and pins NumPy to 1.26.4 and OpenCV below 4.12.
  These constraints prevent the `undefined symbol: torch_library_impl` startup
  crash and the NumPy 1.x/2.x ABI error. TorchAudio uses the SoundFile backend for
  audio I/O; its optional SoX, FFmpeg, and CUDA CTC decoder extensions are disabled.
- After updating the Dockerfile, run `docker compose build comfyui`, then
  `docker compose up -d --no-deps --force-recreate comfyui`. The build checks imports,
  NumPy conversion, resampling, and WAV reading/writing before producing the image.
  A custom node with incompatible dependency requirements now fails the build
  instead of silently ignoring the installation error.
- custom_nodes is a volume so Manager installs persist across image rebuilds.
- If SageAttention fails to import, drop `--use-sage-attention` from COMFY_ARGS in compose; ~30% slower, still fine.
- Do not use GGUF/fp8 quants; run bf16/fp16 for quality, VRAM is not a constraint here.
- Update: `docker compose build --pull && docker compose up -d`
# video-gen

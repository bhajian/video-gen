# syntax=docker/dockerfile:1
# Blackwell-ready ComfyUI. Base image ships PyTorch + CUDA 13 with sm_100/sm_103 kernels.
FROM nvcr.io/nvidia/pytorch:25.08-py3

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PIP_CONSTRAINT=/etc/pip/constraint.txt \
    TORCH_CUDA_ARCH_LIST="10.0;10.3" \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      git ffmpeg libgl1 libglib2.0-0 aria2 libsndfile1 \
      build-essential cmake ninja-build pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Preserve NVIDIA's other constraints, and protect the installed torch stack.
# NumPy 2 and newer OpenCV wheels are incompatible with this base's NumPy ABI.
RUN python - <<'PY'
from importlib.metadata import version
from pathlib import Path
import re

constraints = Path('/etc/pip/constraint.txt')
pins = {
    'torch': f'torch=={version("torch")}',
    'torchvision': f'torchvision=={version("torchvision")}',
    'torchaudio': 'torchaudio==2.8.0',
    'numpy': 'numpy==1.26.4',
    'opencv-python': 'opencv-python<4.12',
    'opencv-python-headless': 'opencv-python-headless<4.12',
    'opencv-contrib-python': 'opencv-contrib-python<4.12',
    'opencv-contrib-python-headless': 'opencv-contrib-python-headless<4.12',
}
lines = constraints.read_text().splitlines() if constraints.exists() else []
kept = []
for line in lines:
    match = re.match(r'\s*([A-Za-z0-9_.-]+)', line)
    name = re.sub(r'[-_.]+', '-', match[1]).lower() if match else None
    if name not in pins:
        kept.append(line)
constraints.parent.mkdir(parents=True, exist_ok=True)
constraints.write_text('\n'.join(kept + list(pins.values())) + '\n')
PY

# PyPI TorchAudio binaries do not match NVIDIA's custom PyTorch ABI.
# Build against the installed torch, without pip replacing it or isolating it.
# Use SoundFile for audio I/O; leave out optional SoX/FFmpeg/CTC extensions.
RUN python -m pip install 'numpy==1.26.4' soundfile && \
    git clone --branch v2.8.0 --depth 1 --recurse-submodules \
      https://github.com/pytorch/audio.git /tmp/torchaudio && \
    BUILD_VERSION=2.8.0 \
    PYTORCH_VERSION="$(python -c 'from importlib.metadata import version; print(version("torch"))')" \
    USE_CUDA=1 BUILD_SOX=0 USE_FFMPEG=0 BUILD_CUDA_CTC_DECODER=0 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
      python -m pip install --no-build-isolation --no-deps --force-reinstall /tmp/torchaudio && \
    rm -rf /tmp/torchaudio

WORKDIR /data
RUN git clone https://github.com/comfyanonymous/ComfyUI /data/ComfyUI

WORKDIR /data/ComfyUI
RUN pip install -r requirements.txt && \
    pip install "huggingface_hub[cli]" opencv-python-headless imageio-ffmpeg && \
    # SageAttention: try the wheel, fall back to source build for sm_103
    (pip install sageattention || \
     pip install git+https://github.com/thu-ml/SageAttention.git)

# Baseline custom nodes; the manager handles the rest from the UI
RUN cd custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager && \
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper && \
    git clone https://github.com/kijai/ComfyUI-KJNodes && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite && \
    git clone https://github.com/Lightricks/ComfyUI-LTXVideo && \
    for d in */; do \
      if [ -f "$d/requirements.txt" ]; then \
        python -m pip install -r "$d/requirements.txt" || exit 1; \
      fi; \
    done && \
    # keep a copy; the runtime custom_nodes dir is a volume and gets seeded from this on first start
    cp -r /data/ComfyUI/custom_nodes /data/ComfyUI/.custom_nodes_seed

# Catch binary incompatibilities during the build, without requiring a GPU.
RUN python - <<'PY'
import tempfile
import numpy as np
import torch
import torchaudio
import torchvision

wave = torch.from_numpy(np.zeros((1, 1600), dtype=np.float32))
assert wave.numpy().shape == (1, 1600)
assert torchaudio.functional.resample(wave, 16000, 8000).shape == (1, 800)
with tempfile.TemporaryDirectory() as directory:
    filename = f'{directory}/smoke.wav'
    torchaudio.save(filename, wave, 16000, backend='soundfile')
    loaded, sample_rate = torchaudio.load(filename, backend='soundfile')
    assert sample_rate == 16000 and loaded.shape == wave.shape
print(f'Audio smoke check passed: torch={torch.__version__}, torchaudio={torchaudio.__version__}, numpy={np.__version__}')
PY

COPY tts_ui.py /opt/tts_ui.py
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

EXPOSE 8188
ENTRYPOINT ["/opt/entrypoint.sh"]

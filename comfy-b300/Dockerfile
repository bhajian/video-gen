# Blackwell-ready ComfyUI. Base image ships PyTorch + CUDA 13 with sm_100/sm_103 kernels.
FROM nvcr.io/nvidia/pytorch:25.08-py3

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    TORCH_CUDA_ARCH_LIST="10.0;10.3" \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      git ffmpeg libgl1 libglib2.0-0 aria2 && \
    rm -rf /var/lib/apt/lists/*

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
    for d in */; do [ -f "$d/requirements.txt" ] && pip install -r "$d/requirements.txt" || true; done && \
    # keep a copy; the runtime custom_nodes dir is a volume and gets seeded from this on first start
    cp -r /data/ComfyUI/custom_nodes /data/ComfyUI/.custom_nodes_seed

COPY tts_ui.py /opt/tts_ui.py
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

EXPOSE 8188
ENTRYPOINT ["/opt/entrypoint.sh"]

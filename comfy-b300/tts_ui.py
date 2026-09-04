# Minimal Chatterbox voice-clone UI. Writes WAVs into /data/audio-out (mounted as ComfyUI/input).
import torch, torchaudio, gradio as gr, time, os
from chatterbox.tts import ChatterboxTTS

model = ChatterboxTTS.from_pretrained(device="cuda")
OUT = "/data/audio-out"

def speak(text, ref_wav, exaggeration, cfg):
    wav = model.generate(text, audio_prompt_path=ref_wav, exaggeration=exaggeration, cfg_weight=cfg)
    path = os.path.join(OUT, f"tts_{int(time.time())}.wav")
    torchaudio.save(path, wav, model.sr)
    return path

gr.Interface(
    fn=speak,
    inputs=[gr.Textbox(lines=6, label="Script"),
            gr.Audio(type="filepath", label="Reference voice (5-15s WAV)"),
            gr.Slider(0.2, 1.2, 0.5, label="Exaggeration"),
            gr.Slider(0.2, 1.0, 0.5, label="CFG weight")],
    outputs=gr.Audio(type="filepath"),
    title="Chatterbox TTS",
).launch(server_name="0.0.0.0", server_port=7860)

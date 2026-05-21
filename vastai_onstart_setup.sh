#!/bin/bash
# ============================================================
# VAST.ai LTX 2.3 Onstart Setup Script
# ----------------------------------------------------------
# 인스턴스 시작 시 자동 실행. 
# 커스텀 노드 설치 → 모델 다운로드 → ComfyUI 재시작
# 모든 출력은 /workspace/setup.log 에 기록
# 완료 시 /workspace/setup_done.flag 생성
#
# 사용법 (vastai CLI):
#   vastai create instance <OFFER_ID> --template_hash <HASH> \
#     --disk 100 --direct \
#     --onstart-cmd "curl -s https://raw.githubusercontent.com/<REPO>/<PATH>/vastai_onstart_setup.sh | bash"
# ============================================================
exec > /workspace/setup.log 2>&1
set -e

echo "SETUP_START $(date)"
COMFY="/workspace/ComfyUI"
VENV="/venv/main/bin/activate"

# ── Step 0: ComfyUI update for LTX audio nodes ──
echo "=== COMFY UPDATE ==="
cd $COMFY
wget -q -c 'https://raw.githubusercontent.com/Comfy-Org/ComfyUI/master/comfy_extras/nodes_lt_audio.py' -O comfy_extras/nodes_lt_audio.py
echo "COMFY_UPDATED"

# ── Step 1: Git clone custom nodes ──
echo "=== NODES ==="
mkdir -p $COMFY/custom_nodes
cd $COMFY/custom_nodes

git clone --depth 1 https://github.com/city96/ComfyUI-GGUF &
git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes &
git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite &
git clone --depth 1 https://github.com/evanspearman/ComfyMath &
git clone --depth 1 https://github.com/Lightricks/ComfyUI-LTXVideo &
git clone --depth 1 https://github.com/GACLove/ComfyUI-VFI &
git clone --depth 1 https://github.com/rgthree/rgthree-comfy &
git clone --depth 1 https://github.com/LAOGOU-666/Comfyui-Memory_Cleanup &
git clone --depth 1 https://github.com/NVIDIAGameWorks/ComfyUI-RTX-Nodes &
wait
echo "NODES_CLONE_DONE"

# ── Step 2: deno-custom-nodes ──
echo "=== DENO NODES ==="
wget -q -c 'https://raw.githubusercontent.com/mijung2323081-a11y/vastai-ltx23-assets/main/deno-custom-nodes-local.zip' \
  -O /workspace/deno-custom-nodes-local.zip
mkdir -p $COMFY/custom_nodes/deno-custom-nodes
unzip -q -o /workspace/deno-custom-nodes-local.zip -d $COMFY/custom_nodes/deno-custom-nodes
echo "NODES_DONE"

# ── Step 3: Pip install ──
echo "=== PIP ==="
source $VENV
pip install --quiet gguf opencv-python-headless numpy 2>&1 | tail -5

for req_dir in \
    $COMFY/custom_nodes/ComfyUI-VideoHelperSuite \
    $COMFY/custom_nodes/ComfyUI-KJNodes \
    $COMFY/custom_nodes/ComfyUI-LTXVideo \
    $COMFY/custom_nodes/ComfyUI-RTX-Nodes; do
    if [ -f "$req_dir/requirements.txt" ]; then
        pip install --quiet -r "$req_dir/requirements.txt" 2>&1 | tail -2
    fi
done
echo "PIP_DONE"

# ── Step 4: LTX 2.3 Model download (HuggingFace, parallel) ──
echo "=== MODELS ==="
cd $COMFY/models
mkdir -p unet text_encoders vae latent_upscale_models

wget -q --show-progress -c \
  'https://huggingface.co/QuantStack/LTX-2.3-GGUF/resolve/main/LTX-2.3-distilled-1.1/LTX-2.3-22B-distilled-1.1-Q4_K_M.gguf?download=true' \
  -O unet/LTX-2.3-22B-distilled-1.1-Q4_K_M.gguf &

wget -q --show-progress -c \
  'https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors?download=true' \
  -O text_encoders/gemma_3_12B_it_fp4_mixed.safetensors &

wget -q --show-progress -c \
  'https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/text_encoders/ltx-2.3_text_projection_bf16.safetensors?download=true' \
  -O text_encoders/ltx-2.3_text_projection_bf16.safetensors &

wget -q --show-progress -c \
  'https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_video_vae_bf16.safetensors?download=true' \
  -O vae/LTX23_video_vae_bf16.safetensors &

wget -q --show-progress -c \
  'https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_audio_vae_bf16.safetensors?download=true' \
  -O vae/LTX23_audio_vae_bf16.safetensors &

wget -q --show-progress -c \
  'https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-spatial-upscaler-x2-1.1.safetensors?download=true' \
  -O latent_upscale_models/ltx-2.3-spatial-upscaler-x2-1.1.safetensors &

wait
echo "MODELS_DONE"

# ── Step 5: RIFE flownet.pkl ──
echo "=== RIFE ==="
mkdir -p $COMFY/custom_nodes/ComfyUI-VFI/rife/train_log
cd /tmp
wget -q -c 'https://huggingface.co/hzwer/RIFE/resolve/main/RIFEv4.26_0921.zip' -O rife.zip
unzip -q -o rife.zip -d rife_extract
find rife_extract -name 'flownet.pkl' -exec cp {} $COMFY/custom_nodes/ComfyUI-VFI/rife/train_log/flownet.pkl \;
rm -rf rife.zip rife_extract
echo "RIFE_DONE"

# ── Step 6: Restart ComfyUI ──
echo "=== RESTART ==="
supervisorctl restart comfyui
sleep 30
echo "SETUP_COMPLETE $(date)" > /workspace/setup_done.flag
echo "ALL_DONE $(date)"

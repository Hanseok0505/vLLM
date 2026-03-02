#!/bin/bash
# vLLM Docker 실행 스크립트
# 사용법: ./run.sh [모델명]
# 예: ./run.sh Qwen/Qwen2.5-0.5B-Instruct

set -e

MODEL="${1:-Qwen/Qwen2.5-0.5B-Instruct}"
IMAGE_NAME="${VLLM_IMAGE:-vllm/vllm-ubuntu22:latest}"
HF_CACHE="${HF_CACHE:-$HOME/.cache/huggingface}"

echo "=== vLLM Docker 실행 ==="
echo "모델: $MODEL"
echo "이미지: $IMAGE_NAME"
echo "캐시: $HF_CACHE"
echo ""

# 이미지가 없으면 빌드
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "이미지 빌드 중..."
    docker build -t "$IMAGE_NAME" .
fi

docker run -it --rm \
    --runtime nvidia \
    --gpus all \
    -v "${HF_CACHE}:/root/.cache/huggingface" \
    -e "HF_TOKEN=${HF_TOKEN}" \
    -p 8000:8000 \
    --ipc=host \
    --shm-size=8g \
    "$IMAGE_NAME" \
    --model "$MODEL" \
    --host 0.0.0.0 \
    --port 8000 \
    "${@:2}"

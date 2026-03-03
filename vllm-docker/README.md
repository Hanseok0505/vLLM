# vLLM Docker (Ubuntu 22.04)

이 문서는 Ubuntu 22.04 환경에서 vLLM 컨테이너를 빌드하고 실행하기 위한 정리본입니다.

## 1. 사전 요구사항

- Ubuntu 22.04
- NVIDIA GPU + NVIDIA Driver
- Docker 20.10+
- NVIDIA Container Toolkit (`nvidia-docker2`)
- 작업 경로: `~/ITB/vllm-docker`

### GPU 드라이버 확인

```bash
nvidia-smi
```

### NVIDIA Container Toolkit 설치

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### 컨테이너에서 GPU 사용 확인

```bash
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi
```

---

## 2. 이미지 빌드 (vLLM + Ubuntu 22.04)

```bash
cd ~/ITB/vllm-docker
docker build -t vllm:vllm-ubuntu22.04 .
```

CUDA 버전이 다를 경우:

```bash
docker build --build-arg CUDA_VERSION=12.1.0 -t vllm:vllm-ubuntu22.04 .
```

필요 시 태그 재설정:

```bash
docker tag vllm:vllm-ubuntu22.04 vllm/vllm-ubuntu22.04:latest
```

---

## 3. 컨테이너 실행

### 3-1. 기본 실행

```bash
docker run -it --rm \
  --gpus all \
  -p 8000:8000 \
  --ipc=host \
  --shm-size=8g \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN="${HF_TOKEN}" \
  vllm:vllm-ubuntu22.04 \
  --model Qwen/Qwen2.5-0.5B-Instruct \
  --host 0.0.0.0 \
  --port 8000
```

- private 모델을 쓰는 경우 `HF_TOKEN`은 반드시 설정해야 합니다.

### 3-2. `run.sh` 사용

`run.sh` 사용법:

```bash
chmod +x run.sh
./run.sh Qwen/Qwen2.5-0.5B-Instruct
./run.sh Qwen/Qwen2.5-1.5B-Instruct
./run.sh meta-llama/Llama-3.2-3B-Instruct
```

### 3-3. docker compose 실행

```bash
cp .env.example .env
# .env에서 아래 값 수정
# VLLM_MODEL=Qwen/Qwen2.5-0.5B-Instruct
# HF_TOKEN=hf_xxxxx

docker compose up -d
docker compose logs -f

docker compose down
```

---

## 4. API 확인

```bash
curl http://localhost:8000/v1/models
```

### Chat Completions 테스트

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "messages": [
      {"role": "user", "content": "안녕하세요. 자기소개 해줄 수 있나요?"}
    ],
    "max_tokens": 128
  }'
```

### Python (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(
  base_url="http://localhost:8000/v1",
  api_key="dummy",
)

resp = client.chat.completions.create(
  model="Qwen/Qwen2.5-0.5B-Instruct",
  messages=[{"role": "user", "content": "현재 GPU 사용량을 줄이는 방법이 뭐가 있나요?"}],
  max_tokens=128
)

print(resp.choices[0].message.content)
```

---

## 5. 실행 옵션

- `--tensor-parallel-size`
- `--max-model-len`
- `--gpu-memory-utilization`
- `--quantization`

예시:

```bash
./run.sh Qwen/Qwen2.5-7B-Instruct --tensor-parallel-size 2 --max-model-len 8192
```

---

## 6. 권장 리소스 설정

- `--ipc=host`
- `--shm-size=8g`
- `--gpu-memory-utilization 0.8 ~ 0.9`

---

## 7. 파일 구성

```text
vllm-docker/
  Dockerfile
  docker-compose.yml
  run.sh
  .env.example
  README.md
```

---

## 8. GitHub Container Registry 업로드

이 저장소에는 GHCR 업로드용 워크플로우가 등록되어 있습니다.

- 파일: `.github/workflows/publish-vllm-image.yml`

수동 실행:

```bash
gh workflow run publish-vllm-image.yml --repo Hanseok0505/vLLM --ref main
```

업로드 태그:

- `ghcr.io/hanseok0505/vllm:latest`
- `ghcr.io/hanseok0505/vllm:<커밋SHA>`

직접 사용:

```bash
docker pull ghcr.io/hanseok0505/vllm:latest
docker run -d -p 8000:8000 --gpus all ghcr.io/hanseok0505/vllm:latest \
  --model Qwen/Qwen2.5-0.5B-Instruct --host 0.0.0.0 --port 8000
```

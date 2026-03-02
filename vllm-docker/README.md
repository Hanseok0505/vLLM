# vLLM Docker (Ubuntu 22.04)

이 문서는 Ubuntu 22.04 + NVIDIA GPU 환경에서 `vLLM` 컨테이너를 빌드하고 실행하기 위한 실행 가이드입니다.

---

## 1. 요구 사항

- Ubuntu 22.04
- NVIDIA GPU + NVIDIA Driver
- Docker 20.10+
- NVIDIA Container Toolkit (`nvidia-docker2`)
- Dockerfile이 있는 경로: `~/ITB/vllm-docker`

### GPU 동작 확인

```bash
nvidia-smi
```

### NVIDIA Container Toolkit 설치

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

sudo systemctl restart docker
```

설치 확인:

```bash
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi
```

---

## 2. 이미지 빌드

```bash
cd ~/ITB/vllm-docker
docker build -t vllm/vllm-ubuntu22:latest .
```

CUDA 버전만 바꿔서 빌드하려면:

```bash
docker build --build-arg CUDA_VERSION=12.1.0 -t vllm/vllm-ubuntu22:latest .
```

현재 사용자께서 빌드한 이미지 태그가 다르다면 같은 방식으로 사용하세요.
예시:

```bash
docker images
docker tag vllm-v1:latest vllm/vllm-ubuntu22:latest
```

---

## 3. 실행

### 3-1. 단일 모델 실행 (docker run)

```bash
docker run -it --rm \
  --gpus all \
  -p 8000:8000 \
  --ipc=host \
  --shm-size=8g \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN="${HF_TOKEN}" \
  vllm/vllm-ubuntu22:latest \
  --model Qwen/Qwen2.5-0.5B-Instruct \
  --host 0.0.0.0 \
  --port 8000
```

- 공개 모델이면 `HF_TOKEN`은 생략 가능
- 게이트모델이면 `HF_TOKEN` 필수 (Hugging Face 토큰)

### 3-2. `run.sh` 사용

`run.sh`가 있는 경우:

```bash
chmod +x run.sh

# 기본 모델
./run.sh

# 원하는 모델로 실행
./run.sh Qwen/Qwen2.5-1.5B-Instruct
./run.sh meta-llama/Llama-3.2-3B-Instruct
./run.sh mistralai/Mistral-7B-Instruct-v0.3
```

### 3-3. Docker Compose

```bash
# 환경 변수 템플릿 복사
cp .env.example .env

# .env 편집 (필요 항목)
# VLLM_MODEL=Qwen/Qwen2.5-0.5B-Instruct
# HF_TOKEN=hf_xxxxx

docker compose up -d
docker compose logs -f

# 종료
docker compose down
```

---

## 4. API 호출 테스트

서버 기동 후:

```bash
curl http://localhost:8000/v1/models
```

### Chat Completions

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "messages": [
      {"role": "user", "content": "안녕하세요"}
    ],
    "max_tokens": 128
  }'
```

### Python (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(
  base_url="http://localhost:8000/v1",
  api_key="dummy"   # vLLM에서는 임의 문자열 가능
)

resp = client.chat.completions.create(
  model="Qwen/Qwen2.5-0.5B-Instruct",
  messages=[{"role": "user", "content": "안녕하세요"}],
  max_tokens=128
)

print(resp.choices[0].message.content)
```

---

## 5. 자주 쓰는 파라미터

```bash
--model
--tensor-parallel-size 2
--max-model-len 4096
--gpu-memory-utilization 0.9
--quantization awq
```

멀티 GPU 예시:

```bash
./run.sh Qwen/Qwen2.5-7B-Instruct --tensor-parallel-size 2 --max-model-len 8192
```

---

## 6. 안정적인 실행을 위한 권장 옵션

- `--ipc=host`
- `--shm-size=8g`
- 메모리 이슈 시 `--gpu-memory-utilization 0.8` 이하 조정
- 큰 모델은 `--max-model-len` 조정으로 메모리 절감

--- 

## 7. 디렉터리 구조

```text
vllm-docker/
├── Dockerfile          # Ubuntu 22.04 + CUDA + vLLM
├── docker-compose.yml  # Compose 설정
├── run.sh              # 실행 래퍼 스크립트
├── .env.example        # 환경 변수 예시
└── README.md           # 사용 가이드
```

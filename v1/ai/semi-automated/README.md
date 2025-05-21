# AI Semi-Automated Deployment Guide

### 1. 개요
AI 서비스의 반복적인 수동 배포 작업을 줄이고, 배포, 실행, 롤백, 헬스체크, 백업까지 한 번에 수행할 수 있도록 한 Semi-Automated 구조입니다.

- 반복적인 명령어 기반 수동 배포의 비효율성을 개선하고, 배포 프로세스를 스크립트 기반으로 자동화한 Semi-Automated 구조입니다.
- 클라우드 담당자뿐 아니라 다른 개발자도 서버에 접속하여 **정해진 alias 명령어만으로** `배포`, `재시작`, `롤백`, `헬스체크`, `백업` 작업을 수행할 수 있습니다.
- **환경 구분은 `.env` 파일을 통해** 이루어지며, `BRANCH`, `PORT`, `SERVICE_NAME` 등의 설정은 서버별로 분리되어 관리됩니다.

### 2. 서버 디렉토리 구조

```bash
~/nemo/
├── ai/
│   ├── ai-service/               # FastAPI 프로젝트 소스 (Git clone)
│   ├── backups/                  # 소스 백업 디렉토리 (.tar.gz)
│   ├── venv/                     # Python 가상환경
│   └── .env                      # 서버 환경별 설정 (BRANCH 등)
├── backend/
├── frontend/
└── cloud/                        # 클라우드 레포 (스크립트 포함)
    └── scripts/
        └── v1/
            └── ai/
                └── semi-automated/
                    ├── deploy.sh
                    ├── run.sh
                    ├── rollback.sh
                    ├── backup.sh
                    └── healthcheck.sh
```

### 3. 배포 / 운영 명령어 매핑

```bash
echo 'alias ai-deploy="bash ~/nemo/cloud/scripts/v1/ai/semi-automated/deploy.sh"' >> ~/.bashrc
echo 'ai-rollback() { bash ~/nemo/cloud/scripts/v1/ai/semi-automated/rollback.sh \"$1\"; }' >> ~/.bashrc
echo 'alias ai-health="bash ~/nemo/cloud/scripts/v1/ai/semi-automated/healthcheck.sh"' >> ~/.bashrc
echo 'alias ai-run="bash ~/nemo/cloud/scripts/v1/ai/semi-automated/run.sh"' >> ~/.bashrc
echo 'alias ai-backup="bash ~/nemo/cloud/scripts/v1/ai/semi-automated/backup.sh"' >> ~/.bashrc

source ~/.bashrc

```
| 명령어 | 설명 |
| --- | --- |
| `ai-deploy` | AI 전체 배포 |
| `ai-rollback` | 최신 롤백 |
| `ai-rollback <파일명>` | 특정 백업 롤백 |
| `ai-health` | 헬스체크 수행 |
| `ai-run` | AI 서버 재시작 (PM2) |
| `ai-backup` | AI 소스 백업 |

### 4. 주요 스크립트 설명
| 파일               | 설명                                                             |
| ---------------- | -------------------------------------------------------------- |
| `deploy.sh`      | `.env`의 `BRANCH`에 따라 소스를 최신화하고, 백업 → 가상환경 구성 → 실행 → 헬스체크까지 자동화 |
| `run.sh`         | `.env` 로드 후 PM2로 FastAPI 실행                                    |
| `backup.sh`      | 현재 소스를 tar.gz 형태로 백업, 최대 7개 유지                                 |
| `rollback.sh`    | 가장 최근 또는 특정 백업으로 소스 복원 및 실행                                    |
| `healthcheck.sh` | `/ai/v1/groups/information` API로 상태 체크, 실패 시 종료                |

### 5. 비고
- 기존의 Manual 방식은 없던 롤백 로직 추가
- [Python 환경 버전 불일치 트러블 슈팅]( https://github.com/100-hours-a-week/6-nemo-wiki/issues/121)
- 모든 스크립트는 공통으로 관리되며, .env 기반 분기로 환경을 구분 (리팩토링)

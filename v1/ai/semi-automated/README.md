# AI Semi-Automated Deployment Guide

### 1. 개요
AI 서비스의 반복적인 수동 배포 작업을 줄이고, 배포, 실행, 롤백, 헬스체크, 백업까지 한 번에 수행할 수 있도록 한 Semi-Automated 구조입니다.
- 모든 스크립트는 cloud 레포에서 관리되며, 서버에서는 .env 환경변수를 기준으로 동작합니다.
- 기존의 명령어 기반의 수동 배포의 비효율성을 개선하고, 반복 작업은 스크립트로 자동화한 Semi-Automated 배포 방식
- 클라우드 담당자뿐 아니라 다른 개발자도 서버에 접속하여 **정해진 alias 명령어만으로** `배포`, `재시작`, `롤백`, `헬스체크`, `백업` 작업을 수행할 수 있습니다.
- 디스코드 웹훅을 통해 배포/롤백 성공 여부 및 헬스체크 실패 상황을 실시간으로 모니터링할 수 있습니다.

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
echo 'alias ai-deploy="bash ~/nemo/cloud/v1/ai/semi-automated/deploy.sh"' >> ~/.bashrc
echo 'ai-rollback() { bash ~/nemo/cloud/v1/ai/semi-automated/rollback.sh \"$1\"; }' >> ~/.bashrc
echo 'alias ai-health="bash ~/nemo/cloud/v1/ai/semi-automated/healthcheck.sh"' >> ~/.bashrc
echo 'alias ai-run="bash ~/nemo/cloud/v1/ai/semi-automated/run.sh"' >> ~/.bashrc
echo 'alias ai-backup="bash ~/nemo/cloud/v1/ai/semi-automated/backup.sh"' >> ~/.bashrc

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

### 4. 크론탭 설정
    ```bash
    # 초기엔 권한 필요
    `chmod +x ~/nemo/cloud/v1/backend/semi-automated/*.sh`
    
    # 주기 등록
    crontab -e
    
    # Dev 서버 설정(5분 주기)
    */5 * * * * /home/ubuntu/nemo/cloud/v1/ai/semi-automated/healthcheck.sh
    
     # 크론탭 실행 로그 확인 (Ubuntu 기준)
     cat /var/log/syslog | grep CRON
    ```

### 5. 비고
- 기존의 Manual 방식은 없던 롤백 로직 추가
- [Python 환경 버전 불일치 트러블 슈팅]( https://github.com/100-hours-a-week/6-nemo-wiki/issues/121)
- 디스코드 알림 추가
  - 배포 성공 유무 (각 서비스 + 클라우드)
  - 롤백 성공 유무 (각 서비스 + 클라우드)
  - 헬스 체크 크론탭 (클라우드만)
    - dev는 5분 주기
    - prod는 1분 주기
    - 트리거: HTTP/200 응답이 아닐 때
- 모든 스크립트는 공통으로 관리되며, .env 기반 분기로 환경을 구분 (리팩토링)

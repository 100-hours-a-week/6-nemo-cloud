# AI Semi-Automated Deployment Guide (v1-dev)

### 1. 개요

- 기존의 명령어 기반의 수동 배포의 비효율성을 개선하고, 반복 작업은 스크립트로 자동화한 Semi-Automated 배포 방식
- 클라우드 담당자 뿐만 아니라 다른 파트 개발자도 서버에 동일하게 들어와 정해진 명령어(alias)만 실행해서 배포, 실행, 롤백, 헬스체크, 백업까지 모두 처리 가능

### 2. 서버 디렉토리 구조

```bash
~/nemo/
└── ai/
    ├── ai-service/                # Git 소스 클론 위치 (프로젝트 루트)
    │   ├── src/
		│   │   ├── key.json     
    │   ├── venv/                 
    │   └── requirements.txt      
    ├── scripts/                  
    │   ├── backup.sh            
    │   ├── deploy.sh             
    │   ├── healthcheck.sh
    │   ├── healthcheck_cron.sh
    │   ├── rollback.sh           
    │   └── run.sh                
    ├── .env                       # 환경변수 파일          
```

### 3. 배포 / 운영 명령어 매핑

```bash
echo 'alias ai-deploy="bash ~/nemo/ai/scripts/deploy.sh"' >> ~/.bashrc
echo 'ai-rollback() { bash ~/nemo/ai/scripts/rollback.sh "$1"; }' >> ~/.bashrc
echo 'alias ai-health="bash ~/nemo/ai/scripts/healthcheck.sh"' >> ~/.bashrc
echo 'alias ai-run="bash ~/nemo/ai/scripts/run.sh"' >> ~/.bashrc
echo 'alias ai-backup="bash ~/nemo/ai/scripts/backup.sh"' >> ~/.bashrc

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

- `backup.sh` : FastAPI 소스 코드 및 모델 파일 백업, 최대 7개 보관
- `deploy.sh` : 전체 배포 프로세스 (백업 → 소스 최신화 → 가상환경 세팅 → 실행 → 헬스체크)
- `run.sh` : PM2로 FastAPI 서버 실행
- `healthcheck.sh` : FastAPI 헬스체크 수행
- `rollback.sh` : 최신/지정 백업 파일로 롤백, 헬스체크 포함
- `healthcheck.cron.sh` : 주기적 헬스체크 및 장애 발생 시 디스코드 알림 전송 (크론탭에서 사용)
- 추가 명령어

    ```bash
    # 권한 부여
    chmod +x /home/ubuntu/nemo/ai/scripts/healthcheck_cron.sh
    
    # 주기 등록
    crontab -e
    
    # Dev 서버 설정(5분 주기)
    */5 * * * * /home/ubuntu/nemo/ai/scripts/healthcheck_cron.sh
    
     # 크론탭 실행 로그 확인 (Ubuntu 기준)
     cat /var/log/syslog | grep CRON
    ```


### 5. 비고

- 기존의 Manual 방식은 없던 롤백 로직 추가
- 배포 및 롤백 성공 여부 알림 추가 (250515)
- 크론잡 및 관련 알림 추가 (250515)
- https://github.com/100-hours-a-week/6-nemo-wiki/issues/121
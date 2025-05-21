# Backend Semi-Automated Deployment Guide (v1-dev)

### 1. 개요

- 기존의 명령어 기반의 수동 배포의 비효율성을 개선하고, 반복 작업은 스크립트로 자동화한 Semi-Automated 배포 방식
- 클라우드 담당자 뿐만 아니라 다른 파트 개발자도 서버에 동일하게 들어와 정해진 명령어(alias)만 실행해서 배포, 실행, 롤백, 헬스체크, 백업까지 모두 처리 가능

### 2. 서버 디렉토리 구조

```bash
~/nemo/
├── ai/
├── backend/
│   ├── backend-service/           # Git 소스 클론 위치
│   ├── jar-backups/               # JAR 파일 백업 저장소 (최대 7개 유지)
│   │   ├── 20250512-0037.jar      # [백업] 2025-05-12 00:37 생성
│   │   └── 20250512-0113.jar      # [백업] 2025-05-12 01:13 생성
│   ├── scripts/                   # 배포/운영 스크립트 모음
│   │   ├── backup.sh              # JAR 파일 백업 스크립트
│   │   ├── deploy.sh              # 전체 배포 스크립트 (백업 + 빌드 + 실행)
│   │   ├── healthcheck.sh         # 헬스체크 스크립트
│   │   ├── healthcheck_cron.sh    # 헬스체크 크론 스크립트
│   │   ├── rollback.sh            # 롤백 스크립트
│   │   └── run.sh                 # PM2 서비스 실행 스크립트
│   └── .env                       #환경변수 파일
└── ...
```

### 3. 배포 / 운영 명령어 매핑

```bash
echo 'alias be-deploy="bash ~/nemo/backend/scripts/deploy.sh"' >> ~/.bashrc
echo 'be-rollback() { bash ~/nemo/backend/scripts/rollback.sh "$1"; }' >> ~/.bashrc
echo 'alias be-health="bash ~/nemo/backend/scripts/healthcheck.sh"' >> ~/.bashrc
echo 'alias be-run="bash ~/nemo/backend/scripts/run.sh"' >> ~/.bashrc
echo 'alias be-backup="bash ~/nemo/backend/scripts/backup.sh"' >> ~/.bashrc

source ~/.bashrc
```

| 명령어 | 설명 |
| --- | --- |
| `be-deploy` | 전체 배포 실행 |
| `be-rollback` | 최신 백업으로 롤백 |
| `be-rollback <timestamp>` | 특정 타임스탬프 롤백 (예: `be-rollback 20250512-0105`) |
| `be-health` | 헬스체크 수행 |
| `be-run` | PM2 서비스 재시작 |
| `be-backup` | JAR 수동 백업 실행 |

### 4. 주요 스크립트 설명

- `backup.sh` : JAR 파일 백업, 최대 7개 보관
- `deploy.sh` : 전체 배포 프로세스 (백업 → 빌드 → 실행 → 헬스체크)
- `run.sh` : PM2로 서버 실행 (환경변수 자동 로드)
- `healthcheck.sh` : Spring Boot Actuator 헬스체크 수행
- `rollback.sh` : 최신/지정 JAR 파일로 롤백, 헬스체크 포함
- `healthcheck_cron.sh`
- `명령어`
    ```bash
    # 권한 부여
    chmod +x /home/ubuntu/nemo/backend/scripts/healthcheck_cron.sh
    
    # 주기 등록
    crontab -e
    
    # Dev 서버 설정(5분 주기)
    */5 * * * * /home/ubuntu/nemo/backend/scripts/healthcheck_cron.sh
    
     # 크론탭 실행 로그 확인 (Ubuntu 기준)
     cat /var/log/syslog | grep CRON
    ```


### 5. 비고

- 기존의 Manual 방식은 없던 롤백 로직 추가
- 디스코드 알림 추가
  - 배포 성공 유무 (각 서비스 + 클라우드)
  - 롤백 성공 유무 (각 서비스 + 클라우드)
  - 헬스 체크 크론탭 (클라우드만)
    - dev는 5분 주기
    - prod는 1분 주기
    - 트리거: HTTP/200 응답이 아닐 때
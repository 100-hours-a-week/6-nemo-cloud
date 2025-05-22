# Frontend  Semi-Automated Deployment Guide

### 1. 개요
Next.js 기반 프론트엔드 서비스의 배포, 실행, 롤백, 헬스체크, 백업을 자동화한 Semi-Automated 구조입니다.
- 모든 스크립트는 cloud 레포에서 관리되며, 서버에서는 .env 환경변수를 기준으로 동작합니다.
- 기존의 명령어 기반의 수동 배포의 비효율성을 개선하고, 반복 작업은 스크립트로 자동화한 Semi-Automated 배포 방식
- 클라우드 담당자 뿐만 아니라 다른 파트 개발자도 서버에 동일하게 들어와 정해진 명령어(alias)만 실행해서 배포, 실행, 롤백, 헬스체크, 백업까지 모두 처리 가능
- 디스코드 웹훅을 통해 배포/롤백 성공 여부 및 헬스체크 실패 상황을 실시간으로 모니터링할 수 있습니다.

### 2. 서버 디렉토리 구조

```bash
~/nemo/
├── frontend/
│   ├── .env                      # 환경변수 파일 (PORT, BRANCH 등)
│   ├── frontend-service/         # Next.js Git 소스 클론 위치
│   ├── .next-backups/            # 빌드 산출물 백업 디렉토리 (.tar.gz)
│   └── scripts/                  # 클라우드 레포 기준 스크립트 위치
├── cloud/
│   └── v1/
│       └── frontend/
│           └── semi-automated/
│               ├── deploy.sh
│               ├── run.sh
│               ├── rollback.sh
│               ├── backup.sh
│               └── healthcheck.sh
```

### 3. 배포 / 운영 명령어 매핑

```bash
echo 'alias fe-deploy="bash ~/nemo/cloud/v1/frontend/semi-automated/deploy.sh"' >> ~/.bashrc
echo 'fe-rollback() { bash ~/nemo/cloud/v1/frontend/semi-automated/rollback.sh \"$1\"; }' >> ~/.bashrc
echo 'alias fe-health="bash ~/nemo/cloud/v1/frontend/semi-automated/healthcheck.sh"' >> ~/.bashrc
echo 'alias fe-run="bash ~/nemo/cloud/v1/frontend/semi-automated/run.sh"' >> ~/.bashrc
echo 'alias fe-backup="bash ~/nemo/cloud/v1/frontend/semi-automated/backup.sh"' >> ~/.bashrc

source ~/.bashrc
```

| 명령어 | 설명 |
| --- | --- |
| `fe-deploy` | 프론트엔드 전체 배포 |
| `fe-rollback` | 프론트엔드 최신 롤백 |
| `fe-rollback <파일명>` | 프론트엔드 특정 백업 롤백 |
| `fe-health` | 프론트엔드 헬스체크 수행 |
| `fe-run` | 프론트엔드 서버 재시작 (PM2) |
| `fe-backup` | 프론트엔드 빌드 산출물 백업 |

### 4. 크론탭 설정
```bash
# 권한 부여
chmod +x /home/ubuntu/nemo/cloud/v1/frontend/healthcheck.sh

# 주기 등록
crontab -e

# Dev 서버 설정(5분 주기)
*/5 * * * * /home/ubuntu/nemo/cloud/v1/frontend/healthcheck.sh

 # 크론탭 실행 로그 확인 (Ubuntu 기준)
 cat /var/log/syslog | grep CRON
```

### 5. 비고
- 기존의 Manual 방식은 없던 롤백 로직 추가
- .env 파일 관리 필요
- ESLint Config 파일 관리 필요
- 초기엔 권한 필요: `chmod +x ~/nemo/cloud/v1/frontend/scripts/*.sh`
- 디스코드 알림 추가
    - 배포 성공 유무 (각 서비스 + 클라우드)
    - 롤백 성공 유무 (각 서비스 + 클라우드)
    - 헬스 체크 크론탭 (클라우드만)
        - dev는 5분 주기
        - prod는 1분 주기
    트리거: HTTP/200 응답이 아닐 때
- 모든 스크립트는 공통으로 관리되며, .env 기반 분기로 환경을 구분 (리팩토링)

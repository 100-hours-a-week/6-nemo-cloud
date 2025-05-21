# Backend Semi-Automated Deployment Guide

### 1. 개요
Spring Boot 기반 백엔드 서비스의 배포, 실행, 롤백, 헬스체크, 백업을 자동화한 Semi-Automated 구조입니다.
- 모든 스크립트는 cloud 레포에서 관리되며, 서버에서는 `.env` 환경변수를 기준으로 동작합니다.
- 기존의 명령어 기반의 수동 배포의 비효율성을 개선하고, 반복 작업은 스크립트로 자동화한 Semi-Automated 배포 방식
- 클라우드 담당자 뿐만 아니라 다른 파트 개발자도 서버에 동일하게 들어와 정해진 명령어(alias)만 실행해서 배포, 실행, 롤백, 헬스체크, 백업까지 모두 처리 가능
- 디스코드 웹훅을 통해 배포/롤백 성공 여부 및 헬스체크 실패 상황을 실시간으로 모니터링할 수 있습니다.


### 2. 서버 디렉토리 구조

```bash
~/nemo/
├── backend/
│   ├── backend-service/           # Git 소스 clone 위치
│   ├── jar-backups/               # 빌드 산출물 백업 디렉토리 (.jar)
│   ├── .env                       # 환경 변수 (BRANCH, PORT, WEBHOOK 등)
├── cloud/
│   └── v1/
│       └── backend/
│           └── semi-automated/
│               ├── deploy.sh
│               ├── run.sh
│               ├── rollback.sh
│               ├── backup.sh
│               ├── healthcheck.sh
│               └── healthcheck_cron.sh
```

### 3. 배포 / 운영 명령어 매핑

```bash
echo 'alias be-deploy="bash ~/nemo/cloud/v1/backend/semi-automated/deploy.sh"' >> ~/.bashrc
echo 'be-rollback() { bash ~/nemo/cloud/v1/backend/semi-automated/rollback.sh \"$1\"; }' >> ~/.bashrc
echo 'alias be-health="bash ~/nemo/cloud/v1/backend/semi-automated/healthcheck.sh"' >> ~/.bashrc
echo 'alias be-run="bash ~/nemo/cloud/v1/backend/semi-automated/run.sh"' >> ~/.bashrc
echo 'alias be-backup="bash ~/nemo/cloud/v1/backend/semi-automated/backup.sh"' >> ~/.bashrc

source ~/.bashrc

```
| 명령어           | 설명                           |
| ------------- | ---------------------------- |
| `be-deploy`   | 전체 배포 (백업 → 빌드 → 실행 → 헬스체크)  |
| `be-run`      | PM2로 백엔드 서버 실행               |
| `be-health`   | 헬스체크 수행 (Spring Actuator 기반) |
| `be-backup`   | JAR 백업 수행                    |
| `be-rollback` | 최근 백업으로 롤백             |
| `be-rollback <파일명>` | 특정 백업 롤백 |


### 4. 크론탭 설정
    ```bash
    # 권한 부여
    chmod +x /home/ubuntu/nemo/cloud/v1/backend/healthcheck.sh
    
    # 주기 등록
    crontab -e
    
    # Dev 서버 설정(5분 주기)
    */5 * * * * /home/ubuntu/nemo/cloud/v1/backend/healthcheck.sh
    
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
- 모든 스크립트는 공통으로 관리되며, .env 기반 분기로 환경을 구분 (리팩토링)

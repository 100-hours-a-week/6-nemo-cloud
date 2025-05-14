# Frontend Manual Deployment Guide (v1-dev)

### 1. 개요

본 문서는 개발 환경에서의 **완전 수동(Bing Bang) 배포 방식**을 설명합니다.

롤백 전략 없이, 모든 배포 과정을 명령어로 직접 수행하거나 배포 스크립트(`deploy-fronted.sh`)만 실행하며,

배포 완료 후 단순 헬스체크만 진행합니다.

### 2. 서버 디렉토리 구조

```
manual-scripts
	├── deploy-fe.sh          # 프론트엔드 배포 스크립트
6-nemo-fe/
	├── .env                  # 환경 변수 설정
	├── .gitignore            # Git 무시 목록
	├── .next/                # Next.js 빌드 산출물 (배포 시 생성)
	├── next.config.ts        # Next.js 설정 파일
	├── package.json          # 프로젝트 메타 정보, 실행 스크립트
	├── pnpm-lock.yaml        # 패키지 버전 고정 (pnpm 사용)
	├── src/                  # 주요 소스 코드
	└── tsconfig.json         # TypeScript 설정
```

### 3. 배포 절차

1. **서버 접속**
    - GCP 콘솔을 통해 SSH 접속
    - `cd manual-scripts` 로 스크립트 디렉토리로 인동
    - `sudo su - ubuntu` 명령어로 `ubuntu` 계정으로 전환하기
2. **배포 스크립트 준비**
    - `deploy-fe.sh`로 저장 후 실행 권한 무여
    - `chmod +x deploy-frontend.sh`
3. **배포 스크립트 수작업 입력 혹은 배포 스크립트 실행**
    - `./deploy-frontend`
4. **배포 후 로그 확인**
    - `pm2 logs nemo-frontend`

### 4. 배포 스크립트 내용

```bash
#!/bin/bash
set -e

echo "==== 프론트엔드(Next.js) 배포 시작 ===="
cd

# 1. 소스 최신화
if [ -d "6-nemo-fe" ]; then
  echo "📦 기존 소스 업데이트 중..."
  cd "6-nemo-fe"
  if ! git pull origin "dev"; then
    echo "❌ git pull 실패. 클린 클론 시도..."
    cd ..
    rm -rf "6-nemo-fe"
    git clone -b "dev" "https://github.com/100-hours-a-week/6-nemo-fe.git"
    cd "6-nemo-fe"
  fi
else
  echo "📥 소스 클론 중..."
  git clone -b "dev" "https://github.com/100-hours-a-week/6-nemo-fe.git"
  cd "6-nemo-fe"
fi

# 2. 기존 PM2 프론트엔드 프로세스 종료
echo "🛑 기존 프론트엔드 PM2 프로세스 종료 중..."
pm2 delete nemo-frontend || true

# 3. pnpm 설치
echo "pnpm install 중..."
pnpm install

# 4. 환경변수 로드
if [ -f ".env" ]; then
  echo "📄 .env 환경변수 로드 중..."
	export $(grep -v '^#' .env | xargs || true)
fi

# 5. pnpm 빌드
echo "⚙️ pnpm build 중..."
pnpm run build

# 6. PM2로 실행
echo "PM2로 프론트 서버 실행 중..."
pm2 start pnpm --name nemo-frontend -- start

# 7. PM2 상태 저장 및 확인
pm2 save
pm2 status

# 8. 헬스 체크
echo "Next.js 서버 헬스체크 중..."
sleep 5
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000")

if [ "$RESPONSE" == "200" ]; then
  echo "✅ Next.js 서버 정상 동작 중 (HTTP 200)"
  echo "✅ FE 서비스 배포 완료"
  exit 0
else
  echo "❌ Next.js 서버 비정상 (응답 코드: $RESPONSE)"
  exit 1
fi
```

```bash
# eslintConfig
import { dirname } from "path";
import { fileURLToPath } from "url";
import { FlatCompat } from "@eslint/eslintrc";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const compat = new FlatCompat({
  baseDirectory: __dirname,
});

const eslintConfig = [
  ...compat.extends("next/core-web-vitals", "next/typescript"),
  {
    rules: {
      // 사용하지 않는 변수 무시
      "@typescript-eslint/no-unused-vars": "off",
      // 리액트 훅 규칙 무시
      "react-hooks/rules-of-hooks": "off",
    },
  },
];

export default eslintConfig;
```

### 5. 비고

- .env는 서버 내에서 관리
- ESLint 에러로 `eslint.config.mjs` 파일 수정
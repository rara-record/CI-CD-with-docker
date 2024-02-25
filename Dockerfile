FROM node:18-alpine AS base

# 의존성 설치 단계
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
# apk : 알파인 리눅스 패키지 관리자, libc6-compat lib : glibc의 기반 프로그램을 musl libc 기반과 호환되게 만들어주는 lib
# glibc에 의존하는 바이너리가 Alpine Linux에서 실행될 수 있도록 한다.
# Docker 이미지 내에서 작업 디렉토리를 /app 으로 설정하여, 이후 모든 명령어는 이 디텍토리 내에서 실행된다.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# 이미지의 현재 작업 디렉토리(/app)로 package.json과 여러 패키지 매니저의 락 파일들을 복사
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
# 사용된 패키지 매니저에 따라 다음 중 하나의 명령어가 실행
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi


# 소스 코드 빌드 단계: nextjs app을 빌드하는 과정으로, 이 과정에서 .next 디렉토리를 생성 후 빌드 결과물이 저장된다.
# 작업 디렉토리를 /app으로 설정하고
# deps 단계에서 설치한 node_modules 디렉토리를 현재 단계의 작업 디렉토리(/app/node_modules)로 복사
# 프로젝트 루트에서 모든 파일과 디렉토리를 이미지의 작업 디렉토리(/app)로 복사. 이는 프로젝트의 소스 코드들을 컨테이너 이미지 안으로 가져옵니다.
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# 빌드 과정에서 Next.js의 텔레메트리 수집 비활성화
# ENV NEXT_TELEMETRY_DISABLED 1

# yarn을 사용하여 프로젝트를 빌드
# RUN yarn build

# npm을 사용하여 프로젝트를 빌드
RUN npm run build

# 프로덕션 환경에 배포 단계: 빌드된 app을 실제로 실행하기 위한 환경을 설정하는 과정
FROM base AS runner
WORKDIR /app

# Node.js 애플리케이션을 프로덕션 모드로 실행
ENV NODE_ENV production

# 사용 데이터 수집 기능을 런타임에 비활성화하고 싶은 경우, 이 줄의 주석 처리를 해제
# ENV NEXT_TELEMETRY_DISABLED 1

# 사용자 및 그룹 추가
# 시스템 사용자 : nextjs 시스템그룹 : nodejs 를 추가 (루트 사용자 대신 제한된 권한을 가진 사용자로 애플리케이션 실행)
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# builder 단계에서 빌드된 public 디렉토리를 현재 작업 디렉토리의 public으로 복사합니다. 이 디렉토리는 정적 파일을 포함합니다.
COPY --from=builder /app/public ./public

# .next 디렉토리를 수동으로 생성하고, 이 디렉토리의 소유권을 nextjs 사용자와 nodejs 그룹에 할당합니다.
# builder 단계에서 생성된 .next 디렉토리의 내용을 runner 단계로 옮겨오기 위함입니다.
RUN mkdir .next
RUN chown nextjs:nodejs .next

# 출력 파일 추적 : https://nextjs.org/docs/advanced-features/output-file-tracing
# builder 단계에서 생성된 .next/standalone 디렉토리를 /app으로 복사. 서버 사이드 코드와 구성파일 포함
# builder 단계에서 생성된 .next/static 디렉토리를 현재 단계의 .next/static 위치로 복사. 정적 파일을 포함
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# 사용자 설정, Docker 컨테이너가 실행될 때 nextjs 사용자로 실행되도록 설정
USER nextjs

# 네트워크 설정, Docker 컨테이너의 3000번 포트를 외부에 노출
EXPOSE 3000

# 애플리케이션의 서비스 포트를 3000으로 설정
ENV PORT 3000

# 애플리케이션을 호스트하는 주소를 모든 인터페이스(0.0.0.0)로 설정
ENV HOSTNAME "0.0.0.0"

# Docker 컨테이너가 시작될 때 실행될 기본 명령을 설정
CMD ["node", "server.js"]
# Ranking Backend Ops

## 목적
- 홈 화면에서 사용하는 `users.overallRank`, `users.schoolRank`, `schools.overallRank`를 백엔드에서 일관되게 갱신합니다.
- 랭킹 기준은 현재 앱 기준과 동일하게 `score_total_personal`(개인), `score_total`(학교) 내림차순입니다.

## 동기화 스크립트
- 파일: `scripts/sync_ranks.js`
- 동작:
  - `users` 전체 조회 후 `overallRank`, `schoolRank` 갱신
  - `schools` 전체 조회 후 `overallRank` 갱신
  - 동점자는 문서 ID 오름차순으로 tie-break
  - `rankCalculatedAt` 타임스탬프 동시 기록

## 스케줄러 래퍼
- 파일: `scripts/run_sync_ranks.sh`
- 동작:
  - `scripts/.sync_ranks.lock` 잠금으로 중복 실행 방지
  - `logs/sync_ranks_YYYYMMDD.log`에 실행 로그 기록
  - `scripts/.env.sync_ranks`가 있으면 자동 로드

## 실행 방법
1. 스크립트 의존성 설치

```bash
cd scripts
npm install
cd ..
```

2. 서비스 계정 키 준비 및 환경 변수 설정

```bash
export FIREBASE_SERVICE_ACCOUNT=/absolute/path/service-account.json
```

3. 실행

```bash
npm --prefix scripts run sync:ranks
```

`FIREBASE_SERVICE_ACCOUNT`를 지정하지 않으면 `applicationDefault()`를 사용합니다. (권장: 운영 시 명시)

## 24시간 주기 실행(현재 권장)
1. 스케줄러용 실행 권한 부여

```bash
chmod +x scripts/run_sync_ranks.sh
```

2. (선택) 환경 변수 파일 생성: `scripts/.env.sync_ranks`

```bash
FIREBASE_SERVICE_ACCOUNT=/absolute/path/service-account.json
```

3. 크론 등록 예시 (`0 3 * * *` = 매일 03:00 1회)

```bash
crontab -e
```

```cron
0 3 * * * cd /Users/park/Desktop/PJT_RG/ranking_ground_v1_src && bash scripts/run_sync_ranks.sh
```

## 운영 권장
- 현재 정책 기준: **24시간마다 1회 집계 갱신**
- Cloud Scheduler + Cloud Run/VM cron 등으로 `24h` 주기 실행 권장
- 앱 홈 화면은 `rankCalculatedAt`이 24시간을 넘으면 랭킹을 "집계 중"으로 표시하도록 연동 가능
- 이 집계는 **점수 초기화(리셋)가 아니라 랭킹 재계산**입니다.

## 데이터 전제
- `users` 문서에 `schoolId`, `score_total_personal` 존재
- `schools` 문서에 `score_total` 존재

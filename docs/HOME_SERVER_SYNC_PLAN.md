# MLMD 홈서버 동기화 세부 계획

## 1. 문서 목적과 전제

이 문서는 `UX_IMPROVEMENT_PLAN.md`의 6.29와 9.26에서 마련한 로컬 우선 가족 동기화 기반을 실제 홈서버에 연결하기 위한 구현 계획이다.

이번 계획에서는 다음을 전제로 한다.

- 공용 클라우드보다 사용자가 관리하는 한 대의 홈서버를 우선 사용한다.
- Android와 Windows 앱은 인터넷이 없어도 모든 기록 기능을 계속 사용할 수 있다.
- 서버는 동기화 중계와 보존을 담당하지만 기록 내용의 신뢰 원본이나 충돌 판정자가 아니다.
- 1차 범위는 구조화 기록과 텍스트 및 첨부 메타데이터다. 사진, PDF, 음성, 동영상 원본은 기존 계획처럼 제외한다.
- 가족은 소수이고, 서버 한 대에서 여러 가족 공간을 운영할 수는 있지만 공간 사이 데이터와 권한은 완전히 분리한다.
- 외부 접속은 원시 포트 포워딩보다 가족 VPN을 우선한다.

## 2. 현재 기반과 해결해야 할 차이

### 이미 구현된 기반

- `FamilySyncTransport`로 제공자별 네트워크 구현이 앱의 저장 모델과 분리되어 있다.
- ObjectBox에 가족 공간, 전송 대기열, 기기별 수신 커서, 충돌 원문과 해결 이력을 저장한다.
- 로컬 저장 경로에서 활동, 할 일, 할 일 회차, 작성자, 첨부 메타데이터, 중복 판단, 커스텀 이벤트 정의의 변경을 outbox에 넣는다.
- 서버가 확인한 변경만 outbox에서 제거하고, 실패한 변경은 재시도 정보를 붙여 보존한다.
- 같은 엔티티의 양쪽 변경은 자동으로 덮어쓰지 않고 사용자 확인 대상으로 보존한다.
- 앱 시작, 포그라운드 복귀와 네트워크 복구 때 한 번에 하나의 동기화를 실행한다.

### 2026-08-03 서버 1차 골격 구현

- 기존 앱 저장소를 모노레포로 유지하고 독립 Go module인 `server/`, 언어 중립 계약인 `protocol/`, 홈 배포 파일인 `deploy/home-server/`를 추가했다.
- `GET /v1/health/live`, `GET /v1/health/ready`, `POST /v1/bootstrap/spaces`, `POST /v1/spaces/{spaceId}/exchange`를 구현했다.
- invite 생성·1회 소비, owner 전용 기기 목록·폐기 API를 구현했다. bootstrap과 invite 소비는 앱의 기존 `deviceProfileId`와 앱이 직접 생성한 256비트 secret을 사용한다.
- SQLite WAL migration, 256비트 무작위 기기 token 인증, 공간별 `serverSeq`, change ID 멱등성, cursor 페이지네이션과 재시작 복구를 구현했다.
- Dart의 secure credential store, XChaCha20-Poly1305 envelope codec, `dart:io` 홈서버 exchange client와 기본 provider를 구현했다. 자격 증명이 없는 로컬 설치는 네트워크 연결을 열지 않는다.
- bootstrap·invite HTTP client, 페어링 QR codec과 연결 application service를 구현했다. bootstrap과 invite 소비는 응답 유실 재시도에서 동일한 공간·기기 ID와 secret을 재사용하며, QR에서 받은 가족 키와 기기 자격증명을 secure storage에 저장한 뒤 기존 가족 공간 저장소에 연결한다.
- 가족 공유 설정 화면에 홈서버 bootstrap 입력, 직접 스캔 QR 참여, 연결된 기기의 초대 QR 표시를 연결했다. Android에는 카메라 권한과 사설 LAN의 평문 HTTP 접속 허용을 추가했으며 공개 서버는 HTTPS를 사용한다.
- owner용 연결 기기 목록과 기기 폐기 화면을 연결했다. 현재 기기는 앱과 서버 양쪽에서 폐기를 거부하며, 같은 기기의 폐기 요청은 최초 폐기 시각을 반환하는 멱등 연산으로 만들어 응답 유실 재시도를 허용한다.
- 충돌 중요도 정책을 추가해 투약(`mlmd.medication`)은 중요, 체온·수유량·일정은 주의, 나머지는 일반으로 분류한다. 일반 충돌은 기존 건수 알림을 유지하고, 투약 충돌은 가족 공유 화면에 지속 경고와 두 값 요약을 표시하며 상세 화면에서 약 이름·용량·투약 시각·작성자·기기·수정 시각을 비교한다.
- 동일한 충돌을 여러 기기에서 동시에 해소하면 `serverSeq`, 그 값이 없거나 같은 경우 `changeId` 순서로 자동 수렴한다. 해소 메타데이터와 양쪽 결과는 E2EE 본문 안에 두고, 선택되지 않은 결과도 기기 로컬 감사 상태에 보존한다.
- 동시 해소는 새 미해결 충돌로 되돌리지 않는다. 일반 항목은 간단한 알림, 투약 항목은 두 결과·작성자·기기·시각과 최종 적용값을 보여 주는 상세 경고를 남긴다. 확인 상태는 알림·최종 승자·작성자 프로필별 E2EE 변경으로 동기화한다.
- JSON Schema와 golden fixture를 추가하고 Go 통합 테스트에서 계약을 읽도록 연결했다.
- Go test, vet와 build를 로컬에서 검증하고 Linux CI에 race detector를 추가했다.
- 실행 중인 WAL 데이터베이스에서 `mlmd-server backup --key-file <key> --output <path>`로 암호화된 일관성 백업을 만들 수 있다. `VACUUM INTO`와 `quick_check`를 통과한 스냅샷을 1 MiB 단위 AES-256-GCM으로 스트리밍 암호화하고 인증된 종료 레코드와 디스크 동기화를 통과한 뒤에만 대상 경로에 게시하며 기존 파일은 덮어쓰지 않는다.
- 서버를 중지한 뒤 `mlmd-server restore --key-file <key> --input <path>`로 암호화 백업을 복원할 수 있다. 복원 파일 전체의 인증, SQLite 무결성·외래 키·스키마 버전 검사와 지원 migration을 임시 DB에서 마친 뒤에만 교체하며, 기존 DB와 WAL/SHM은 `mlmd.db.pre-restore-*` 디렉터리에 보존한다. 서버·백업 작업 잠금이 남아 있으면 복원을 거부하고 설치 실패 시 기존 파일을 원위치한다.
- 별도 `mlmd-backup` 프로세스가 시작 직후와 기본 1시간 간격으로 자동 백업 필요 여부를 확인한다. UTC 날짜마다 최대 한 파일을 만들고 최근 7개 UTC 날짜의 일별 백업과 현재 주를 포함한 최근 8개 ISO 주의 주별 최신 백업을 합집합으로 보존한다. 관리 형식과 일치하는 파일만 정리하며 실패한 주기는 기록한 뒤 다음 주기에 재시도한다.
- 새 자동 백업은 성공으로 기록하기 전에 별도 임시 작업공간에서 다시 복호화해 SQLite 무결성·외래 키·스키마 호환성과 migration을 검증한다. `verify-backup`으로 운영 DB를 교체하지 않는 수동 복원 훈련도 실행할 수 있고, `/v1/health/backup`은 마지막 성공·연속 실패·다음 예정 시각과 지연 상태를 readiness와 분리해 제공한다.

백업·복원·자동 보관·복원 검증과 상태 노출의 1차 범위는 구현했다. 남은 운영 범위는 실제 설치 환경의 정기 복원 훈련과 외부 알림 연동이다. bootstrap token은 서버 콘솔 설정용 환경 변수이며 최종 관리자 UI를 대체하지 않는다.

### 홈서버 연결 전에 보완할 차이

1. 실제 `FamilySyncTransport` 구현, 서버 API, 인증과 가입 절차가 없다.
2. 현재 `SyncChange`의 payload는 평문 JSON이다. README의 종단간 암호화 원칙을 만족하려면 서버 전송 전에 암호화해야 한다.
3. 서버가 정한 단조 증가 순번, 페이지네이션, 최초 기기의 전체 이력 업로드와 새 기기의 초기 전체 수신 규칙이 없다.
4. 저장 직후 동기화를 깨우는 신호와 앱이 열린 동안의 주기적 pull이 없다.
5. `ChildProfile`은 기기 설정 저장소에 있고 현재 공유 payload에 포함되지 않는다. 가족 공간과 아이의 관계를 먼저 정규화해야 한다.
6. 활동과 일기 컨테이너는 ObjectBox 관계를 사용하지만 현재 공유 단위는 활동 중심이다. 원격 활동 적용 시 날짜별 컨테이너 생성 규칙과 일기 본문 동기화 범위를 분리해야 한다.
7. 활동과 일기는 현재 물리 삭제 경로가 있어, 새 기기와 장기 오프라인 기기를 위한 삭제 표식 수명이 명확하지 않다.
8. 서버 로그 압축 전에는 모든 변경을 보존해야 하며, 압축 이후에는 암호화된 스냅샷 규격이 필요하다.

## 3. 권장 아키텍처

```text
Android / Windows 앱
  ├─ ObjectBox 원본 데이터
  ├─ Sync outbox / cursor / conflict
  ├─ 가족 키가 있는 Secure Storage
  └─ HomeServerFamilySyncTransport
             │ HTTPS over Tailscale
             ▼
MLMD Sync Server (Docker)
  ├─ 인증 및 기기 권한
  ├─ 공간별 단조 증가 serverSeq 발급
  ├─ 암호문 변경 로그 저장과 조회
  ├─ 초대 토큰 발급·소비·폐기
  └─ SQLite WAL + 정기 백업
```

1차 홈서버는 같은 내부 네트워크에서만 접속할 수 있게 한다. Docker port는 홈서버의 지정된 LAN 주소에만 publish하고, 호스트 firewall에서도 허용한 사설 subnet 이외의 접근을 차단한다. 라우터 포트 포워딩과 공인 인터넷 노출은 사용하지 않는다.

내부망에서도 다른 기기나 공유기 침해 가능성을 완전히 신뢰하지 않으므로 애플리케이션의 기기 인증과 payload 종단간 암호화는 그대로 유지한다. HTTPS는 내부 reverse proxy와 로컬 인증서를 사용할 수 있으면 적용하되, 1차 배포를 막는 필수 조건으로 두지는 않는다. 집 밖 접속이 필요해지면 Tailscale을 우선 추가하고, 공개 서비스는 별도 도메인과 공인 HTTPS를 사용한다. 접속 방식이 바뀌어도 동기화 프로토콜은 바꾸지 않는다.

### 서버 기술 구성

1차 구현은 다음 구성으로 확정한다.

- `server/`: 앱과 독립된 Go module
- HTTP: 표준 `net/http`
- JSON: 표준 `encoding/json`
- 저장소 경계: `database/sql`과 내부 `Store` interface
- 홈 저장소: cgo를 사용하지 않는 SQLite driver, WAL 모드, foreign key 활성화
- 로그: 표준 `log/slog`
- 동시 작업 수명: `context` + `golang.org/x/sync/errgroup`
- 배포: multi-stage Docker 빌드로 만든 단일 Go 실행 파일
- 설정: 환경 변수와 Docker secret
- 데이터 볼륨: `/data`
- 상태 확인: 인증이 필요 없는 최소 `/health/live`, DB 쓰기 가능 여부를 포함한 `/health/ready`

앱과 서버는 구현 코드를 공유하지 않는다. `protocol/`에는 JSON Schema, 프로토콜 버전, 크기 제한, 오류 코드와 golden JSON fixture를 둔다. Dart와 Go는 각각 자신의 DTO를 구현하고 동일 fixture에 대한 직렬화·역직렬화 contract test를 통과해야 한다. ObjectBox 엔티티나 Go DB row를 wire format으로 직접 노출하지 않는다.

SQLite는 초기 소규모 가족 서버에 충분하고 백업과 복구가 단순하다. 공개 서비스에서는 같은 Go application 계층과 HTTP 계약을 유지하고 `Store` 구현만 PostgreSQL로 교체한다. API 인스턴스는 메모리에 영속 세션을 두지 않는 stateless 구조로 만들어 수평 확장한다.

## 4. 서버가 알 수 있는 정보와 종단간 암호화

### 평문 서버 메타데이터

서버는 라우팅, 인증, 중복 제거와 순서 부여에 필요한 다음 정보만 평문으로 본다.

- 프로토콜 및 암호화 envelope 버전
- `familySpaceId`
- `changeId`
- 가명화된 `sourceDeviceId`
- 서버가 부여한 `serverSeq`와 `receivedAt`
- 암호문 크기

`entityType`, `entityId`, `entityRevision`, operation, 작성자 ID, 발생 시각과 payload는 모두 암호문 안에 넣는다. 서버 로그에는 요청 본문, 토큰, 초대 내용과 암호문을 출력하지 않는다.

### 암호화 방식

- 가족 공간을 처음 만든 앱이 무작위 256비트 `familyKey`를 생성한다.
- 앱은 `familyKey`를 `flutter_secure_storage`에 저장하며 ObjectBox나 일반 설정에 넣지 않는다.
- 각 변경은 새 무작위 nonce를 사용해 XChaCha20-Poly1305로 암호화한다.
- AAD는 `mlmd-sync-envelope`, envelope 버전, `familySpaceId`, `changeId`, `sourceDeviceId`를 NUL byte로 연결한 UTF-8로 고정해 메타데이터 바꿔치기를 막는다.
- 암호문 내부에는 현재 `SyncChange` 전체와 `schemaVersion`을 넣는다.
- 서버 응답을 받은 앱은 인증 태그, 공간 ID, change ID와 스키마를 검증한 뒤에만 원격 적용기로 넘긴다.
- 인증 실패한 항목은 cursor를 넘기지 않고 동기화를 중단하며 사용자에게 `가족 기록을 안전하게 확인할 수 없음` 상태를 표시한다.

암호화 적용은 `FamilySyncTransport` 아래가 아니라 별도 `EncryptedFamilySyncTransport` 장식 계층으로 둔다. 홈서버 HTTP 구현은 암호화 envelope만 전송하고, 테스트용 메모리 transport는 평문 도메인 변경으로 계속 검증할 수 있게 한다.

### 키 분실과 폐기

- 홈서버만 복원해서는 기록 본문을 복호화할 수 없다.
- 연결된 기기를 모두 잃고 가족 키 백업도 없으면 서버 데이터는 복구할 수 없음을 가입 시 명확히 안내한다.
- 1차 릴리스에서는 기존 연결 기기가 보여 주는 QR로만 새 기기를 가입시킨다.
- 기기 폐기 시 서버 접근 토큰을 취소한다. 이미 유출된 가족 키로 과거 데이터를 잊게 만들 수는 없으므로 이 한계를 표시한다.
- 키 epoch와 새 변경용 키 회전은 2차 보안 작업으로 둔다. 회전 시 과거 로그 전체 재암호화를 요구하지 않으며, 남은 기기가 새 epoch 키를 공유한다.

## 5. 가족 공간 생성과 기기 가입

### 서버 최초 설정

1. 서버 컨테이너가 최초 실행 시 1회용 bootstrap 토큰을 생성해 관리자 콘솔에 표시한다.
2. 첫 앱에서 홈서버 주소와 bootstrap 토큰을 입력하거나 서버가 표시한 설정 QR을 스캔한다.
3. 앱이 가족 키와 무작위 기기 접근 토큰을 생성한다.
4. 서버는 첫 가족 공간, owner 기기와 접근 토큰의 해시만 저장하고 bootstrap 토큰을 즉시 폐기한다.
5. 앱은 서버 URL, 공간 ID, 기기 토큰과 가족 키를 secure storage에 저장한다.
6. 앱이 로컬 공유 대상의 초기 변경을 outbox에 만들고 일반 exchange API로 업로드한다.

bootstrap 토큰은 서버 관리 권한이지 가족 키가 아니다. 서버 콘솔이나 설정 QR에 가족 기록의 복호화 키를 넣지 않는다.

### 두 번째 기기 초대

1. 이미 연결된 owner 또는 초대 권한 기기가 서버에 10분 유효, 1회 사용 invite를 만든다.
2. 기존 기기가 `serverUrl`, `familySpaceId`, invite token, `familyKey`, inviter 확인 지문을 담은 QR을 화면에 표시한다.
3. 새 기기는 QR을 직접 스캔하고 새 `deviceId`와 기기 접근 토큰을 만든다.
4. 새 기기가 invite token을 소비하면 서버는 해당 기기를 공간 구성원으로 등록하고 token hash를 저장한다.
5. 새 기기는 cursor 없이 페이지 단위로 전체 암호문 로그를 받아 로컬 DB를 구성한다.
6. 초기 수신이 끝난 뒤에만 `함께 사용 중`으로 표시한다.

QR에는 가족 키가 있으므로 스크린샷 공유를 권장하지 않는다. 원격 초대 링크와 짧은 코드는 키 합의와 상대 확인이 추가로 필요하므로 1차 범위에서 제외한다.

### 권한

- `owner`: 기기 초대, 기기 취소, 공간 이름 변경, 동기화
- `member`: 기록 동기화, 자신이 만든 invite의 취소; 기본적으로 새 기기 초대 불가
- 서버 관리자는 컨테이너 운영자일 뿐 기록 내용이나 앱 내 가족 권한을 갖지 않는다.

## 6. HTTP 동기화 계약

### 주요 endpoint

```text
GET    /v1/health/live
GET    /v1/health/ready
GET    /v1/health/backup
POST   /v1/bootstrap/spaces
POST   /v1/spaces/{spaceId}/invites
POST   /v1/invites/{inviteId}/consume
GET    /v1/spaces/{spaceId}/devices
DELETE /v1/spaces/{spaceId}/devices/{deviceId}
POST   /v1/spaces/{spaceId}/exchange
```

기기 API는 `Authorization: Bearer <deviceId>.<random secret>`을 사용한다. secret은 256비트 CSPRNG로 만들고 서버 DB에는 SHA-256 hash만 저장한다. 사람이 정하는 저엔트로피 비밀번호와 달리 무작위 256비트 token에는 느린 비밀번호 해시가 실질적인 이점을 주지 않는다. 비교는 상수 시간으로 수행한다. 모든 변경 endpoint는 요청의 공간과 token 소속 공간이 같은지 확인한다.

### exchange 요청

```json
{
  "protocolVersion": 1,
  "afterCursor": "1842",
  "limit": 200,
  "outgoing": [
    {
      "envelopeVersion": 1,
      "changeId": "uuid",
      "sourceDeviceId": "uuid",
      "nonce": "base64url",
      "ciphertext": "base64url"
    }
  ]
}
```

### exchange 응답

```json
{
  "acknowledgedChangeIds": ["uuid"],
  "incoming": [
    {
      "serverSeq": 1843,
      "receivedAt": "2026-08-02T12:34:56.000Z",
      "envelopeVersion": 1,
      "changeId": "uuid",
      "sourceDeviceId": "uuid",
      "nonce": "base64url",
      "ciphertext": "base64url"
    }
  ],
  "nextCursor": "2042",
  "hasMore": true
}
```

### 서버 처리 규칙

1. 한 요청의 outgoing 삽입과 순번 발급은 DB transaction 하나에서 처리한다.
2. `(family_space_id, change_id)`는 unique다. 같은 change ID 재전송은 성공으로 확인하고 새 로그를 만들지 않는다.
3. `serverSeq`는 가족 공간 안에서만 단조 증가한다. 앱의 시계와 `occurredAt`으로 전달 순서를 만들지 않는다.
4. 응답은 `serverSeq > afterCursor`를 오름차순으로 최대 `limit`개 반환한다.
5. 자신의 기기에서 올린 변경도 pull 결과에 포함될 수 있다. 앱은 change ID/revision으로 안전하게 무시할 수 있어야 한다.
6. cursor는 마지막으로 반환한 `serverSeq`다. 앱은 반환된 페이지의 모든 항목을 적용하거나 충돌함에 보존한 뒤에만 저장한다.
7. 중간 항목의 복호화 또는 적용이 실패하면 해당 페이지의 cursor를 저장하지 않는다. 이미 적용한 항목의 재수신은 멱등이어야 한다.
8. `hasMore`가 true면 같은 실행 안에서 다음 페이지를 요청하되, 한 실행 최대 페이지 수를 두어 UI와 배터리를 독점하지 않는다.
9. 서버는 암호문을 해석하거나 리비전 충돌을 해결하지 않는다.

### 제한 기본값

- outgoing: 요청당 100건
- incoming: 페이지당 200건
- 암호문 변경 하나: 256 KiB
- 요청 전체: 2 MiB
- 요청 시간 제한: 15초
- invite: 10분, 1회 사용
- 기기별 API rate limit: 짧은 burst 30회/분, 지속 10회/분

제한 초과는 전체 요청을 모호하게 실패시키지 않고 안정적인 오류 코드와 재시도 가능 여부를 돌려준다. 부분 승인된 outgoing 목록은 반드시 응답에 명시한다.

## 7. 서버 데이터 모델

```text
family_spaces
- id (UUID, PK)
- display_name
- created_at
- next_seq

devices
- id (UUID, PK)
- family_space_id (FK)
- token_hash
- role
- display_name
- created_at / last_seen_at / revoked_at

invites
- id (UUID, PK)
- family_space_id (FK)
- token_hash
- created_by_device_id
- expires_at / consumed_at / revoked_at

changes
- family_space_id (FK)
- server_seq
- change_id
- source_device_id
- envelope_version
- nonce
- ciphertext
- received_at
- primary key (family_space_id, server_seq)
- unique (family_space_id, change_id)

device_cursors
- family_space_id (FK)
- device_id (FK)
- last_reported_seq
- updated_at
```

서버의 `device_cursors`는 운영과 향후 compaction 판단용이다. 클라이언트가 실제 적용 cursor의 주체이며, 서버 cursor 값만으로 클라이언트 데이터를 복구됐다고 간주하지 않는다.

## 8. 클라이언트 처리 흐름

### 로컬 변경

1. 원본 ObjectBox 저장과 outbox 적재를 가능한 한 같은 repository 작업 경계에서 끝낸다.
2. 화면은 네트워크를 기다리지 않고 즉시 로컬 값을 보여 준다.
3. outbox가 빈 상태에서 새 항목이 생기면 sync wake-up 신호를 보낸다.
4. 2초 debounce 후 exchange를 실행해 짧은 연속 입력을 한 묶음으로 보낸다.
5. 서버가 확인한 change ID만 삭제한다.
6. 실패 시 지수 backoff에 jitter를 더한다. 5초, 15초, 1분, 5분, 15분을 상한으로 하고 네트워크 복구·수동 재시도는 즉시 한 번 시도한다.

### 원격 변경

1. envelope 메타데이터와 인증 태그를 확인하고 복호화한다.
2. `schemaVersion`, 공간, change ID와 payload 크기를 검증한다.
3. 현재 `FamilySyncRemoteApplier`로 멱등 적용하거나 충돌을 보존한다.
4. 한 페이지 전체가 처리된 뒤 cursor를 저장한다.
5. 성공 후 관련 provider와 검색 색인을 갱신한다. 임베딩은 서버에서 받지 않고 로컬에서 재생성한다.

### 실행 시점

- 앱 시작과 포그라운드 복귀
- 네트워크가 사용 가능해진 순간
- 새 outbox 변경이 생긴 뒤 2초 debounce
- 앱이 포그라운드이고 가족 공유가 연결된 동안 30초 주기
- 사용자가 상태 화면에서 `지금 다시 시도`를 누를 때

Android 백그라운드 동기화는 OS가 정확한 실행 시점을 보장하지 않으므로 2차 단계에서 WorkManager 기반 best-effort 작업으로 추가한다. 알림이나 의료 안전 판단이 즉시 동기화에 의존하도록 만들지 않는다. 실시간 WebSocket은 첫 구현에 넣지 않는다.

## 9. 데이터 범위와 엔티티별 규칙

| 데이터 | 1차 동기화 | 규칙 |
|---|---:|---|
| 아이 프로필 | 필수 추가 | 가족 공간 생성 전에 `local-child`를 UUID 아이로 승격하고 이름·생일·수정 리비전을 공유한다. |
| 활동/구조화 기록/메모 | 예 | `recordId`가 전역 식별자다. 날짜별 Diary 컨테이너는 원격 적용 시 로컬에서 결정적으로 찾거나 만든다. |
| 투약/의료 안전 기록 | 예 | 가능한 한 기존 값을 덮어쓰지 않고 `생성 -> 정정 -> 취소`의 추가 전용 사건으로 남긴다. 원기록과 모든 정정 이력을 보존한다. |
| 일기 본문 | 결정 필요 | 활동 컨테이너와 별도 사용자 본문이 있다면 별도 `diaryEntry` payload로 공유한다. 단순 날짜 컨테이너는 공유하지 않는다. |
| 할 일/반복/회차 | 예 | `childId`를 반드시 가족 공간의 아이 UUID로 검증한다. |
| 작성자 프로필 | 예 | 닉네임과 색상만 공유하며 로그인 자격 증명과 분리한다. |
| 기기 프로필 | 최소 | 가명 ID와 표시 이름, 폐기 상태만 공유한다. OS 상세 정보는 보내지 않는다. |
| 커스텀 이벤트 정의 | 예 | 보관은 `archivedAt`으로 처리하고 기기별 pin은 제외한다. |
| 중복 판단/충돌 해결 | 예 | 해결은 양쪽 변경을 `parents`로 참조하는 새 변경이다. 해결 결과끼리 경쟁해도 하나로 자동 수렴하며 모든 결과와 알림 이력을 삭제하지 않는다. |
| 첨부 메타데이터 | 예 | 원본 경로를 제외하고 종류, 크기, 해시, 원본 보관 기기와 삭제 상태만 공유한다. |
| 첨부 바이너리 | 아니요 | 1차 제외. 화면에서 `이 기기에 원본 없음`을 표시한다. |
| 초안, 검색 이력, 빠른 기록 pin | 아니요 | 기기별 상태로 유지한다. |
| 임베딩, 썸네일, AI 재생성 가능 결과 | 아니요 | 원본 변경 후 각 기기에서 재생성한다. |

### 삭제 표식

- 동기화 대상 삭제는 앱 원본에서 사라지더라도 outbox에는 `delete` 변경을 남긴다.
- 서버 변경 로그를 압축하지 않는 1차 버전에서는 delete 변경을 기한 없이 보존한다.
- 로컬 충돌/복구 UI에는 삭제 전 payload와 삭제 변경을 함께 보존한다.
- 첨부는 기존 `deletedAt` 복원 기간과 파일 purge를 유지하되, 원본 파일 purge가 메타데이터 delete 전달보다 먼저 일어나도 다른 기기가 파일을 가진 것처럼 표시하지 않게 한다.
- 서버 로그 compaction은 암호화 스냅샷과 모든 활성 기기의 적용 cursor를 구현한 뒤에만 시작한다.

## 10. 충돌과 순서 정책

- 서버 순번은 일반 변경의 사용자 사건 시각이나 최초 충돌의 승자 판정 기준이 아니다. 단, 같은 충돌을 이미 해소한 결과끼리 다시 경쟁할 때는 모든 클라이언트가 하나로 수렴하기 위한 최종 동률 해소 기준으로 사용할 수 있다.
- 서로 다른 entity ID는 모두 보존하고 기존 중복 후보 흐름으로 보낸다.
- 같은 entity ID에서 로컬 미전송 변경과 원격 변경이 다르면 현재처럼 두 버전을 충돌함에 보존한다.
- 단순히 더 늦게 서버에 도착했다는 이유로 기록을 덮어쓰지 않는다.
- 사용자 해결은 `max(localRevision, incomingRevision) + 1`의 새 변경으로 보낸다. 암호화 본문의 `resolution.parentChangeIds`에는 양쪽 원본 change ID를 정렬해 넣고, `sourceConflictId`와 `selectedResolution`도 함께 기록한다.
- 동일 change ID 재수신과 이미 저장한 충돌은 멱등 처리한다. revision이 같아도 change ID나 resolution 메타데이터가 다르면 동시 변경 또는 동시 해소일 수 있으므로 revision 값만 보고 버리지 않는다.
- 필드 단위 자동 병합은 1차 범위에서 하지 않는다. 향후 할 일 완료처럼 안전성이 검증된 엔티티만 별도 규칙을 둘 수 있다.

현재 시각의 microseconds 값을 revision으로 쓰는 경로는 기기 시계 역행과 동률 위험이 있다. 1차 서버 연결 전에 엔티티별 정수 revision을 로컬 원자 연산으로 증가시키거나 HLC(Hybrid Logical Clock)로 통일한다. 서버 시각을 revision으로 사용하지 않는다.

### 동시 충돌 해소의 수렴

두 기기가 같은 충돌을 서로 모른 채 동시에 해소하면 서로 다른 두 resolution change가 만들어질 수 있다. 이것을 사용자에게 다시 해결하라고 요구하지 않고 다음 규칙으로 자동 수렴한다.

1. 두 resolution이 같은 가족 공간·엔티티를 대상으로 하고 같은 정렬된 `parentChangeIds`를 참조하면 동일한 충돌에 대한 동시 해소로 판정한다. 각 기기에서 보이는 로컬 `sourceConflictId`는 달라질 수 있으므로 그룹 판정에 단독으로 사용하지 않는다.
2. 복호화된 결과가 같으면 의미상 중복으로 처리한다.
3. 결과가 다르면 더 큰 `serverSeq`의 resolution을 현재 표시값으로 선택한다. 이 기준까지 같을 수 있는 테스트나 복원 상황에는 `changeId`의 바이트 순서를 최종 동률 해소 기준으로 사용한다.
4. 선택되지 않은 resolution도 충돌·감사 이력에 보존한다.
5. 이후 모든 클라이언트가 두 resolution을 받으면 같은 현재값과 같은 동시 해소 사건 ID에 도달해야 한다.

`resolution` 메타데이터와 결과 payload는 E2EE 암호문 안에 둔다. 서버는 두 resolution이 같은 충돌을 해소했다는 사실도 판단하지 않는다.

이 규칙에서 `serverSeq`는 서버가 내용을 이해하거나 올바른 결과를 결정한다는 뜻이 아니다. 서버는 암호문에 안정적인 전송 순서만 부여하고, 클라이언트가 복호화 후 동일한 결정 함수를 실행한다. resolution 수신 순서가 달라도 결과가 같아야 한다.

동시 해소 사건의 ID는 양쪽 resolution change ID를 정렬해 결정적으로 만든다. 1차 로컬 저장 키는 구분자를 포함한 정렬된 쌍을 그대로 사용하며, 외부에 노출되는 식별자가 필요해지면 같은 입력의 해시 표현으로 바꿀 수 있다.

```text
resolutionCollisionId = join(":", sort(resolutionA.changeId, resolutionB.changeId))
```

이 ID를 알림 중복 제거, 읽음/확인 상태와 감사 이력의 키로 사용한다.

### 중요도별 알림

자동 수렴은 사용자가 이미 해소한 충돌을 다시 보여 주지 않기 위한 데이터 처리 정책이다. 동시 해소가 있었다는 사실까지 숨기지는 않는다. 알림은 클라이언트가 E2EE payload를 복호화한 뒤 엔티티와 필드에 따라 생성하며, 서버는 알림의 의료적 의미를 알지 못한다.

| 중요도 | 예 | 사용자 경험 |
|---|---|---|
| 일반 | 일기 제목, 메모, 태그 | `같은 항목을 두 기기에서 동시에 수정해 최신 변경을 적용했습니다`와 같은 짧은 인앱 알림 또는 동기화 기록을 한 번 표시한다. |
| 주의 | 일정 시각, 수유량, 체온 메모 | 현재 적용값과 다른 기기의 값을 요약하고 알림함에 남긴다. |
| 중요 | 투약 여부, 약 이름, 용량, 투약 시각 | 지속되는 경고에 두 값, 작성자·기기와 각 수정 시각을 상세히 표시하고 가족 구성원의 명시적 확인을 요구한다. |

중요 알림의 기본 동작은 `확인했습니다`, `현재 기록 수정`, `변경 이력 보기`로 한다. 이미 끝난 충돌을 다시 해소하라는 표현은 사용하지 않는다. 사용자가 값을 고치면 두 resolution을 모두 확인한 뒤 만든 정상적인 새 변경이며, 이전 이력을 덮어쓰지 않는다.

- 일반 알림은 기기별 또는 사용자별 읽음 상태로 중복 표시를 막는다.
- 중요 알림의 확인은 `noticeId + winningChangeId + authorProfileId` 단위의 단조 E2EE 변경으로 동기화한다. 다른 구성원의 확인으로 내 알림이 사라지지 않으며, 최종 승자가 바뀌면 기존 확인을 새 결과에 재사용하지 않는다.
- 알림 전달 시점은 네트워크와 Android 백그라운드 실행에 따라 늦어질 수 있으므로 투약 여부 판단이나 응급 안전 기능이 즉시 알림에 의존해서는 안 된다.
- 중요도 분류는 UI 문자열이 아니라 protocol schema의 엔티티·필드 정책표로 버전 관리한다.

## 11. 운영, 백업과 복구

### Go 안정성 기준

서버 안정성은 OTP식 supervisor를 Go 안에 재구현하는 방식이 아니라 Go의 일반적인 실패 처리와 외부 프로세스 관리에 맞춘다.

```text
예상 가능한 실패
  -> error 반환, 로그, 제한된 backoff 또는 HTTP 오류 응답

HTTP handler panic
  -> 요청 단위 recovery, stack trace와 request ID 기록, 다른 요청 유지

background panic / 핵심 구성요소 종료
  -> 프로세스 종료
  -> Docker 또는 systemd가 깨끗한 프로세스로 재시작

재시작 전후 전송
  -> changeId unique, transaction, client outbox로 멱등 복구
```

#### 프로세스 수명

- `main`은 설정·secret·DB migration을 검증한 뒤 root `context`를 만든다.
- HTTP server와 장기 background loop는 `errgroup.WithContext` 아래에서 시작한다.
- 구성요소 하나가 복구 불가능한 error를 반환하면 root context를 취소하고 모든 구성요소가 종료될 때까지 기다린다.
- `SIGTERM`과 `SIGINT`에서는 새 요청 수락을 중단하고 정해진 grace period 안에 HTTP와 DB 작업을 마친다.
- 시작한 goroutine은 소유자, 종료 조건과 error 관찰 경로가 있어야 한다. fire-and-forget goroutine은 두지 않는다.
- `log.Fatal`과 `os.Exit`은 `main`의 기동 실패 외에는 사용하지 않는다.

#### 요청과 background 작업

- `net/http`의 요청별 panic 경계에 request ID·구조화 로그·지표를 추가하는 recovery middleware를 둔다.
- 인증 실패, 잘못된 payload, DB busy, timeout과 일시적 I/O 오류는 panic이 아니라 명시적 error로 처리한다.
- 초대 만료 정리, 백업, 로그 압축 같은 비핵심 주기 작업은 자기 loop에서 실행하며 한 번의 error를 기록하고 제한된 backoff 후 다음 실행을 계속한다.
- 예상하지 못한 background panic을 범용 `recover`로 숨기거나 임의 상태에서 같은 worker만 재시작하지 않는다. stack trace를 남기고 프로세스를 종료해 전체 상태를 새로 만든다.
- 반복 가능한 job은 같은 입력을 다시 처리해도 안전하도록 멱등하게 구현한다.

#### 자원 상한과 timeout

- HTTP server에 header, body read, response write와 idle timeout을 모두 설정한다.
- request body, outgoing/incoming 건수와 암호문 크기는 6장의 제한을 decode 전에 검사한다.
- DB connection 수, 동시 exchange 수, channel buffer와 background job 동시 실행 수에 명시적 상한을 둔다.
- 모든 DB·파일·네트워크 작업은 `context` 취소와 deadline을 전달받는다.
- 응답 body, row iterator, 파일 descriptor와 timer가 모든 반환 경로에서 닫히는지 테스트한다.
- 저장 공간 임계치와 DB 오류는 panic이 아니라 readiness·명시적 HTTP 오류로 드러낸다.

#### 데이터 안전성과 재시작

- outgoing insert와 `serverSeq` 발급은 transaction 하나에서 처리한다.
- commit 이후 응답 전에 프로세스가 종료되어도 같은 `changeId` 재전송을 성공으로 확인한다.
- 서버 메모리 상태는 영속 원본으로 사용하지 않는다. 재시작 후 SQLite에서 전체 운영 상태를 복구할 수 있어야 한다.
- SQLite WAL과 migration은 강제 종료·응답 유실·중복 재전송을 포함한 통합 테스트로 검증한다.
- Docker Compose는 `restart: unless-stopped`와 grace period를 설정한다. health check 실패만으로 데이터 volume을 교체하거나 삭제하지 않는다.

#### 자동 검증과 진단

- CI에서 `go test ./...`, `go test -race ./...`, `go vet ./...`를 실행한다.
- parser, cursor, token과 envelope 경계에는 fuzz test를 추가한다.
- 테스트에서 handler panic, background error, DB busy, transaction rollback, disk full, SIGTERM과 응답 유실을 주입한다.
- panic·비정상 종료에는 build version, task 또는 request, error, 전체 stack trace와 종료 코드를 남기되 secret과 payload는 기록하지 않는다.
- `/health/live`는 event loop와 HTTP 응답 가능성만, `/health/ready`는 DB와 핵심 쓰기 경로를 확인한다. 백업 같은 비핵심 기능 실패는 별도 degraded 상태로 표시한다.

이 구조에서 단일 프로세스 재시작은 일시적인 동기화 지연일 뿐 앱의 로컬 작성 실패가 아니다. 공개 서비스에서는 두 개 이상의 stateless Go API instance를 load balancer 뒤에 두어 한 instance 재시작을 사용자 요청에서 격리한다.

### 배포 기본값

- Docker Compose 서비스 하나와 named volume 하나
- Docker 또는 systemd의 자동 재시작을 최상위 장애 복구 경계로 사용한다.
- 컨테이너는 non-root, read-only root filesystem, 필요한 data volume만 쓰기 허용
- 이미지 버전은 고정 태그를 사용하고 자동 무중단 업그레이드를 가정하지 않는다.
- DB migration은 시작 전 백업 후 한 방향으로 실행하며 실패 시 새 버전을 기동하지 않는다.
- 서버 시간은 NTP로 맞추되 클라이언트 사건 시각과 충돌 판단에는 사용하지 않는다.

### 백업

- SQLite WAL을 안전하게 포함하는 `VACUUM INTO`로 일관된 스냅샷을 만든다.
- 최근 7일 일별, 최근 8주 주별 백업을 보존한다.
- 자동 실행은 HTTP 서버와 별도 프로세스로 두어 백업 키와 실패 수명을 분리한다. 시작 직후 한 번 실행하고 기본 1시간마다 UTC 당일 백업 존재 여부를 확인하며, 한 주기 실패는 다음 주기 실행을 중단하지 않는다.
- 새 백업은 암호화 파일을 다시 복호화해 실제 복원 전 검증·migration 경로를 통과한 뒤에만 성공 상태로 기록한다. 마지막 성공과 실패 횟수는 DB 옆의 원자 교체 상태 파일에 보존하고, HTTP 서버는 이를 별도 backup health로 읽되 readiness에는 반영하지 않는다.
- 최소 한 사본은 홈서버와 다른 물리 장치에 둔다.
- 백업에는 DB와 서버 설정을 포함하되 Docker secret 원문은 별도 암호화 보관한다.
- 기록 본문은 E2EE 암호문이지만 가족/기기 메타데이터가 있으므로 백업 파일 자체도 암호화한다.
- 백업 파일은 별도 256비트 키와 청크 단위 AES-256-GCM으로 인증 암호화한다. 키는 DB·백업과 다른 위치에 보관하고, 임시 평문 스냅샷은 보호된 DB 디렉터리 안에서만 만들고 암호화 직후 제거한다.
- 복원은 서버가 완전히 중지된 상태에서만 허용한다. 암호화 인증과 DB 검증이 끝나기 전에는 운영 DB를 건드리지 않고, 교체 직전 운영 DB·WAL·SHM을 같은 볼륨의 별도 디렉터리에 이동해 검증 완료 때까지 보존한다.
- 매 릴리스 전 자동 복원 테스트, 월 1회 별도 임시 볼륨으로 수동 복구 확인을 한다.

복구 후 서버 순번과 change ID unique 제약이 유지되어야 한다. 클라이언트는 복구 시점 이후 서버에서 사라진 자신의 outbox를 다시 올릴 수 있지만 이미 ack 후 지운 변경은 재생성할 수 없다. 따라서 서버 장애 복구 목표는 `RPO 24시간 이하`로 시작하되, 실제 가족 사용 전 1시간 단위 백업 또는 WAL 아카이빙을 검토한다.

### 관찰 가능성

- 구조화 로그: request ID, endpoint, 상태 코드, 지연, 공간과 기기의 단방향 해시, 업로드/다운로드 건수
- 금지 로그: bearer token, invite token, QR 내용, nonce/ciphertext, 복호화 payload
- 지표: DB 크기, 공간/기기 수, changes 증가율, exchange p50/p95, 4xx/5xx, 마지막 백업과 복구 점검 시각
- 저장 공간 70% 경고, 85%에서 새 invite 차단, 95%에서 새 업로드를 명시적 오류로 거절하되 기존 로컬 데이터는 계속 사용하게 한다.

## 12. 위협과 대응

| 위협 | 대응 |
|---|---|
| 홈서버 또는 DB 탈취 | payload E2EE, token hash 저장, 암호화 백업 |
| 네트워크 도청/변조 | HTTPS + AEAD 인증, 운영 환경 평문 HTTP 거부 |
| invite 탈취 | 10분 만료, 1회 사용, QR 직접 스캔, 소비 즉시 폐기 |
| 기기 토큰 탈취 | secure storage, 기기별 token, owner의 즉시 취소 |
| 재전송/중복 요청 | 공간별 change ID unique와 멱등 ack |
| 악성 또는 손상된 대형 요청 | 요청·항목 크기 제한, 개수 제한, rate limit |
| 서버 롤백 | 앱이 마지막 server identity와 cursor를 보존하고 cursor 후퇴를 경고; 백업 복구 절차에서 재동기화 모드 명시 |
| 가족 키 분실 | 연결 기기 QR 승계, 별도 복구 키 내보내기는 후속 보안 설계 |
| 폐기 기기의 과거 열람 | 이미 받은 데이터 회수 불가를 안내하고 접근 취소 + 이후 key epoch 회전 |

## 13. 구현 단계와 완료 조건

아래 예상치는 전담 개발자 1명 기준의 거친 범위다. 0~4단계는 약 4~6 개발 주, 이후 실제 기기 제한 운영은 달력 기준 2주를 별도로 잡는다. 암호화·복구 검증을 줄여 일정을 맞추지 않는다.

| 단계 | 예상 | 주요 산출물 |
|---|---:|---|
| 0. 계약과 모델 | 2~3일 | 언어 중립 protocol schema, 엔티티 규칙표, fixture |
| 1. 서버 기반 | 4~6일 | Go/SQLite server, Docker, integration test |
| 2. 암호화와 가입 | 5~7일 | E2EE envelope, secure storage, QR pairing |
| 3. 앱 연결 | 7~10일 | 실제 transport, 초기 sync, 재시도/pagination |
| 4. 장애와 충돌 | 5~7일 | fault test, 삭제/충돌 수렴, 사용자 상태 |
| 5. 제한 운영 | 달력 2주 | 설치 문서, backup runbook, soak 결과 |

### 0단계: 계약 고정과 모델 정리

- `protocol/`에 JSON Schema와 protocol v1 golden fixture를 만들고 Dart·Go DTO contract test를 추가한다.
- 아이 프로필, 일기 본문, 기기 프로필의 동기화 범위를 확정한다.
- 모든 공유 엔티티의 UUID, revision 증가, delete 표현을 표로 고정한다.
- `SyncExchange`에 `hasMore`와 서버 cursor 의미를 추가한다.

완료 조건: Android/Windows 앱과 Go 서버에서 같은 fixture의 정규 직렬화 결과가 같고, 알 수 없는 필드 허용·지원하지 않는 버전 거절 테스트가 통과한다.

### 1단계: 단일 서버와 평문 테스트 transport

- Go `net/http`, `context`, `errgroup`, `slog` 기반 application skeleton과 graceful shutdown을 먼저 구현한다.
- SQLite schema/migration, 공간·기기 인증, exchange와 health endpoint를 구현한다.
- Docker image와 Compose 예시, volume, backup/restore 명령을 만든다.
- E2E 암호화 전에는 테스트 데이터만 사용하고 실제 가족 기록을 넣지 않는다.

완료 조건: 재전송 중복 없음, 공간 격리, 순번 정렬, 페이지네이션, 부분/전체 실패와 SIGTERM graceful shutdown이 server integration test에서 통과한다.

### 2단계: 암호화와 안전한 가입

- 가족 키 생성·secure storage, XChaCha20-Poly1305 envelope와 QR 가입을 구현한다.
- token hash, 만료/1회 invite, 기기 취소를 구현한다.
- 로그 및 오류에 비밀이 남지 않는지 자동 검사한다.

완료 조건: 서버 DB와 패킷 캡처에 기록 본문이 없고, 잘못된 키·AAD·nonce·공간 바꿔치기가 모두 거절되며 cursor가 진행하지 않는다.

### 3단계: 앱 transport와 초기 동기화

- `HomeServerFamilySyncTransport`를 provider override로 연결한다.
- 초기 로컬 이력 outbox 생성과 새 기기 전체 pull을 구현한다.
- pagination loop, 저장 직후 debounce, 포그라운드 주기, backoff를 구현한다.
- 아이 프로필과 모든 1차 공유 엔티티의 원격 적용을 완성한다.

완료 조건: 빈 서버/기존 기기, 빈 새 기기/기존 서버, 두 기존 데이터 집합의 연결 세 시나리오에서 누락·중복 없이 수렴한다.

### 4단계: 충돌, 삭제와 장애 주입

- 같은 기록 양쪽 수정, 수정 대 삭제, 삭제 대 재생성, 시계 역행을 시험한다.
- 같은 충돌을 두 기기가 서로 다르게 동시에 해소했을 때 수신 순서와 무관하게 같은 현재값으로 수렴하고, 사용자가 충돌을 다시 해소하지 않아도 되는지 시험한다.
- 동시 해소 알림 ID의 결정성·중복 제거, 일반 알림의 1회 표시, 투약 관련 상세 알림과 구성원별 확인 상태의 E2EE 동기화를 시험한다.
- 투약 기록의 생성·정정·취소 이력이 덮어써지거나 누락되지 않는지 시험한다.
- 네트워크 단절, handler panic, background error, 서버 재시작, 응답 유실, DB busy, transaction rollback, 페이지 중간 손상과 디스크 부족을 주입한다.
- `go test -race`, fuzz test, `go vet`과 process restart 통합 테스트를 CI에 연결한다.
- 사용자 상태와 수동 재시도/충돌 해결 흐름을 연결한다.

완료 조건: 어떤 실패에서도 로컬 작성이 막히지 않고, ack되지 않은 outbox가 사라지지 않으며, 재연결 후 두 기기가 같은 상태로 수렴한다.

### 5단계: 홈 운영 검증과 제한 배포

- LAN 주소 binding, firewall, Docker port publish와 QR 기반 설정 마법사 문서를 만든다.
- 자동 백업, 실제 복원, 업그레이드/롤백 runbook을 검증한다.
- Windows 1대, Android 2대에서 2주 동안 제한 운영한다.

완료 조건: 2주간 데이터 누락 0건, 미해결 암호화 오류 0건, 성공 exchange p95 1초 이하, 서버 재시작 후 자동 회복, 백업 복원 후 전체 수렴을 확인한다.

### 후속 단계

- Android best-effort background sync
- 암호화된 첨부 바이너리 chunk 동기화
- key epoch 회전과 복구 키
- 암호화 스냅샷 및 변경 로그 compaction
- VPN 없는 도메인 접속
- PostgreSQL 저장소와 다중 서버 운영

## 14. 테스트 매트릭스

최소 자동·수동 시나리오는 다음과 같다.

- 단일 기기: 생성/수정/삭제, 응답 유실 후 재전송
- 두 기기: 순차 수정, 동시 수정, 같은 내용의 반복 전송, 서로 다른 ID의 중복 사건
- 오프라인: 1시간/7일/180일 뒤 복귀, 여러 페이지 backlog
- 가입: 정상 QR, 만료 QR, 재사용 QR, 다른 공간 QR, 잘못된 가족 키
- 권한: member의 기기 취소 시도, 취소된 token, 공간 ID 바꿔치기
- 암호화: bit flip, nonce/AAD 변경, 지원하지 않는 envelope/schema 버전
- 서버: handler panic 격리, background error, 비정상 종료 자동 재시작, SIGTERM, DB 잠금, transaction rollback, 디스크 부족, 백업 복원
- 플랫폼: Windows↔Android 양방향, Android 절전/프로세스 종료 후 복귀, 잘못된 기기 시각
- 개인정보: 서버 DB·로그·백업에 제목, 메모, 아이 이름, 생일과 의료 payload 평문이 없는지 검사

## 15. 이번 결정과 보류 결정

### 이번 계획에서 채택

- 홈서버를 1차 전송 제공자로 사용
- 1차 홈서버는 지정된 내부 네트워크에서만 접근 허용; 집 밖 접속은 후속 Tailscale 선택지로 유지
- Go `net/http` + SQLite + Docker 구성
- `context`와 `errgroup`으로 프로세스 수명을 관리하고 Docker/systemd를 최상위 재시작 경계로 사용
- 예상 가능한 실패는 error·timeout·backoff로 처리하고 예상하지 못한 background panic은 프로세스를 새로 시작해 복구
- 서버는 불투명한 암호문 변경 로그만 저장
- QR 직접 스캔 가입과 기기별 bearer token
- 텍스트/구조화 데이터와 첨부 메타데이터만 1차 동기화
- at-least-once 전송, change ID 멱등성, 공간별 server sequence cursor
- 최초 충돌은 클라이언트가 보존하고 사용자가 해결
- 동시 충돌 해소 결과는 결정적으로 자동 수렴하고 모든 결과를 이력에 보존
- 일반 동시 해소는 간단히 알리고, 투약 등 중요 동시 해소는 상세 정보와 명시적 확인을 제공

### 구현 전에 짧게 확정할 항목

- 허용할 내부 subnet과 홈서버 고정 LAN 주소
- 내부 HTTPS를 1차부터 적용할지, E2EE와 기기 인증을 유지한 채 초기에는 HTTP를 허용할지
- 한 가족 공간이 아이 한 명만 포함하는지 여러 아이를 포함하는지
- 날짜별 Diary의 사용자 작성 본문을 활동과 함께 공유할지
- owner만 초대할지 member도 초대할 수 있게 할지
- RPO 24시간으로 시작할지 처음부터 더 짧은 백업 주기를 요구할지

위 항목은 전송·암호화 골격을 바꾸지 않는다. 0단계에서 제품 데이터 모델과 운영 기본값만 확정하면 구현을 시작할 수 있다.

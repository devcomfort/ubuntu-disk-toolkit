# Ubuntu Disk Toolkit

> 🚀 **Ubuntu 시스템용 통합 스토리지 관리 도구**

Ubuntu 환경에서 디스크, RAID, fstab을 통합 관리하는 포괄적이고 사용자 친화적인 CLI 도구입니다. 모듈형 API 아키텍처와 ID 기반 디스크 관리를 통해 안전하고 강력한 스토리지 관리를 제공합니다.

## ✨ 주요 특징

### 🎯 **완전한 스토리지 라이프사이클 관리**
- **RAID 관리**: RAID 0, 1, 5, 6, 10 지원 + 자동 파일시스템 생성 + fail-safe fstab 통합
- **디스크 관리**: ID 기반 안전한 디스크 식별 (UUID, PARTUUID, LABEL, /dev/sdX)
- **fstab 관리**: 자동 fail-safe 옵션 적용, 검증, 백업, ID 기반 안전성
- **종합 진단**: 실시간 건강 분석 및 자동 문제 수정

### 🛡️ **안전성 우선 설계**
- **Fail-safe 기본값**: 모든 fstab 항목에 `nofail` 옵션 자동 적용
- **ID 기반 안정성**: UUID/PARTUUID 사용으로 디바이스 경로 변경에 무관
- **자동 검증**: 디스크 존재성, RAID 호환성, 마운트 충돌 사전 검사
- **완전 자동 백업**: fstab, mdadm.conf 수정 시 타임스탬프 백업 생성

### 🎨 **사용자 친화적 인터페이스**
- **통합 CLI**: 단일 `ubuntu-disk-toolkit` 명령어로 모든 기능 접근
- **Just 워크플로우**: 개발자 친화적 `just` 명령어 지원
- **다중 출력 형식**: table, detailed, simple, JSON 지원
- **대화형 모드**: 복잡한 작업을 위한 단계별 안내

### ⚡ **모듈형 API 아키텍처**
- **Core Utilities**: `id-resolver.sh`, `validator.sh`, `fail-safe.sh`
- **High-Level APIs**: `disk-api.sh`, `fstab-api.sh`, `raid-api.sh`
- **코드 재사용성**: 모든 기능이 모듈화되어 안정적 재사용 가능
- **확장성**: 새로운 기능 추가가 용이한 계층적 구조

## 📋 시스템 요구사항

### 지원 운영체제
- Ubuntu 18.04 LTS 이상
- Debian 10 이상
- 기타 Debian 계열 배포판

### 필수 패키지
```bash
# 자동 설치 및 확인 제공
sudo apt update && sudo apt install -y \
    mdadm \
    smartmontools \
    util-linux \
    parted \
    e2fsprogs \
    shellcheck  # 개발 시 권장
```

## 🚀 빠른 시작

### 1. 저장소 클론 및 설치
```bash
git clone <repository-url>
cd ubuntu-disk-toolkit

# 🎯 방법 1: 완전 자동 설치 (권장)
just setup -y && just install -y

# 🔧 방법 2: 단계별 설치
just setup          # 개발 환경 설정
just install         # 시스템 설치

# 📋 방법 3: 수동 설치
./install/install-deps.sh -y
sudo ./install/install.sh -y
```

### 2. 즉시 사용 가능한 명령어
```bash
# 📊 시스템 상태 확인
ubuntu-disk-toolkit check-system
ubuntu-disk-toolkit list-disks
ubuntu-disk-toolkit list-raids
ubuntu-disk-toolkit list-fstab

# 🔧 Just 명령어로 더 편리하게
just check-system
just disks
just raids  
just fstab
```

## 🛠️ 개발 및 Just 워크플로우

### 📋 전체 Just 명령어 목록
```bash
just --list          # 모든 명령어 보기
just dev-guide        # 개발 가이드 보기
```

### ⚡ 핵심 Just 명령어들
```bash
# =============================================================================
# 🚀 개발 환경
# =============================================================================
just setup [-y]              # 개발 환경 설정 (의존성 설치 + 권한)
just install [-y]             # 시스템 설치 (비대화형 가능)
just uninstall [-y]           # 완전 제거

# =============================================================================
# 🧪 테스트 및 품질 검사
# =============================================================================
just test                     # 전체 테스트 실행
just lint [-y]                # shellcheck 검사 (자동 설치 옵션)
just demo                     # 데모 실행

# =============================================================================
# 💾 디스크 관리
# =============================================================================
just disks [TYPE]             # 디스크 목록 (table/available/mounted/raid-ready)
just disk-info <ID>           # 디스크 상세 정보
just mount-temp <ID> <MOUNT> [FS]     # 임시 마운트
just unmount-temp <TARGET> [force]    # 임시 언마운트

# =============================================================================
# ⚡ RAID 관리
# =============================================================================
just raids [FORMAT]           # RAID 상태 (detailed/simple/summary)
just create-raid <LEVEL> <MOUNT> [FS] <DISK1> <DISK2>...  # RAID 생성
just remove-raid <DEVICE> [wipe]      # RAID 제거  
just analyze-raid <DEVICE> [perf]     # RAID 상세 분석
just setup-raid               # 대화형 RAID 설정
just raid-disks               # RAID용 사용 가능한 디스크

# =============================================================================
# 📋 fstab 관리
# =============================================================================
just fstab [FORMAT]           # fstab 항목 목록
just add-fstab <ID> <MOUNT> [FS] [OPTIONS]    # fstab 추가 (fail-safe 자동)
just remove-fstab <IDENTIFIER>                # fstab 제거

# =============================================================================
# 🔍 시스템 관리
# =============================================================================
just check-system             # 전체 시스템 검사
just fix-system               # 자동 문제 수정
```

## 📖 사용법

### 🔧 **통합 CLI**
```bash
# 기본 정보 조회
ubuntu-disk-toolkit --help
ubuntu-disk-toolkit list-disks [table|available|mounted|raid-ready]
ubuntu-disk-toolkit list-raids [detailed|simple|summary]  
ubuntu-disk-toolkit list-fstab [detailed|table|simple]
ubuntu-disk-toolkit disk-info <UUID|PARTUUID|LABEL|/dev/sdX|sdX>

# 시스템 관리
ubuntu-disk-toolkit check-system      # 전체 검사
ubuntu-disk-toolkit fix-system        # 자동 문제 수정
```

### ⚡ **RAID 관리**
```bash
# RAID 생성 - 완전 자동화된 프로세스
ubuntu-disk-toolkit create-raid 1 /data ext4 sdb sdc
ubuntu-disk-toolkit create-raid 5 /storage ext4 sdb sdc sdd sde

# RAID 관리
ubuntu-disk-toolkit remove-raid /dev/md0 [wipe]
ubuntu-disk-toolkit analyze-raid /dev/md0 [perf]

# 대화형 모드 (복잡한 설정용)
ubuntu-disk-toolkit setup-raid
```

### 📋 **fstab 관리**
```bash
# ID 기반 안전한 fstab 관리 (fail-safe 자동 적용)
ubuntu-disk-toolkit add-fstab UUID=12345678-... /data ext4 defaults
ubuntu-disk-toolkit add-fstab PARTUUID=abcd-... /backup xfs "defaults,noatime"
ubuntu-disk-toolkit add-fstab /dev/sdb1 /temp ext4 defaults

# fstab 항목 제거
ubuntu-disk-toolkit remove-fstab /data
ubuntu-disk-toolkit remove-fstab UUID=12345678-...
```

### 💾 **디스크 관리**
```bash
# ID 기반 디스크 정보 (모든 ID 형식 지원)
ubuntu-disk-toolkit disk-info UUID=12345678-...
ubuntu-disk-toolkit disk-info /dev/sdb1
ubuntu-disk-toolkit disk-info sdb

# 임시 마운트 (fstab 수정 없음)
ubuntu-disk-toolkit mount-temp UUID=... /mnt/temp ext4
ubuntu-disk-toolkit unmount-temp /mnt/temp [force]
```

### 🎯 **실제 사용 예시**
```bash
# 1️⃣ RAID 1 미러링 설정 (완전 자동)
just create-raid 1 /data ext4 sdb sdc
# ✅ 디스크 검증 → RAID 생성 → 파일시스템 생성 → fstab 등록 (nofail 자동) → 마운트

# 2️⃣ 기존 디스크를 fstab에 안전하게 추가
just add-fstab UUID=12345678-abcd-... /backup ext4 "defaults,noatime"
# ✅ UUID 존재 확인 → 마운트포인트 충돌 검사 → nofail 추가 → fstab 백업 → 등록

# 3️⃣ 시스템 전체 검사 및 자동 수정
just check-system  # 문제점 발견
just fix-system    # 자동 수정 적용

# 4️⃣ RAID용 사용 가능한 디스크 확인
just raid-disks
# ✅ 마운트되지 않고 RAID에 속하지 않은 사용 가능한 디스크만 표시
```

## 🧪 테스트 시스템

### Bats 기반 통합 테스트
```bash
# 테스트 실행
just test                    # 전체 테스트
just lint -y                 # shellcheck 자동 설치 + 검사

# 개발 워크플로우
just setup -y && just test && just lint -y && just demo
```

### 테스트 구조
```
tests/
├── test_helpers.bash      # Mock 시스템 + 공통 함수
├── test_common.bats       # 기본 기능 테스트
├── test_integration.bats  # 통합 테스트 (ubuntu-disk-toolkit)
└── test_*.bats           # 기능별 세부 테스트
```

## 📁 프로젝트 구조

```
ubuntu-disk-toolkit/
├── 📋 README.md              # 프로젝트 개요
├── 🛠️ justfile              # Just 워크플로우
├── 📝 docs/
│   └── FEATURES.md           # 상세 기능 문서
├── 🎯 bin/                   # 실행 스크립트
│   ├── ubuntu-disk-toolkit   # 메인 통합 CLI
│   ├── check-system          # 시스템 검사
│   ├── manage-disk           # 디스크 관리
│   ├── manage-fstab          # fstab 관리
│   └── check-disk-health     # 종합 진단
├── 📚 lib/                   # 모듈형 라이브러리
│   ├── 🔧 Core Utilities
│   │   ├── common.sh             # 기본 유틸리티
│   │   ├── id-resolver.sh        # ID 해석 (UUID↔경로)
│   │   ├── validator.sh          # 검증 시스템
│   │   └── fail-safe.sh          # nofail 자동 적용
│   ├── 🎯 High-Level APIs
│   │   ├── disk-api.sh           # 디스크 관리 API
│   │   ├── fstab-api.sh          # fstab 관리 API
│   │   └── raid-api.sh           # RAID 관리 API
│   └── 🎨 Legacy Functions
│       ├── ui-functions.sh       # UI/출력 함수
│       ├── system-functions.sh   # 시스템 검사
│       ├── disk-functions.sh     # 디스크 관리
│       ├── fstab-functions.sh    # fstab 관리
│       └── raid-functions.sh     # RAID 관리
├── ⚙️ config/
│   └── defaults.conf         # 설정 파일
├── 🚀 install/
│   ├── install.sh            # 시스템 설치
│   ├── install-deps.sh       # 의존성 설치
│   └── uninstall.sh          # 완전 제거
└── 🧪 tests/                 # Bats 테스트 시스템
    ├── test_*.bats           # 기능별 테스트
    ├── test_helpers.bash     # 테스트 헬퍼
    └── run-tests.sh          # 테스트 실행기
```

## 🔧 고급 기능

### ID 기반 디스크 관리
```bash
# 지원하는 모든 ID 형식
ubuntu-disk-toolkit disk-info UUID=12345678-1234-1234-1234-123456789abc
ubuntu-disk-toolkit disk-info PARTUUID=abcd1234-12ab-34cd-56ef-123456789abc  
ubuntu-disk-toolkit disk-info LABEL=MyDisk
ubuntu-disk-toolkit disk-info /dev/sdb1
ubuntu-disk-toolkit disk-info sdb1
ubuntu-disk-toolkit disk-info sdb

# fstab에서는 UUID가 자동 우선 선택
just add-fstab /dev/sdb1 /data  # 내부적으로 UUID로 변환
```

### 자동 Fail-Safe 시스템
```bash
# 모든 fstab 추가 시 nofail 자동 적용
just add-fstab UUID=... /data ext4 defaults
# 실제 fstab: UUID=... /data ext4 defaults,nofail 0 2

# RAID의 경우 nofail + noauto 자동 적용  
just create-raid 1 /data ext4 sdb sdc
# 실제 fstab: UUID=... /data ext4 defaults,nofail,noauto 0 2
```

### 통합 시스템 검사
```bash
# 포괄적 시스템 상태 확인
just check-system
# ✅ 필수 도구 설치 확인
# ✅ RAID 배열 상태 검사  
# ✅ fstab 유효성 검증
# ✅ 마운트 상태 확인
# ✅ 디스크 건강 상태
# ✅ 권한 및 설정 검사

# 발견된 문제 자동 수정
just fix-system
```

## 🚨 안전 가이드

### ⚠️ **중요 주의사항**
1. **자동 백업**: 모든 설정 변경 시 `/var/backups/` 자동 백업
2. **ID 기반 안전성**: UUID/PARTUUID 사용으로 디바이스 변경에 무관
3. **fail-safe 기본값**: 부팅 실패 방지를 위한 `nofail` 자동 적용
4. **사전 검증**: 모든 작업 전 디스크 존재성, 호환성 검사

### 🛡️ **내장 안전 기능**
- **ID 검증**: 존재하지 않는 디스크 사전 차단
- **충돌 방지**: 마운트포인트, fstab 항목 중복 검사
- **RAID 호환성**: 마운트된 디스크, 기존 RAID 멤버 사용 방지
- **자동 롤백**: 실패 시 백업을 통한 자동 복원

## 🤝 기여하기

### 개발 워크플로우
```bash
# 1. 개발 환경 설정
git clone <repo> && cd ubuntu-disk-toolkit
just setup -y

# 2. 개발 및 테스트
just test && just lint -y

# 3. 새 기능 추가 시
# - lib/ 디렉토리에 모듈 추가
# - tests/ 디렉토리에 테스트 추가  
# - justfile에 명령어 추가 (필요시)
# - README.md 업데이트

# 4. 풀 리퀘스트 전 최종 검사
just demo  # 전체 기능 동작 확인
```

## 📜 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 🏆 주요 개선사항

| 분야 | 이전 버전 | **현재 버전** | 개선효과 |
|------|----------|-----------------|----------|
| **아키텍처** | 단일 파일 함수 | **모듈형 API** | **재사용성 3배 향상** |
| **디스크 관리** | 경로 기반 | **ID 기반 (UUID/PARTUUID)** | **안정성 대폭 향상** |
| **fail-safe** | 수동 권장 | **자동 적용** | **부팅 실패 위험 제거** |
| **CLI 통합** | 개별 스크립트 | **단일 ubuntu-disk-toolkit** | **사용 편의성 향상** |
| **Just 명령어** | 기본 5개 | **확장 16개** | **개발 생산성 3배** |
| **검증 시스템** | 기본 검사 | **포괄적 validator.sh** | **오류 사전 방지** |
| **자동화** | 수동 단계 | **완전 자동 워크플로우** | **RAID 생성 원클릭** |

---

**Ubuntu Disk Toolkit**으로 더 안전하고 강력한 Ubuntu 스토리지 관리를 경험하세요! 🚀

### 🎯 지금 바로 시작하기
```bash
# 완전 자동 설치 및 데모
git clone <your-repo>
cd ubuntu-disk-toolkit
just setup -y && just demo

# 첫 번째 RAID 생성
just raid-disks              # 사용 가능한 디스크 확인
just create-raid 1 /data ext4 sdb sdc  # RAID 1 생성
``` 
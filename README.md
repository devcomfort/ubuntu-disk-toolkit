# Ubuntu Disk Toolkit

> 🚀 **Ubuntu 시스템용 통합 스토리지 관리 도구 - Pure Bash 구현**

Ubuntu 환경에서 디스크, RAID, fstab을 통합 관리하는 포괄적이고 사용자 친화적인 CLI 도구입니다. Python 의존성을 완전히 제거하고 순수 bash로 구현하여 더 빠르고 안정적인 시스템 통합을 제공합니다.

## ✨ 주요 특징

### 🎯 **완전한 스토리지 라이프사이클 관리**
- **RAID 관리**: RAID 0, 1, 5, 6 지원 + 자동 파일시스템 생성
- **디스크 관리**: mount/umount, 디스크 정보 조회, SMART 상태 확인
- **fstab 관리**: 분석, 추가, 제거, 검증, 백업
- **종합 진단**: 기존 `check_disk_health.sh` 기반 확장된 건강 분석

### 🛡️ **안전성 우선 설계**
- **Fail-safe 마운트**: 부팅 실패 방지를 위한 `nofail` 옵션 자동 권장
- **자동 백업**: fstab, mdadm.conf 수정 시 자동 백업 생성
- **권한 관리**: sudo 권한 필요성 검사 및 안전한 권한 상승 안내
- **테스트 마운트**: fstab 변경 전 안전성 검증

### 🎨 **사용자 친화적 인터페이스**
- **Interactive 모드**: 단계별 안내로 안전한 작업 수행
- **하이브리드 지원**: CLI 명령어와 Interactive 모드 동시 지원
- **다중 출력**: table, detailed, JSON 형식 지원
- **컬러 UI**: 상태별 색상 코딩과 직관적 아이콘

### ⚡ **시스템 네이티브 통합**
- **제로 의존성**: Python 없이 순수 bash + 시스템 도구만 사용
- **직접 연동**: `mdadm`, `lsblk`, `smartctl` 등과 직접 통신
- **systemd 지원**: 자동 모니터링 및 부팅 시 초기화
- **즉시 배포**: 스크립트 복사만으로 완전한 설치

## 📋 시스템 요구사항

### 지원 운영체제
- Ubuntu 18.04 LTS 이상
- Debian 10 이상
- 기타 Debian 계열 배포판

### 필수 패키지
```bash
# 자동 설치 확인 및 설치 안내 제공
sudo apt update && sudo apt install -y \
    mdadm \
    smartmontools \
    util-linux \
    parted \
    e2fsprogs
```

## 🚀 빠른 시작

### 1. 저장소 클론
```bash
git clone <repository-url>
cd ubuntu-disk-toolkit
```

### 2. 의존성 설치
```bash
# 🎯 방법 1: Just를 이용한 자동 설치 (권장)
./install/install-deps.sh --dev
just setup

# 🔧 방법 2: 수동 의존성 설치
sudo ./install/install-deps.sh
chmod +x bin/* tests/run-tests.sh install/*.sh

# 📋 방법 3: 확인만 (설치하지 않음)
./install/install-deps.sh --check-only
```

### 3. 시스템 설치
```bash
# 자동 설치
sudo ./install/install.sh

# 또는 Just 사용
just install
```

### 4. 현재 상태 확인
```bash
# 시스템 호환성 및 필수 도구 확인
ubuntu-disk-toolkit check-system --auto-install

# 디스크 상태 확인
ubuntu-disk-toolkit list-disks

# RAID 배열 상태
ubuntu-disk-toolkit list-raids --detailed

# 종합 건강 진단
sudo ubuntu-disk-toolkit analyze-health
```

## 🛠️ 개발 및 빌드 시스템

### Just를 이용한 개발 워크플로우
```bash
# 📦 개발 환경 완전 설정
just setup                    # 의존성 설치 + 권한 설정

# 🧪 테스트 실행
just test                     # 전체 테스트
just test-verbose             # 상세 출력
just test-parallel            # 병렬 실행
just test-file test_common.bats  # 특정 테스트

# 🔍 코드 품질 검사
just lint                     # shellcheck 검사
just lint-install             # shellcheck 설치

# 🚀 기능 테스트
just demo                     # 데모 실행
just help                     # CLI 도움말
just info                     # 시스템 정보
just disks                    # 디스크 목록

# 🏗️ 설치 및 패키징
just install                  # 프로덕션 설치
just install-dev              # 개발 모드 설치
just package                  # 배포 패키지 생성
just verify-release           # 릴리스 검증

# 🧹 정리 및 유지보수
just clean                    # 임시 파일 정리
just status                   # 프로젝트 상태
just dev-guide                # 개발 가이드
```

### 개발자용 명령어
```bash
# 개발 환경 상태 확인
just status

# 프로젝트 정보 표시
# 📁 프로젝트: ubuntu-disk-toolkit
# 📂 경로: /path/to/project
# 🔧 스크립트: 5개
# 📚 라이브러리: 6개
# 🧪 테스트: 5개
# 💾 크기: 2.1M

# 트러블슈팅
just check-system             # 시스템 호환성 검사
just fix-permissions          # 권한 문제 해결
just reinstall-deps           # 의존성 재설치
```

## 📖 사용법

### 🔧 **시스템 관리**
```bash
# 시스템 검사 및 설정
ubuntu-disk-toolkit check-system               # 전체 검사
ubuntu-disk-toolkit check-system info          # 시스템 정보
ubuntu-disk-toolkit check-system requirements  # 필수 도구 확인
ubuntu-disk-toolkit check-system setup         # 자동 설정
```

### 💾 **디스크 관리**
```bash
# 디스크 목록 및 상태
ubuntu-disk-toolkit manage-disk list --all     # 모든 디스크
ubuntu-disk-toolkit manage-disk info           # Interactive 정보 조회

# 마운트 관리 (Interactive)
ubuntu-disk-toolkit manage-disk mount          # 단계별 마운트
ubuntu-disk-toolkit manage-disk umount         # 안전한 언마운트
```

### 📄 **fstab 관리**
```bash
# fstab 분석 및 관리
ubuntu-disk-toolkit manage-fstab list          # 현재 설정 확인
ubuntu-disk-toolkit manage-fstab add           # Interactive 항목 추가
ubuntu-disk-toolkit manage-fstab validate      # 설정 검증
ubuntu-disk-toolkit manage-fstab backup        # 안전 백업
```

### ⚡ **RAID 관리**
```bash
# RAID 생성 (Interactive)
ubuntu-disk-toolkit setup-raid

# 명령줄 모드
ubuntu-disk-toolkit setup-raid --level 1 --disks /dev/sdb,/dev/sdc --mount /mnt/raid1

# RAID 상태 확인
ubuntu-disk-toolkit list-raids
ubuntu-disk-toolkit check-raids                # 상세 상태
```

### 🔍 **진단 도구**
```bash
# 기본 상태 확인
ubuntu-disk-toolkit check

# 종합 건강 진단 (root 필요)
sudo ubuntu-disk-toolkit analyze-health
```

## 🧪 테스트

### bats 기반 테스트 시스템
```bash
# bats 설치 (자동 설치됨)
sudo apt install bats

# 또는 개발 환경 설정으로
just setup

# 테스트 실행
just test                    # 전체 테스트
just test-verbose           # 상세 + 색상 출력
just test-parallel          # 병렬 실행 (4 jobs)
just test-file test_common.bats   # 특정 테스트
just test-tap               # TAP 형식 출력
```

### 테스트 구조
```
tests/
├── test_helpers.bash      # 공통 헬퍼 함수 (Mock 시스템 포함)
├── test_common.bats       # 공통 함수 테스트
├── test_system.bats       # 시스템 검사 테스트
├── test_fstab.bats        # fstab 관리 테스트
├── test_disk.bats         # 디스크 관리 테스트
├── test_integration.bats  # 통합 테스트
└── run-tests.sh           # 테스트 실행기
```

## 📁 프로젝트 구조

```
ubuntu-disk-toolkit/
├── 📋 README.md              # 프로젝트 개요
├── 🛠️ justfile              # 빌드 도구 (개발 워크플로우)
├── 📝 docs/
│   └── FEATURES.md           # 구현 기능 상세
├── 🎯 bin/                   # 실행 스크립트
│   ├── ubuntu-disk-toolkit   # 메인 CLI
│   ├── check-system          # 시스템 검사
│   ├── manage-disk           # 디스크 관리
│   ├── manage-fstab          # fstab 관리
│   └── check-disk-health     # 종합 진단
├── 📚 lib/                   # 함수 라이브러리
│   ├── common.sh             # 공통 유틸리티
│   ├── ui-functions.sh       # UI/출력 함수
│   ├── system-functions.sh   # 시스템 검사
│   ├── disk-functions.sh     # 디스크 관리
│   ├── fstab-functions.sh    # fstab 관리
│   └── raid-functions.sh     # RAID 관리
├── ⚙️ config/
│   └── defaults.conf         # 기본 설정
├── 🚀 install/
│   ├── install.sh            # 시스템 설치
│   ├── install-deps.sh       # 의존성 설치
│   └── uninstall.sh          # 완전 제거
└── 🧪 tests/                 # bats 테스트 시스템
    ├── test_*.bats           # 테스트 파일들
    ├── test_helpers.bash     # 테스트 헬퍼 (Mock 포함)
    └── run-tests.sh          # 테스트 실행기
```

## 🔧 고급 기능

### 자동화 및 모니터링
```bash
# systemd 서비스 (자동 설치됨)
systemctl status ubuntu-disk-toolkit-monitor
systemctl status ubuntu-disk-toolkit-health-check

# 로그 확인
journalctl -u ubuntu-disk-toolkit-monitor -f
tail -f /var/log/ubuntu-disk-toolkit.log
```

### 설정 커스터마이징
```bash
# 설정 파일 편집
sudo nano /etc/ubuntu-disk-toolkit/defaults.conf

# 사용자별 설정 오버라이드
mkdir -p ~/.config/ubuntu-disk-toolkit/
cp /etc/ubuntu-disk-toolkit/defaults.conf ~/.config/ubuntu-disk-toolkit/
```

### JSON API 모드
```bash
# 자동화를 위한 JSON 출력
ubuntu-disk-toolkit check-system info --format json | jq .
ubuntu-disk-toolkit manage-fstab list --format json | jq '.entries[]'
```

## 🚨 안전 가이드

### ⚠️ **중요 주의사항**
1. **백업 필수**: RAID 작업 전 중요 데이터 백업
2. **권한 관리**: 필요한 경우에만 sudo 사용
3. **테스트 환경**: 프로덕션 적용 전 테스트 시스템에서 검증
4. **설정 검증**: fstab 변경 후 반드시 테스트 마운트 실행

### 🛡️ **내장 안전 기능**
- **자동 백업**: 모든 설정 변경 시 타임스탬프 백업
- **Fail-safe 옵션**: 부팅 실패 방지 마운트 옵션
- **권한 검사**: 위험한 작업 시 명시적 사용자 확인
- **롤백 지원**: 백업을 통한 설정 복원 가능

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### 개발 가이드
```bash
# 개발 환경 설정
just setup

# 개발 워크플로우
just test && just lint && just demo

# 코드 품질 검사
shellcheck bin/* lib/*

# 새 기능 추가 시 테스트 작성 필수
just test-file tests/new_feature.bats
```

## 📜 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 🏆 성과 요약

| 지표 | Python 버전 | **Bash 버전** | 개선율 |
|------|-------------|---------------|--------|
| **프로젝트명** | ubuntu-raid-cli | **ubuntu-disk-toolkit** | **범위 확장** |
| **코드량** | 1,200줄 | **~800줄** | **33% 감소** |
| **의존성** | 4개 라이브러리 | **0개** | **100% 제거** |
| **배포** | 빌드 + 패키징 | **스크립트 복사** | **즉시 사용** |
| **기능 범위** | RAID 중심 | **스토리지 통합** | **3배 확장** |
| **통합성** | subprocess | **네이티브** | **완벽 연동** |
| **개발 도구** | 없음 | **Justfile** | **워크플로우 자동화** |
| **구조** | 중첩 디렉토리 | **직접 접근** | **경로 단순화** |

---

**Ubuntu Disk Toolkit**으로 더 안전하고 강력한 Ubuntu 스토리지 관리를 경험하세요! 🚀

### 🎯 다음 단계
```bash
# 바로 시작하기
git clone <your-repo>
cd ubuntu-disk-toolkit
just setup
just demo
``` 
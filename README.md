# Ubuntu RAID CLI

Ubuntu 시스템에서 RAID 설정을 간편하게 관리하기 위한 CLI 도구입니다.

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.8+-blue.svg" alt="Python 3.8+"/>
  <img src="https://img.shields.io/badge/OS-Ubuntu%2020.04+-orange.svg" alt="Ubuntu 20.04+"/>
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT"/>
</p>

## 목차

- [일반 사용자 가이드](#일반-사용자-가이드)
  - [주요 기능](#주요-기능)
  - [설치 방법](#설치-방법)
  - [기본 사용법](#기본-사용법)
  - [사용 예시](#사용-예시)
  - [주의사항](#주의사항)
- [개발자 가이드](#개발자-가이드)
  - [개발 환경 설정](#개발-환경-설정)
  - [프로젝트 구조](#프로젝트-구조)
  - [빌드 방법](#빌드-방법)
    - [독립 실행형(Standalone) 빌드](#독립-실행형standalone-빌드)
  - [테스트](#테스트)
  - [기여 방법](#기여-방법)
- [라이선스](#라이선스)

---

# 일반 사용자 가이드

## 주요 기능

- **디스크 관리**: 시스템의 모든 디스크 목록 확인 및 상태 관리
- **RAID 설정**: RAID 0, 1, 5, 6 배열 생성 및 관리
- **자동 추천**: 디스크 수와 크기에 따른 최적의 RAID 레벨 추천
- **마운트 관리**: RAID 및 디스크의 마운트 위치 설정 및 변경
- **상태 모니터링**: 디스크 및 RAID 배열의 건강 상태 실시간 확인
- **파일 시스템 관리**: 장치 포맷, 마운트, 언마운트 등의 관리 기능

## 설치 방법

### 원클릭 설치 (권장)

```bash
# 스크립트 실행 권한 부여
chmod +x scripts/setup_all.sh

# 설치 스크립트 실행 (root 권한 필요)
sudo ./scripts/setup_all.sh
```

이 스크립트는 모든 필요한 시스템 패키지를 설치하고, Rye를 통해 프로젝트를 빌드한 후 시스템에 설치합니다.

### GitHub CDN을 통한 빠른 설치

```bash
# 설치 스크립트 다운로드 및 실행
curl -s https://raw.githubusercontent.com/devcomfort/ubuntu-raid-cli/main/scripts/install.sh | sudo bash
```

또는 wget을 사용하는 경우:
```bash
wget -qO- https://raw.githubusercontent.com/devcomfort/ubuntu-raid-cli/main/scripts/install.sh | sudo bash
```

이 방법은 GitHub CDN을 통해 최신 설치 스크립트를 다운로드하고 실행합니다. 설치 과정에서 pip를 통한 설치와 바이너리 설치 중 선택할 수 있습니다.

### 독립 실행형(Standalone) 배포판 설치

독립 실행형 배포판은 특별한 개발 환경 없이도 설치할 수 있는 패키지입니다:

```bash
# 배포 패키지 압축 해제
tar -xzvf ubuntu-raid-cli-standalone.tar.gz

# 설치 스크립트 실행 (root 권한 필요)
sudo ./install.sh
```

이 방법은 개발 환경 없이 바로 실행 파일을 시스템에 설치합니다.

### 단계별 수동 설치

시스템 패키지 설치:
```bash
sudo apt-get update
sudo apt-get install -y mdadm smartmontools python3-pip python3-venv
```

Rye 설치 (Python 패키지 관리자):
```bash
curl -sSf https://rye.astral.sh/get | bash
source ~/.bashrc  # 또는 쉘 재시작
```

프로젝트 빌드 및 설치:
```bash
# 프로젝트 루트 디렉토리에서
chmod +x scripts/build.sh
./scripts/build.sh
sudo chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

## 기본 사용법

설치 후 `raid` 명령어를 사용하여 도구를 실행할 수 있습니다:

```bash
# 도움말 표시
raid --help

# 디스크 목록 확인
raid list-disks

# RAID 배열 목록 확인
raid list-raids

# RAID 설정 (대화형)
raid setup-raid

# 상태 확인
raid check
```

독립 실행형 배포판을 사용한 경우 `raid-cli` 명령어를 사용합니다:

```bash
# 도움말 표시
raid-cli --help

# 디스크 목록 확인
raid-cli list-disks
```

## 사용 예시

### RAID 5 배열 생성

```bash
# 대화형으로 RAID 5 설정
raid setup-raid --level 5 --device /dev/md0 --mount /mnt/raid5
```

### 디스크 상태 확인

```bash
# 전체 디스크 상태 확인
raid check

# 특정 디스크 확인
raid check --device /dev/sda
```

### 포맷 및 마운트

```bash
# 장치 포맷
raid format-device

# 장치 마운트
raid mount-device
```

## 주의사항

- **데이터 손실 위험**: RAID 설정은 디스크의 모든 데이터를 삭제합니다. 중요한 데이터는 미리 백업하세요.
- **권한 요구사항**: 대부분의 RAID 관련 작업은 root 권한이 필요합니다.
- **RAID 레벨별 최소 디스크 수**:
  - RAID 0: 2개 이상 (데이터 보호 없음, 성능 향상)
  - RAID 1: 2개 이상 (미러링, 50% 용량 효율)
  - RAID 5: 3개 이상 (패리티, 1개 디스크 장애 허용)
  - RAID 6: 4개 이상 (이중 패리티, 2개 디스크 장애 허용)
- **하드웨어 호환성**: 모든 디스크가 SMART 기능을 지원하지 않을 수 있습니다.
- **경고 사항**: 비정상적인 SMART 값이 발견되면 즉시 데이터를 백업하고 디스크 교체를 고려하세요.

---

# 개발자 가이드

## 개발 환경 설정

### 필수 요구사항

- Python 3.8 이상
- Rye 패키지 관리자
- mdadm, smartmontools 패키지

### 개발 환경 구성

```bash
# 프로젝트 클론
git clone https://github.com/devcomfort/ubuntu-raid-cli.git
cd ubuntu-raid-cli

# Rye로 개발 환경 구성
rye sync --dev
```

## 프로젝트 구조

```
ubuntu-raid-cli/
├── dist/                  # 빌드된 패키지 파일
├── scripts/               # 설치 및 유틸리티 스크립트
│   ├── build.sh           # 빌드 스크립트
│   ├── install.sh         # 설치 스크립트
│   ├── setup_all.sh       # 통합 설치 스크립트
│   └── standalone_build.sh # 독립 실행형 빌드 스크립트
├── src/
│   └── ubuntu_raid_cli/   # 소스 코드
│       ├── __init__.py
│       ├── cli.py         # CLI 인터페이스
│       ├── main.py        # 메인 진입점
│       ├── raid_manager.py # RAID 관리 기능
│       └── utils.py       # 유틸리티 함수
├── pyproject.toml         # 프로젝트 설정
└── README.md              # 문서
```

## 빌드 방법

Rye를 사용한 빌드:

```bash
# 개발 의존성 포함 동기화
rye sync --dev

# 프로젝트 빌드
rye build
```

빌드 스크립트 사용:

```bash
chmod +x scripts/build.sh
./scripts/build.sh
```

빌드된 패키지는 `dist/` 디렉토리에 생성됩니다.

### 독립 실행형(Standalone) 빌드

PyInstaller를 사용하여 독립 실행형 실행 파일을 생성합니다:

```bash
# 스크립트 실행 권한 부여
chmod +x scripts/standalone_build.sh

# 빌드 실행
./scripts/standalone_build.sh
```

이 스크립트는 다음 과정을 자동화합니다:

1. 가상환경 생성 및 의존성 설치
2. PyInstaller를 사용한 독립 실행형(standalone) 실행 파일 생성
3. 설치 스크립트가 포함된 배포 패키지(.tar.gz) 생성

생성된 배포 패키지는 `release/ubuntu-raid-cli-standalone.tar.gz`에 저장됩니다.

독립 실행형 빌드의 장점:
- Python 환경 없이도 실행 가능
- 모든 의존성 패키지가 단일 실행 파일에 포함됨
- 별도의 개발 환경 없이 대상 시스템에 쉽게 배포 가능

대상 시스템에 설치:
```bash
tar -xzvf ubuntu-raid-cli-standalone.tar.gz
sudo ./install.sh
```

## 테스트

테스트 실행:

```bash
# 모든 테스트 실행
pytest

# 특정 테스트 실행
pytest tests/test_raid_manager.py
```

## 기여 방법

1. 이슈 확인 또는 새 이슈 생성
2. 프로젝트 포크
3. 기능/버그 수정 브랜치 생성 (`git checkout -b feature/amazing-feature`)
4. 변경사항 커밋 (`git commit -m 'Add amazing feature'`)
5. 원격 저장소에 푸시 (`git push origin feature/amazing-feature`)
6. Pull Request 생성

코드 스타일은 Black과 isort를 따릅니다:
```bash
# 코드 포맷팅
black src/
isort src/

# 타입 체크
mypy src/
```

---

# 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

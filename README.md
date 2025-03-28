# Ubuntu RAID CLI

Ubuntu 시스템에서 RAID 설정을 관리하기 위한 CLI 도구입니다.

## 기능

- 디스크 목록 확인
- RAID 배열 설정 (RAID 0, 1, 5, 6 지원)
- RAID 배열 제거
- RAID 마운트 포인트 변경
- RAID 상태 확인
- RAID 그룹 관리
- RAID 그룹 상태 확인
- RAID 디스크 상태 모니터링
- 디스크 건강 상태 확인

## 요구사항

- Ubuntu 20.04 이상
- Python 3.8 이상
- `mdadm` 패키지
- `parted` 패키지
- `smartmontools` 패키지

## 설치 방법

### 1. 자동 설치 (권장)

```bash
# 스크립트 실행 권한 부여
chmod +x scripts/setup.sh

# 설치 스크립트 실행
sudo ./scripts/setup.sh
```

### 2. 수동 설치

필요한 경우 아래 명령어로 개별적으로 설치할 수 있습니다:

```bash
# 시스템 패키지 설치
sudo apt-get update
sudo apt-get install -y mdadm smartmontools python3-pip python3-venv

# Rye 설치 (Python 패키지 관리자)
curl -sSf https://rye.astral.sh/get | bash

# Python 의존성 설치
rye sync
```

이 설치 스크립트는 다음과 같은 기능을 제공합니다:

1. root 권한 확인
2. 필요한 시스템 패키지 자동 설치:
   - mdadm (RAID 관리)
   - smartmontools (디스크 건강 상태 확인)
   - python3-pip
   - python3-venv
3. Python 의존성 자동 설치
4. 컬러 로깅으로 설치 진행 상황 표시
5. 오류 처리 및 이미 설치된 패키지 확인

스크립트를 실행하기 전에 실행 권한을 부여해야 합니다:
```bash
chmod +x scripts/setup.sh
```

이렇게 하면 사용자가 한 번의 명령어로 모든 필요한 패키지를 설치할 수 있습니다.

## 사용법

### 디스크 목록 확인

```bash
raid-cli list-disks
```

### RAID 배열 목록 확인

```bash
raid-cli list-raids
```

### RAID 배열 설정

```bash
raid-cli setup-raid
```

또는 옵션을 직접 지정:

```bash
raid-cli setup-raid --level 5 --device /dev/md0 --mount /mnt/raid
```

### RAID 배열 제거

```bash
raid-cli remove-raid /dev/md0
```

### 마운트 포인트 변경

```bash
raid-cli change-mount
```

### RAID 관리

```bash
# RAID 그룹 목록 확인
raid list

# RAID 상태 확인
raid status /dev/md0
```

### 디스크 건강 상태 확인

```bash
# 모든 디스크 및 RAID 디바이스 상태 확인
raid check

# 특정 디바이스만 확인
raid check --device /dev/sda
```

### 디스크 및 RAID 관리

```bash
# 장치 포맷
raid format-device

# 장치 마운트
raid mount-device

# 장치 언마운트
raid unmount-device
```

각 명령어는 대화형 인터페이스를 제공합니다:
- 사용 가능한 장치 목록 표시
- 장치 선택
- 필요한 경우 추가 정보 입력 (마운트 위치, 파일시스템 유형 등)
- fstab 자동 업데이트 옵션

## 주의사항

- RAID 설정은 디스크의 모든 데이터를 삭제합니다. 설정 전에 데이터를 백업하세요.
- RAID 설정은 root 권한이 필요합니다.
- RAID 레벨별 최소 디스크 요구사항:
  - RAID 0: 2개 이상
  - RAID 1: 2개 이상
  - RAID 5: 3개 이상
  - RAID 6: 4개 이상
- 모든 디스크가 SMART 기능을 지원하지는 않을 수 있습니다.
- 비정상적인 SMART 값이 발견되면 즉시 데이터 백업을 권장합니다.

## 라이선스

MIT License

## 기여하기

[기여 방법 안내]

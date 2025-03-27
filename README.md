# Ubuntu RAID CLI

Ubuntu 시스템에서 RAID 설정을 관리하기 위한 CLI 도구입니다.

## 기능

- 디스크 목록 확인
- RAID 배열 설정 (RAID 0, 1, 5, 6 지원)
- RAID 배열 제거
- RAID 마운트 포인트 변경
- RAID 상태 확인

## 요구사항

- Ubuntu 20.04 이상
- Python 3.8 이상
- `mdadm` 패키지
- `parted` 패키지

## 설치

1. 필요한 시스템 패키지 설치:

```bash
sudo apt-get update
sudo apt-get install mdadm parted
```

2. Python 패키지 설치:

```bash
pip install -e .
```

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
raid-cli change-mount /dev/md0 /mnt/new_location
```

## 주의사항

- RAID 설정은 디스크의 모든 데이터를 삭제합니다. 설정 전에 데이터를 백업하세요.
- RAID 설정은 root 권한이 필요합니다.
- RAID 레벨별 최소 디스크 요구사항:
  - RAID 0: 2개 이상
  - RAID 1: 2개 이상
  - RAID 5: 3개 이상
  - RAID 6: 4개 이상

## 라이선스

MIT License

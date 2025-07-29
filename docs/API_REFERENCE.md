# Ubuntu Disk Toolkit - API Reference

## 📖 개요

Ubuntu Disk Toolkit의 모든 공개 API를 계층별로 정리한 참조 문서입니다. 각 함수의 사용법, 매개변수, 반환값, 예제를 포함합니다.

## 🏗️ Layer 0: Foundation APIs

### core.sh

#### `init_environment()`
시스템 환경을 초기화합니다.

**사용법:**
```bash
init_environment
```

**반환값:**
- `0`: 성공
- `1`: 실패

**예제:**
```bash
source lib/foundation/core.sh
init_environment || exit 1
```

#### `setup_directories()`
필요한 디렉토리 구조를 생성합니다.

**사용법:**
```bash
setup_directories
```

**생성되는 디렉토리:**
- `$LOG_DIR`
- `$CONFIG_DIR`
- `$TEMP_DIR`

### logging.sh

#### `log_info(message)`
정보 메시지를 로그에 기록합니다.

**매개변수:**
- `message`: 로그 메시지

**사용법:**
```bash
log_info "디스크 스캔을 시작합니다"
```

#### `log_error(message)`
오류 메시지를 로그에 기록합니다.

**매개변수:**
- `message`: 오류 메시지

**사용법:**
```bash
log_error "디스크를 찾을 수 없습니다: /dev/sdb"
```

#### `log_debug(message)`
디버그 메시지를 로그에 기록합니다 (DEBUG_MODE=true일 때만).

**매개변수:**
- `message`: 디버그 메시지

**사용법:**
```bash
DEBUG_MODE=true log_debug "함수 진입점: get_disk_info"
```

### config.sh

#### `load_config(config_file)`
설정 파일을 로드합니다.

**매개변수:**
- `config_file`: 설정 파일 경로

**반환값:**
- `0`: 성공
- `1`: 파일이 존재하지 않음

**사용법:**
```bash
load_config "/etc/ubuntu-disk-toolkit/custom.conf"
```

#### `save_config(key, value, config_file)`
설정을 파일에 저장합니다.

**매개변수:**
- `key`: 설정 키
- `value`: 설정 값
- `config_file`: 설정 파일 경로

**사용법:**
```bash
save_config "DEFAULT_FILESYSTEM" "ext4" "$CONFIG_FILE"
```

## 🛠️ Layer 1: Utilities APIs

### shell.sh

#### `safe_execute(command, [description])`
안전한 명령어 실행 (테스트 모드 지원).

**매개변수:**
- `command`: 실행할 명령어
- `description`: 작업 설명 (선택사항)

**반환값:**
- 명령어의 exit code

**환경변수:**
- `TESTING_MODE`: true시 위험한 명령어 모킹
- `DRY_RUN`: true시 실제 실행하지 않음

**사용법:**
```bash
safe_execute "parted -s /dev/sdb mkpart primary 0% 100%" "파티션 생성"
```

**테스트 모드:**
```bash
export TESTING_MODE=true
safe_execute "mkfs.ext4 /dev/sdb1" "파일시스템 생성"
# 출력: [MOCK] 파일시스템 생성 시뮬레이션 완료
```

#### `confirm_action(message, [default])`
사용자 확인을 요청합니다.

**매개변수:**
- `message`: 확인 메시지
- `default`: 기본값 (y/n, 기본값: n)

**반환값:**
- `0`: 사용자가 승인
- `1`: 사용자가 거부

**환경변수:**
- `AUTO_CONFIRM`: true시 자동으로 승인

**사용법:**
```bash
if confirm_action "정말 디스크를 포맷하시겠습니까?"; then
    format_disk "$device"
fi
```

### ui.sh

#### `table_start()`
테이블 출력을 시작합니다.

**사용법:**
```bash
table_start
table_row "디바이스" "크기" "타입"
table_row "/dev/sda" "500GB" "HDD"
table_end
```

#### `table_row(col1, col2, col3)`
테이블 행을 출력합니다.

**매개변수:**
- `col1`, `col2`, `col3`: 각 열의 내용

#### `table_end()`
테이블 출력을 종료합니다.

#### `show_progress(current, total, message)`
진행률 표시줄을 출력합니다.

**매개변수:**
- `current`: 현재 진행률
- `total`: 전체 작업량
- `message`: 진행 메시지

**사용법:**
```bash
for i in {1..100}; do
    show_progress "$i" "100" "파일 복사 중"
    sleep 0.1
done
echo  # 줄바꿈
```

### validation.sh

#### `validate_device(device)`
디바이스가 존재하는지 검증합니다.

**매개변수:**
- `device`: 디바이스 경로

**반환값:**
- `0`: 디바이스 존재
- `1`: 디바이스 없음

**사용법:**
```bash
if validate_device "/dev/sdb"; then
    echo "디바이스가 존재합니다"
fi
```

#### `validate_mountpoint(mountpoint)`
마운트포인트가 유효한지 검증합니다.

**매개변수:**
- `mountpoint`: 마운트포인트 경로

**반환값:**
- `0`: 유효함
- `1`: 유효하지 않음

**사용법:**
```bash
validate_mountpoint "/mnt/data" || {
    echo "유효하지 않은 마운트포인트입니다"
    exit 1
}
```

## 🖥️ Layer 2: System APIs

### disk.sh

#### `get_all_disks()`
시스템의 모든 디스크를 나열합니다.

**반환값:**
- 표준출력으로 디스크 목록 (NAME SIZE TYPE 형식)

**사용법:**
```bash
get_all_disks
# 출력:
# sda 500G disk
# sdb 1T disk
```

#### `get_disk_info(device)`
디스크의 상세 정보를 조회합니다.

**매개변수:**
- `device`: 디바이스 경로

**반환값:**
- 표준출력으로 디스크 정보

**사용법:**
```bash
get_disk_info "/dev/sda"
# 출력:
# Device: /dev/sda
# Size: 500G
# Model: Samsung SSD 980
# Serial: S649NJ0R123456
```

#### `is_disk_mounted(device)`
디스크가 마운트되어 있는지 확인합니다.

**매개변수:**
- `device`: 디바이스 경로

**반환값:**
- `0`: 마운트됨
- `1`: 마운트되지 않음

**사용법:**
```bash
if is_disk_mounted "/dev/sda1"; then
    echo "마운트되어 있습니다"
fi
```

### mount.sh

#### `mount_device(device, mountpoint, [options])`
디바이스를 마운트합니다.

**매개변수:**
- `device`: 디바이스 경로
- `mountpoint`: 마운트포인트
- `options`: 마운트 옵션 (기본값: defaults)

**반환값:**
- `0`: 마운트 성공
- `1`: 마운트 실패

**사용법:**
```bash
mount_device "/dev/sdb1" "/mnt/data" "defaults,noatime"
```

#### `unmount_device(target, [force])`
디바이스를 언마운트합니다.

**매개변수:**
- `target`: 디바이스 경로 또는 마운트포인트
- `force`: 강제 언마운트 여부 (true/false, 기본값: false)

**반환값:**
- `0`: 언마운트 성공
- `1`: 언마운트 실패

**사용법:**
```bash
unmount_device "/mnt/data"
unmount_device "/dev/sdb1" "true"  # 강제 언마운트
```

## ⚙️ Layer 3: Services APIs

### disk_service.sh

#### `disk_service_list_available([format])`
사용 가능한 디스크 목록을 조회합니다.

**매개변수:**
- `format`: 출력 형식 (table/json/simple, 기본값: table)

**반환값:**
- 표준출력으로 포맷된 디스크 목록

**사용법:**
```bash
# 테이블 형식
disk_service_list_available "table"

# JSON 형식
disk_service_list_available "json"
# 출력: {"disks":[{"name":"sda","size":"500G","type":"disk"}]}

# 단순 목록
disk_service_list_available "simple"
# 출력: sda sdb
```

#### `disk_service_analyze_health(device, [report_file])`
디스크 건강 상태를 분석합니다.

**매개변수:**
- `device`: 디바이스 경로
- `report_file`: 보고서 파일 경로 (선택사항)

**반환값:**
- 표준출력으로 보고서 파일 경로

**사용법:**
```bash
report_file=$(disk_service_analyze_health "/dev/sda")
cat "$report_file"
```

### raid_service.sh

#### `raid_service_create(raid_level, device1, device2, ...)`
RAID 배열을 생성합니다.

**매개변수:**
- `raid_level`: RAID 레벨 (0, 1, 5, 6, 10)
- `device1, device2, ...`: RAID에 사용할 디바이스들

**반환값:**
- 표준출력으로 생성된 RAID 디바이스 경로
- `0`: 생성 성공
- `1`: 생성 실패

**사용법:**
```bash
raid_device=$(raid_service_create "1" "/dev/sdb" "/dev/sdc")
echo "RAID 디바이스: $raid_device"  # /dev/md0
```

#### `raid_service_list_arrays([format])`
RAID 배열 목록을 조회합니다.

**매개변수:**
- `format`: 출력 형식 (table/json/simple, 기본값: table)

**사용법:**
```bash
raid_service_list_arrays "table"
```

#### `raid_service_remove(raid_device)`
RAID 배열을 제거합니다.

**매개변수:**
- `raid_device`: RAID 디바이스 경로

**반환값:**
- `0`: 제거 성공
- `1`: 제거 실패

**사용법:**
```bash
raid_service_remove "/dev/md0"
```

### fstab_service.sh

#### `fstab_service_add_entry(device, mountpoint, filesystem, [options])`
fstab에 항목을 추가합니다.

**매개변수:**
- `device`: 디바이스 경로
- `mountpoint`: 마운트포인트
- `filesystem`: 파일시스템 타입
- `options`: 마운트 옵션 (기본값: defaults)

**반환값:**
- `0`: 추가 성공
- `1`: 추가 실패

**안전 기능:**
- 자동 fail-safe 옵션 적용
- fstab 백업 생성
- UUID 기반 식별자 사용

**사용법:**
```bash
fstab_service_add_entry "/dev/sdb1" "/mnt/data" "ext4" "defaults,noatime"
```

#### `fstab_service_remove_entry(mountpoint)`
fstab에서 항목을 제거합니다.

**매개변수:**
- `mountpoint`: 제거할 마운트포인트

**반환값:**
- `0`: 제거 성공
- `1`: 제거 실패

**사용법:**
```bash
fstab_service_remove_entry "/mnt/data"
```

#### `fstab_service_list_entries([format])`
fstab 항목 목록을 조회합니다.

**매개변수:**
- `format`: 출력 형식 (table/json/simple, 기본값: table)

**사용법:**
```bash
fstab_service_list_entries "json"
```

#### `fstab_service_validate()`
fstab 파일의 유효성을 검사합니다.

**반환값:**
- `0`: 유효함
- `1`: 오류 발견

**사용법:**
```bash
if ! fstab_service_validate; then
    echo "fstab에 오류가 있습니다"
fi
```

## 🚀 Layer 4: Application APIs

### storage_api.sh

#### `storage_api_setup_raid_with_fstab(raid_level, mountpoint, [filesystem], device1, device2, ...)`
RAID 생성부터 fstab 등록까지 전체 워크플로우를 실행합니다.

**매개변수:**
- `raid_level`: RAID 레벨
- `mountpoint`: 마운트포인트
- `filesystem`: 파일시스템 (기본값: ext4)
- `device1, device2, ...`: RAID에 사용할 디바이스들

**반환값:**
- `0`: 전체 과정 성공
- `1`: 과정 중 실패

**진행 단계:**
1. RAID 배열 생성
2. 파일시스템 생성
3. 마운트포인트 생성
4. fstab 등록
5. 테스트 마운트

**사용법:**
```bash
storage_api_setup_raid_with_fstab "1" "/mnt/raid1" "ext4" "/dev/sdb" "/dev/sdc"
```

#### `storage_api_complete_disk_setup(device, mountpoint, [filesystem], [options])`
단일 디스크의 완전한 설정을 수행합니다.

**매개변수:**
- `device`: 디바이스 경로
- `mountpoint`: 마운트포인트
- `filesystem`: 파일시스템 (기본값: ext4)
- `options`: 마운트 옵션 (기본값: defaults,nofail)

**진행 단계:**
1. 디스크 유효성 검사
2. 파일시스템 생성
3. 마운트포인트 생성
4. fstab 등록
5. 테스트 마운트

**사용법:**
```bash
storage_api_complete_disk_setup "/dev/sdb1" "/mnt/data" "xfs" "defaults,noatime,nofail"
```

### analysis_api.sh

#### `analysis_api_comprehensive_report([output_file])`
종합 시스템 분석 보고서를 생성합니다.

**매개변수:**
- `output_file`: 출력 파일 경로 (기본값: /tmp/system_analysis_타임스탬프.html)

**반환값:**
- 표준출력으로 보고서 파일 경로

**포함 내용:**
- 시스템 정보
- 디스크 상태
- RAID 배열 정보
- fstab 구성
- 건강 상태 분석

**사용법:**
```bash
report_file=$(analysis_api_comprehensive_report "/tmp/my_report.html")
firefox "$report_file"  # 브라우저에서 보기
```

#### `analysis_api_disk_health_summary()`
모든 디스크의 건강 상태 요약을 생성합니다.

**반환값:**
- JSON 형식의 건강 상태 요약

**사용법:**
```bash
health_summary=$(analysis_api_disk_health_summary)
echo "$health_summary" | jq '.disks[0].health_status'
```

### automation_api.sh

#### `automation_api_auto_setup_storage([config_file])`
설정 파일을 기반으로 자동 스토리지 설정을 수행합니다.

**매개변수:**
- `config_file`: 설정 파일 경로 (기본값: /etc/ubuntu-disk-toolkit/auto-setup.conf)

**설정 파일 형식:**
```bash
# auto-setup.conf
RAID_LEVEL=1
RAID_DEVICES="/dev/sdb /dev/sdc"
MOUNTPOINT="/mnt/raid1"
FILESYSTEM="ext4"
OPTIONS="defaults,noatime,nofail"
```

**사용법:**
```bash
automation_api_auto_setup_storage "/path/to/config.conf"
```

## 📋 CLI 인터페이스 APIs

### ubuntu-disk-toolkit (메인 CLI)

#### 명령어 구조
```bash
ubuntu-disk-toolkit <category> <command> [options]
```

#### 카테고리
- `disk`: 디스크 관리
- `raid`: RAID 관리
- `fstab`: fstab 관리
- `system`: 시스템 관리
- `analyze`: 종합 분석

#### 예제
```bash
ubuntu-disk-toolkit disk list
ubuntu-disk-toolkit raid create --level 1 --devices "/dev/sdb /dev/sdc"
ubuntu-disk-toolkit fstab add --device /dev/sdb1 --mountpoint /mnt/data
ubuntu-disk-toolkit analyze --output /tmp/report.html
```

### udt-disk (디스크 전용 CLI)

#### 명령어
- `list [format]`: 사용 가능한 디스크 목록
- `info <device>`: 디스크 상세 정보
- `health <device>`: 건강 상태 분석
- `mount <device> <mountpoint>`: 마운트
- `unmount <target>`: 언마운트

#### 예제
```bash
udt-disk list table
udt-disk info /dev/sda
udt-disk mount /dev/sdb1 /mnt/data
```

### udt-raid (RAID 전용 CLI)

#### 명령어
- `list [format]`: RAID 배열 목록
- `create <level> <devices...>`: RAID 생성
- `remove <raid_device>`: RAID 제거
- `status <raid_device>`: 상태 확인

#### 예제
```bash
udt-raid list
udt-raid create 1 /dev/sdb /dev/sdc
udt-raid status /dev/md0
```

### udt-fstab (fstab 전용 CLI)

#### 명령어
- `list [format]`: fstab 항목 목록
- `add <device> <mountpoint> <filesystem>`: 항목 추가
- `remove <mountpoint>`: 항목 제거
- `validate`: 유효성 검사

#### 예제
```bash
udt-fstab list
udt-fstab add /dev/sdb1 /mnt/data ext4
udt-fstab validate
```

## 🔧 고급 사용법

### 배치 작업

#### 여러 디스크 동시 설정
```bash
#!/bin/bash
# setup_multiple_disks.sh

devices=("/dev/sdb" "/dev/sdc" "/dev/sdd")
mountpoints=("/mnt/data1" "/mnt/data2" "/mnt/data3")

for i in "${!devices[@]}"; do
    device="${devices[$i]}"
    mountpoint="${mountpoints[$i]}"
    
    echo "설정 중: $device -> $mountpoint"
    storage_api_complete_disk_setup "$device" "$mountpoint" "ext4"
done
```

#### RAID 자동 설정
```bash
#!/bin/bash
# auto_raid_setup.sh

# 사용 가능한 디스크 자동 탐지
available_disks=($(disk_service_list_available "simple"))

if [[ ${#available_disks[@]} -ge 2 ]]; then
    echo "RAID 1 설정: ${available_disks[0]}, ${available_disks[1]}"
    storage_api_setup_raid_with_fstab "1" "/mnt/raid1" "ext4" "${available_disks[0]}" "${available_disks[1]}"
else
    echo "RAID 설정을 위한 디스크가 부족합니다"
fi
```

### 에러 처리

#### 안전한 스크립트 작성
```bash
#!/bin/bash
set -euo pipefail  # 엄격한 에러 처리

# 로깅 활성화
export DEBUG_MODE=true

# 사전 검사
if ! validate_device "/dev/sdb"; then
    log_error "디바이스 /dev/sdb가 존재하지 않습니다"
    exit 1
fi

# 백업 생성
create_backup "/etc/fstab"

# 실제 작업
if fstab_service_add_entry "/dev/sdb1" "/mnt/data" "ext4"; then
    log_info "fstab 항목이 성공적으로 추가되었습니다"
else
    log_error "fstab 항목 추가에 실패했습니다"
    # 백업에서 복원
    restore_backup "/etc/fstab"
    exit 1
fi
```

### 테스트 모드

#### 안전한 테스트 실행
```bash
#!/bin/bash
# test_script.sh

# 테스트 모드 활성화
export TESTING_MODE=true
export DRY_RUN=true

# 위험한 명령어는 모킹됨
safe_execute "parted -s /dev/sdb mkpart primary 0% 100%"
# 출력: [MOCK] 파티션 생성 시뮬레이션 완료

safe_execute "mkfs.ext4 /dev/sdb1"
# 출력: [MOCK] 파일시스템 생성 시뮬레이션 완료
```

## 📊 성능 고려사항

### 캐싱 활용
```bash
# 디스크 정보 캐싱 활용
disk_info=$(get_disk_info_cached "/dev/sda")  # 5분간 캐시됨
```

### 병렬 처리
```bash
# 여러 디스크 병렬 분석
devices=("/dev/sda" "/dev/sdb" "/dev/sdc")
for device in "${devices[@]}"; do
    disk_service_analyze_health "$device" &
done
wait  # 모든 배경 작업 완료 대기
```

### Lazy Loading
```bash
# 필요할 때만 모듈 로드
ensure_loaded "services/raid_service"  # raid 기능 사용 전에만 로드
```

이 API 참조서를 통해 Ubuntu Disk Toolkit의 모든 기능을 효과적으로 활용할 수 있습니다.
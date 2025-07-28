#!/usr/bin/env bash

# ===================================================================================
# test_helpers.bash - bats 테스트용 공통 헬퍼 함수
# ===================================================================================

# 테스트 환경 설정
setup_test_environment() {
    # 프로젝트 루트 설정
    export BATS_PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PATH="${BATS_PROJECT_ROOT}/bin:${PATH}"
    
    # 테스트용 임시 디렉토리 설정
    export BATS_TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
    export TEST_TEMP_DIR="${BATS_TMPDIR}/bash-raid-cli-test-$$"
    
    # 테스트용 설정 파일 경로
    export TEST_CONFIG_DIR="${TEST_TEMP_DIR}/config"
    export TEST_FSTAB_FILE="${TEST_TEMP_DIR}/fstab"
    export TEST_MDADM_CONF="${TEST_TEMP_DIR}/mdadm.conf"
    
    # 임시 디렉토리 생성
    mkdir -p "${TEST_TEMP_DIR}" "${TEST_CONFIG_DIR}"
    
    # 테스트용 설정 파일 생성
    create_test_config
    create_test_fstab
    
    # 테스트용 로그 파일 설정
    export TEST_LOG_FILE="${TEST_TEMP_DIR}/test.log"
    export LOG_FILE="${TEST_LOG_FILE}"  # 비즈니스 로직에서 사용하는 LOG_FILE 오버라이드
    touch "${TEST_LOG_FILE}"
    
    # 색상 출력 비활성화 (테스트 시 ANSI 코드 제거)
    export NO_COLOR=1
    export TESTING_MODE=true
}

# 테스트 환경 정리
cleanup_test_environment() {
    # 임시 디렉토리 정리
    if [[ -d "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
    
    # 환경 변수 정리
    unset BATS_PROJECT_ROOT TEST_TEMP_DIR TEST_CONFIG_DIR 
    unset TEST_FSTAB_FILE TEST_MDADM_CONF NO_COLOR TESTING_MODE
}

# 테스트용 설정 파일 생성
create_test_config() {
    cat > "${TEST_CONFIG_DIR}/defaults.conf" << 'EOF'
# Test configuration for bash-raid-cli
FSTAB_PATH="/tmp/test-fstab"
LOG_LEVEL="INFO"
BACKUP_ENABLED=true
BACKUP_DIR="/tmp/test-backups"
RAID_DEFAULT_LEVEL="1"
DISK_CHECK_ENABLED=true
MONITORING_ENABLED=false
UI_COLOR_ENABLED=false
SAFETY_CHECKS_ENABLED=true
EOF
}

# 테스트용 fstab 생성
create_test_fstab() {
    cat > "${TEST_FSTAB_FILE}" << 'EOF'
# Test fstab file
UUID=12345678-1234-1234-1234-123456789abc / ext4 defaults 0 1
UUID=87654321-4321-4321-4321-cba987654321 /boot ext4 defaults 0 2
/dev/sdb1 /mnt/data ext4 defaults,nofail 0 2
/dev/sdc1 /mnt/backup xfs defaults,noauto 0 0
tmpfs /tmp tmpfs defaults,noatime 0 0
EOF
}

# Mock 시스템 명령어들
mock_lsblk() {
    cat << 'EOF'
NAME   SIZE   TYPE FSTYPE             MOUNTPOINT
sda    20G    disk                    
├─sda1 1G     part vfat               /boot/efi
├─sda2 2G     part ext4               /boot
└─sda3 17G    part ext4               /
sdb    10G    disk                    
└─sdb1 10G    part ext4               /mnt/data
sdc    10G    disk                    
└─sdc1 10G    part xfs                
sdd    10G    disk linux_raid_member  
sde    10G    disk linux_raid_member  
md0    20G    raid1 ext4              /mnt/raid
EOF
}

mock_mdadm_detail() {
    local device="${1:-/dev/md0}"
    cat << EOF
/dev/md0:
           Version : 1.2
     Creation Time : $(date)
        Raid Level : raid1
        Array Size : 20971520 (20.00 GiB 21.47 GB)
     Used Dev Size : 20971520 (20.00 GiB 21.47 GB)
      Raid Devices : 2
     Total Devices : 2
       Persistence : Superblock is persistent

     Intent Bitmap : Internal

       Update Time : $(date)
             State : clean 
    Active Devices : 2
   Working Devices : 2
    Failed Devices : 0
     Spare Devices : 0

Consistency Policy : bitmap

              Name : test-server:0
              UUID : abcdef12-3456-7890-abcd-ef1234567890
            Events : 123

    Number   Major   Minor   RaidDevice State
       0       8       48        0      active sync   /dev/sdd
       1       8       64        1      active sync   /dev/sde
EOF
}

mock_smartctl() {
    local device="${1:-/dev/sda}"
    cat << EOF
smartctl 7.2 2020-12-30 r5155 [x86_64-linux-5.15.0-144-generic] (local build)
Copyright (C) 2002-20, Bruce Allen, Christian Franke, www.smartmontools.org

=== START OF INFORMATION SECTION ===
Model Family:     Test Hard Drive Family
Device Model:     TEST-HDD-001
Serial Number:    TEST123456789
LU WWN Device Id: 5 000000 000000001
Firmware Version: TEST01
User Capacity:    21,474,836,480 bytes [21.4 GB]
Sector Size:      512 bytes logical/physical
Rotation Rate:    7200 rpm
Form Factor:      3.5 inches
Device is:        In smartctl database [for details use: -P show]
ATA Version is:   ACS-3 T13/2161-D revision 5
SATA Version is:  SATA 3.2, 6.0 Gb/s (current: 6.0 Gb/s)
Local Time is:    $(date)
SMART support is: Available - device has SMART capability.
SMART support is: Enabled

=== START OF READ SMART DATA SECTION ===
SMART overall-health self-assessment test result: PASSED
EOF
}

# 테스트용 파일시스템 mock
mock_findmnt() {
    cat << 'EOF'
TARGET                SOURCE      FSTYPE     OPTIONS
/                     /dev/sda3   ext4       rw,relatime
├─/boot               /dev/sda2   ext4       rw,relatime
├─/boot/efi           /dev/sda1   vfat       rw,relatime
├─/mnt/data           /dev/sdb1   ext4       rw,relatime,nofail
├─/mnt/raid           /dev/md0    ext4       rw,relatime
└─/tmp                tmpfs       tmpfs      rw,noatime
EOF
}

# 테스트 유틸리티 함수들
assert_file_exists() {
    local file="$1"
    [[ -f "$file" ]] || (echo "File does not exist: $file" && return 1)
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    grep -q "$pattern" "$file" || (echo "File $file does not contain: $pattern" && return 1)
}

assert_command_success() {
    # run 명령어가 이미 실행된 후에 호출되므로 status만 확인
    [[ "$status" -eq 0 ]] || (echo "Command failed with status: $status" && echo "Output: $output" && return 1)
}

assert_command_failure() {
    # run 명령어가 이미 실행된 후에 호출되므로 status만 확인
    [[ "$status" -ne 0 ]] || (echo "Command should have failed but succeeded" && echo "Output: $output" && return 1)
}

assert_output_contains() {
    local pattern="$1"
    [[ "$output" =~ $pattern ]] || (echo "Output does not contain: $pattern" && echo "Actual output: $output" && return 1)
}

assert_output_not_contains() {
    local pattern="$1"
    [[ ! "$output" =~ $pattern ]] || (echo "Output should not contain: $pattern" && echo "Actual output: $output" && return 1)
}

# Mock 함수 설정
setup_mocks() {
    # PATH에 mock 디렉토리 추가
    export MOCK_DIR="${TEST_TEMP_DIR}/mocks"
    mkdir -p "${MOCK_DIR}"
    export PATH="${MOCK_DIR}:${PATH}"
    
    # Mock 스크립트 생성
    create_mock_script "lsblk" mock_lsblk
    create_mock_script "mdadm" mock_mdadm_wrapper
    create_mock_script "smartctl" mock_smartctl_wrapper
    create_mock_script "findmnt" mock_findmnt_wrapper
}

create_mock_script() {
    local script_name="$1"
    local function_name="$2"
    
    cat > "${MOCK_DIR}/${script_name}" << EOF
#!/bin/bash
# Mock script for $script_name
source "${BATS_TEST_DIRNAME}/test_helpers.bash"
$function_name "\$@"
EOF
    chmod +x "${MOCK_DIR}/${script_name}"
}

mock_mdadm_wrapper() {
    case "$1" in
        "--detail")
            mock_mdadm_detail "$2"
            ;;
        "--examine")
            echo "Mock mdadm examine output"
            ;;
        *)
            echo "Mock mdadm command: $*"
            ;;
    esac
}

mock_smartctl_wrapper() {
    if [[ "$1" == "-H" ]]; then
        echo "SMART overall-health self-assessment test result: PASSED"
    else
        mock_smartctl "$2"
    fi
}

mock_findmnt_wrapper() {
    if [[ "$#" -eq 0 ]]; then
        mock_findmnt
    else
        echo "Mock findmnt for: $*"
    fi
}

# 테스트 상태 검증 함수들
verify_no_side_effects() {
    # 실제 시스템 파일이 변경되지 않았는지 확인
    [[ ! -f "/etc/fstab.backup" ]] || (echo "Unexpected backup file created" && return 1)
    [[ ! -f "/etc/mdadm/mdadm.conf.backup" ]] || (echo "Unexpected mdadm backup created" && return 1)
}

skip_if_not_root() {
    if [[ $EUID -ne 0 ]]; then
        skip "This test requires root privileges"
    fi
}

skip_if_no_mdadm() {
    if ! command -v mdadm &> /dev/null; then
        skip "mdadm is not installed"
    fi
}

skip_if_no_smartctl() {
    if ! command -v smartctl &> /dev/null; then
        skip "smartctl is not installed"
    fi
}

# 로그 캡처 함수
capture_logs() {
    export TEST_LOG_FILE="${TEST_TEMP_DIR}/test.log"
    touch "${TEST_LOG_FILE}"
}

assert_log_contains() {
    local pattern="$1"
    [[ -f "${TEST_LOG_FILE}" ]] || (echo "Log file not found" && return 1)
    grep -q "$pattern" "${TEST_LOG_FILE}" || (echo "Log does not contain: $pattern" && return 1)
} 
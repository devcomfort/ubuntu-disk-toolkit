#!/usr/bin/env bash

# ===================================================================================
# test_helpers.bash - bats 테스트용 공통 헬퍼 함수
# ===================================================================================

# 테스트 환경 설정
setup_test_environment() {
    # 프로젝트 루트 설정
    export BATS_PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PATH="${BATS_PROJECT_ROOT}/bin:${PATH}"
    
    # 라이브러리 및 바이너리 디렉토리 설정
    export LIB_DIR="${BATS_PROJECT_ROOT}/lib"
    export BIN_DIR="${BATS_PROJECT_ROOT}/bin"
    
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
    # PATH 복원
    if [[ -n "${ORIGINAL_PATH:-}" ]]; then
        export PATH="$ORIGINAL_PATH"
        unset ORIGINAL_PATH
    fi
    
    # 임시 디렉토리 정리
    if [[ -d "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
    
    # 환경 변수 정리
    unset BATS_PROJECT_ROOT TEST_TEMP_DIR TEST_CONFIG_DIR 
    unset TEST_FSTAB_FILE TEST_MDADM_CONF NO_COLOR TESTING_MODE MOCK_DIR
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
    # 다양한 lsblk 옵션 처리
    if [[ "$*" == *"-J"* ]]; then
        # JSON 형식 출력
        cat << 'EOF'
{
   "blockdevices": [
      {
         "name": "sda",
         "size": "20G",
         "type": "disk",
         "fstype": null,
         "mountpoint": null,
         "children": [
            {
               "name": "sda1",
               "size": "1G", 
               "type": "part",
               "fstype": "vfat",
               "mountpoint": "/boot/efi"
            },
            {
               "name": "sda2",
               "size": "2G",
               "type": "part", 
               "fstype": "ext4",
               "mountpoint": "/boot"
            },
            {
               "name": "sda3",
               "size": "17G",
               "type": "part",
               "fstype": "ext4", 
               "mountpoint": "/"
            }
         ]
      },
      {
         "name": "md0",
         "size": "20G",
         "type": "raid1",
         "fstype": "ext4",
         "mountpoint": "/mnt/raid"
      }
   ]
}
EOF
    elif [[ "$*" == *"-b"* ]] && [[ "$*" == *"-d"* ]] && [[ "$*" == *"-n"* ]] && [[ "$*" == *"-o SIZE"* ]]; then
        # 바이트 단위 크기 출력 (get_disk_size에서 사용)
        if [[ "$*" == *"/dev/sda"* ]]; then
            echo "21474836480"  # 20GB in bytes
        elif [[ "$*" == *"/dev/sdb"* ]]; then
            echo "10737418240"  # 10GB in bytes
        elif [[ "$*" == *"/dev/sdc"* ]]; then
            echo "10737418240"  # 10GB in bytes
        elif [[ "$*" == *"/dev/sdd"* ]]; then
            echo "10737418240"  # 10GB in bytes
        elif [[ "$*" == *"/dev/sde"* ]]; then
            echo "10737418240"  # 10GB in bytes
        elif [[ "$*" == *"/dev/md0"* ]]; then
            echo "21474836480"  # 20GB in bytes
        else
            echo "0"
        fi
    elif [[ "$*" == *"-d"* ]] && [[ "$*" == *"-n"* ]] && [[ "$*" == *"-o NAME,SIZE,TYPE"* ]]; then
        # 디스크만 표시 (show_disk_info_interactive에서 사용)
        cat << 'EOF'
sda 20G disk
sdb 10G disk
sdc 10G disk
sdd 10G disk
sde 10G disk
EOF
    elif [[ "$*" == *"-o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID"* ]]; then
        # 상세 디스크 정보 (show_disk_info_direct에서 사용)
        if [[ "$*" == *"/dev/virtual-sda"* ]]; then
            cat << 'EOF'
NAME         SIZE TYPE FSTYPE MOUNTPOINT UUID
virtual-sda   20G disk               
├─virtual-sda1 1G part vfat   /test/efi virtual-uuid-1
├─virtual-sda2 2G part ext4   /test/boot virtual-uuid-2
└─virtual-sda3 17G part ext4   /test virtual-uuid-3
EOF
        elif [[ "$*" == *"/dev/virtual-sdb"* ]]; then
            cat << 'EOF'
NAME         SIZE TYPE FSTYPE MOUNTPOINT UUID
virtual-sdb   10G disk               
└─virtual-sdb1 10G part ext4        virtual-uuid-4
EOF
        elif [[ "$*" == *"/dev/test-empty"* ]]; then
            cat << 'EOF'
NAME       SIZE TYPE FSTYPE MOUNTPOINT UUID
test-empty   0B disk               
EOF
        elif [[ "$*" == *"/dev/test-small"* ]]; then
            cat << 'EOF'
NAME       SIZE TYPE FSTYPE MOUNTPOINT UUID
test-small  1K disk               
EOF
        elif [[ "$*" == *"/dev/sda"* ]]; then
            cat << 'EOF'
NAME     SIZE TYPE FSTYPE MOUNTPOINT UUID
sda       20G disk               
├─sda1    1G part vfat   /boot/efi 1234-5678
├─sda2    2G part ext4   /boot     abcd-efgh-1234-5678
└─sda3   17G part ext4   /         ijkl-mnop-5678-9012
EOF
        else
            cat << 'EOF'
NAME     SIZE TYPE FSTYPE      MOUNTPOINT UUID
sdb       10G disk               
└─sdb1   10G part ext4       /mnt/data  uuid-sdb1
EOF
        fi
    elif [[ "$*" == *"-n"* ]] && [[ "$*" == *"-o NAME"* ]]; then
        # 파티션 이름만 (파티션 정보에서 사용)
        if [[ "$*" == *"/dev/sda"* ]]; then
            cat << 'EOF'
sda1
sda2
sda3
EOF
        else
            echo "sdb1"
        fi
    elif [[ "$*" == *"-n"* ]] && [[ "$*" == *"-o FSTYPE"* ]]; then
        # FSTYPE만 출력 (is_raid_member에서 사용)
        if [[ "$*" == *"/dev/sdd"* ]]; then
            echo "linux_raid_member"
        elif [[ "$*" == *"/dev/sde"* ]]; then
            echo "linux_raid_member"
        elif [[ "$*" == *"/dev/test-empty"* ]]; then
            echo ""  # 빈 FSTYPE (RAID 멤버가 아님)
        elif [[ "$*" == *"/dev/virtual-sda"* ]]; then
            echo ""  # 빈 FSTYPE
        elif [[ "$*" == *"/dev/virtual-sdb"* ]]; then
            echo ""  # 빈 FSTYPE
        else
            echo ""  # 기본적으로 빈 FSTYPE
        fi
    elif [[ "$*" == *"-n"* ]] && [[ "$*" == *"-o SIZE,FSTYPE,MOUNTPOINT"* ]]; then
        # 파티션 상세 정보 (파티션별 정보에서 사용)
        if [[ "$*" == *"/dev/sda1"* ]]; then
            echo "1G vfat /boot/efi"
        elif [[ "$*" == *"/dev/sda2"* ]]; then
            echo "2G ext4 /boot"
        elif [[ "$*" == *"/dev/sda3"* ]]; then
            echo "17G ext4 /"
        else
            echo "10G ext4 /mnt/data"
        fi
    elif [[ "$*" == *"-d"* ]] && [[ "$*" == *"-n"* ]] && [[ "$*" == *"-o NAME,SIZE,TYPE,MODEL,SERIAL"* ]]; then
        # get_all_disks에서 사용하는 옵션
        cat << 'EOF'
sda 20G disk ATA_TEST_HDD TEST123
sdb 10G disk ATA_TEST_HDD TEST456
sdc 10G disk ATA_TEST_HDD TEST789
sdd 10G disk ATA_TEST_HDD TEST012
sde 10G disk ATA_TEST_HDD TEST345
EOF
    else
        # 기본 테이블 형식
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
    fi
}

mock_blockdev() {
    # blockdev --getsize64 명령어 처리
    if [[ "$*" == *"--getsize64"* ]]; then
        # 가상 디스크 지원
        if [[ "$*" == *"/dev/virtual-sda"* ]]; then
            # Mock이 사용되었음을 확인할 수 있는 특별한 값 (실제로는 20GB)
            echo "21474836480"
        elif [[ "$*" == *"/dev/virtual-sdb"* ]]; then
            echo "10737418240"  # 10GB in bytes
        elif [[ "$*" == *"/dev/virtual-sdc"* ]]; then
            echo "10737418240"  # 10GB in bytes
        elif [[ "$*" == *"/dev/test-empty"* ]]; then
            echo "0"  # 0 bytes
        elif [[ "$*" == *"/dev/test-small"* ]]; then
            echo "1024"  # 1KB in bytes
        # 테스트용 디스크들 (안전성 체크 없이 단순 처리)
        elif [[ "$*" == *"/dev/sda"* ]]; then
            echo "21474836480"  # 20GB in bytes
        elif [[ "$*" == *"/dev/sdb"* ]]; then
            echo "10737418240"  # 10GB in bytes
        elif [[ "$*" == *"/dev/sdc"* ]]; then
            echo "10737418240"  # 10GB in bytes
        elif [[ "$*" == *"/dev/sdd"* ]]; then
            echo "10737418240"  # 10GB in bytes
        elif [[ "$*" == *"/dev/sde"* ]]; then
            echo "10737418240"  # 10GB in bytes
        elif [[ "$*" == *"/dev/md0"* ]]; then
            echo "21474836480"  # 20GB in bytes
        else
            echo "0"
        fi
    else
        echo "blockdev: unknown option"
        return 1
    fi
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
    
    if [[ ! -f "$file" ]]; then
        echo "❌ FILE DOES NOT EXIST"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 Test: ${BATS_TEST_DESCRIPTION:-Unknown}"
        echo "📁 Expected File: $file"
        echo "🔍 Current Directory: $(pwd)"
        echo ""
        echo "📂 DIRECTORY CONTENTS:"
        echo "────────────────────────────────────────────────────────────────────────────────"
        local dir="$(dirname "$file")"
        if [[ -d "$dir" ]]; then
            echo "Directory '$dir' exists. Contents:"
            ls -la "$dir" 2>/dev/null || echo "Cannot list directory contents"
        else
            echo "Directory '$dir' does not exist"
        fi
        echo "────────────────────────────────────────────────────────────────────────────────"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    
    if [[ ! -f "$file" ]]; then
        echo "❌ FILE DOES NOT EXIST"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 Test: ${BATS_TEST_DESCRIPTION:-Unknown}"
        echo "📁 Expected File: $file"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
    
    if ! grep -q "$pattern" "$file"; then
        echo "❌ FILE DOES NOT CONTAIN EXPECTED PATTERN"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 Test: ${BATS_TEST_DESCRIPTION:-Unknown}"
        echo "📁 File: $file"
        echo "🔍 Expected Pattern: '$pattern'"
        echo ""
        echo "📝 FILE CONTENTS:"
        echo "────────────────────────────────────────────────────────────────────────────────"
        if [[ -r "$file" ]]; then
            head -20 "$file" || echo "Cannot read file"
            local line_count=$(wc -l < "$file" 2>/dev/null || echo "0")
            if [[ $line_count -gt 20 ]]; then
                echo "... (showing first 20 lines of $line_count total)"
            fi
        else
            echo "File is not readable"
        fi
        echo "────────────────────────────────────────────────────────────────────────────────"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
}

assert_command_success() {
    # run 명령어가 이미 실행된 후에 호출되므로 status만 확인
    if [[ "$status" -ne 0 ]]; then
        echo "❌ COMMAND FAILED"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 Test: ${BATS_TEST_DESCRIPTION:-Unknown}"
        echo "📁 File: ${BATS_TEST_FILENAME:-Unknown}"
        echo "📍 Line: ${BATS_TEST_LINE_NUMBER:-Unknown}"
        echo "💥 Exit Code: $status"
        echo "📝 Expected: 0 (success)"
        echo ""
        echo "🔍 COMMAND OUTPUT:"
        echo "────────────────────────────────────────────────────────────────────────────────"
        if [[ -n "$output" ]]; then
            echo "$output"
        else
            echo "(No output)"
        fi
        echo "────────────────────────────────────────────────────────────────────────────────"
        echo ""
        echo "🛠️  DEBUGGING INFO:"
        echo "Working Directory: $(pwd)"
        echo "PATH: $PATH"
        echo "Environment Variables:"
        env | grep -E "(BATS_|TEST_|PROJECT_)" | sort || true
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
}

assert_command_failure() {
    # run 명령어가 이미 실행된 후에 호출되므로 status만 확인
    if [[ "$status" -eq 0 ]]; then
        echo "❌ COMMAND SHOULD HAVE FAILED"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 Test: ${BATS_TEST_DESCRIPTION:-Unknown}"
        echo "📁 File: ${BATS_TEST_FILENAME:-Unknown}"
        echo "📍 Line: ${BATS_TEST_LINE_NUMBER:-Unknown}"
        echo "💥 Exit Code: $status"
        echo "📝 Expected: non-zero (failure)"
        echo ""
        echo "🔍 COMMAND OUTPUT:"
        echo "────────────────────────────────────────────────────────────────────────────────"
        if [[ -n "$output" ]]; then
            echo "$output"
        else
            echo "(No output)"
        fi
        echo "────────────────────────────────────────────────────────────────────────────────"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
}

assert_output_contains() {
    local pattern="$1"
    # 정규표현식 대신 literal 문자열 매칭 사용 ({ } 등의 특수문자 문제 해결)
    if [[ "$output" != *"$pattern"* ]]; then
        echo "❌ OUTPUT DOES NOT CONTAIN EXPECTED PATTERN"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 Test: ${BATS_TEST_DESCRIPTION:-Unknown}"
        echo "📁 File: ${BATS_TEST_FILENAME:-Unknown}"
        echo "📍 Line: ${BATS_TEST_LINE_NUMBER:-Unknown}"
        echo "🔍 Expected Pattern: '$pattern'"
        echo ""
        echo "📝 ACTUAL OUTPUT:"
        echo "────────────────────────────────────────────────────────────────────────────────"
        if [[ -n "$output" ]]; then
            echo "$output"
        else
            echo "(No output)"
        fi
        echo "────────────────────────────────────────────────────────────────────────────────"
        echo ""
        echo "🔍 PATTERN ANALYSIS:"
        echo "Pattern length: ${#pattern}"
        echo "Output length: ${#output}"
        if [[ ${#output} -gt 0 ]]; then
            echo "Output preview (first 200 chars): ${output:0:200}..."
            echo ""
            # 대소문자 구분 없이 검색해보기
            if echo "$output" | grep -qi "$pattern"; then
                echo "💡 NOTE: Pattern found with case-insensitive search"
            fi
        fi
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
}

assert_output_not_contains() {
    local pattern="$1"
    # 정규표현식 대신 literal 문자열 매칭 사용
    if [[ "$output" == *"$pattern"* ]]; then
        echo "❌ OUTPUT CONTAINS UNEXPECTED PATTERN"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 Test: ${BATS_TEST_DESCRIPTION:-Unknown}"
        echo "📁 File: ${BATS_TEST_FILENAME:-Unknown}"
        echo "📍 Line: ${BATS_TEST_LINE_NUMBER:-Unknown}"
        echo "🚫 Forbidden Pattern: '$pattern'"
        echo ""
        echo "📝 ACTUAL OUTPUT:"
        echo "────────────────────────────────────────────────────────────────────────────────"
        if [[ -n "$output" ]]; then
            echo "$output"
        else
            echo "(No output)"
        fi
        echo "────────────────────────────────────────────────────────────────────────────────"
        echo ""
        echo "🔍 PATTERN ANALYSIS:"
        echo "Pattern found at position(s):"
        # 패턴이 나타나는 위치들을 찾아서 표시
        local temp_output="$output"
        local position=0
        while [[ "$temp_output" == *"$pattern"* ]]; do
            local before="${temp_output%%$pattern*}"
            position=$((position + ${#before}))
            echo "  - Position $position"
            temp_output="${temp_output#*$pattern}"
            position=$((position + ${#pattern}))
        done
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
}

# Mock 함수 설정
setup_mocks() {
    # 원래 PATH 백업
    export ORIGINAL_PATH="$PATH"
    
    # PATH에 mock 디렉토리 추가 (기본 시스템 경로 유지)
    export MOCK_DIR="${TEST_TEMP_DIR}/mocks"
    mkdir -p "${MOCK_DIR}"
    export PATH="${MOCK_DIR}:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
    
    # 기본 시스템 명령어들을 Mock 디렉토리에 링크 (fallback용)
    for cmd in rm grep sort env cat head tail wc ls mkdir cp mv chmod touch; do
        if command -v "$cmd" >/dev/null 2>&1; then
            ln -sf "$(command -v "$cmd")" "${MOCK_DIR}/$cmd" 2>/dev/null || true
        fi
    done
    
    # mount, swapon, pvs Mock 스크립트 생성
    create_mock_script "mount" mock_mount
    create_mock_script "swapon" mock_swapon  
    create_mock_script "pvs" mock_pvs
    
    # 확장된 Mock 시스템 명령어들
    create_mock_script "blkid" mock_blkid
    create_mock_script "parted" mock_parted
    create_mock_script "mkfs.ext4" mock_mkfs_ext4
    create_mock_script "mkfs.xfs" mock_mkfs_xfs
    create_mock_script "mkfs.btrfs" mock_mkfs_btrfs
    create_mock_script "dd" mock_dd
    create_mock_script "shred" mock_shred
    create_mock_script "wipefs" mock_wipefs
    
    # Mock 스크립트 생성
    create_mock_script "lsblk" mock_lsblk
    create_mock_script "mdadm" mock_mdadm_wrapper
    create_mock_script "smartctl" mock_smartctl_wrapper
    create_mock_script "findmnt" mock_findmnt_wrapper
    create_mock_script "blockdev" mock_blockdev
    
    # check_disk_exists Mock 스크립트 생성
    cat > "${MOCK_DIR}/check_disk_exists" << 'EOF'
#!/bin/bash
source "${BATS_TEST_DIRNAME}/test_helpers.bash"

# 가상 디스크 인식 함수 재정의
is_virtual_disk() {
    local disk="$1"
    case "$disk" in
        "/dev/virtual-"*|"/dev/test-"*) return 0 ;;
        *) return 1 ;;
    esac
}

disk="$1"

# 가상 디스크는 항상 존재
if is_virtual_disk "$disk"; then
    exit 0
fi

# 실제 디스크는 블록 디바이스 체크
if [[ -b "$disk" ]]; then
    exit 0
else
    echo "✗ 디스크 '$disk'를 찾을 수 없습니다."
    exit 1
fi
EOF
    chmod +x "${MOCK_DIR}/check_disk_exists"
}

create_mock_script() {
    local script_name="$1"
    local function_name="$2"
    
    # 절대 경로로 test_helpers.bash 위치 확정
    local test_helpers_path
    if [[ -n "${BATS_TEST_DIRNAME:-}" ]]; then
        test_helpers_path="${BATS_TEST_DIRNAME}/test_helpers.bash"
    else
        test_helpers_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helpers.bash"
    fi
    
    cat > "${MOCK_DIR}/${script_name}" << EOF
#!/bin/bash
# Mock script for $script_name
source "$test_helpers_path"
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
            local device="$2"
            if [[ "$device" == "/dev/test-empty" ]] || [[ "$device" == "/dev/virtual-"* ]]; then
                # test-empty와 virtual 디스크들은 RAID 멤버가 아님
                echo "mdadm: $device does not appear to be an md device" >&2
                return 1
            else
                echo "Mock mdadm examine output for $device"
            fi
            ;;
        *)
            echo "Mock mdadm command: $*"
            ;;
    esac
}

mock_smartctl_wrapper() {
    local option="$1"
    local device="$2"
    
    if [[ "$option" == "-H" ]]; then
        echo "SMART overall-health self-assessment test result: PASSED"
    elif [[ "$option" == "-i" ]]; then
        # 정보 요청 - 디스크별로 다른 응답
        if [[ "$device" == "/dev/test-empty" ]]; then
            # test-empty는 SMART를 지원하지 않음
            cat << EOF
smartctl 7.2 2020-12-30 r5155 [x86_64-linux-5.15.0-144-generic] (local build)
Device: $device [Empty Test Device]
SMART support is: Unavailable - device lacks SMART capability.
EOF
        else
            # 다른 디스크들은 SMART 지원
            cat << EOF
smartctl 7.2 2020-12-30 r5155 [x86_64-linux-5.15.0-144-generic] (local build)
Device: $device [Test Device]
SMART support is: Available - device has SMART capability.
SMART support is: Enabled
EOF
        fi
    else
        mock_smartctl "$device"
    fi
}

mock_findmnt_wrapper() {
    if [[ "$#" -eq 0 ]]; then
        mock_findmnt
    else
        echo "Mock findmnt for: $*"
    fi
}

mock_mount() {
    # 테스트용 마운트 정보 반환 (가상 디스크는 마운트되지 않음)
    cat << 'EOF'
/dev/sda3 on / type ext4 (rw,relatime)
/dev/sda1 on /boot/efi type vfat (rw,relatime)
/dev/sda2 on /boot type ext4 (rw,relatime)
tmpfs on /tmp type tmpfs (rw,nosuid,nodev)
EOF
}

mock_swapon() {
    if [[ "$*" == *"--show"* ]]; then
        # 가상 디스크는 스왑으로 사용되지 않음
        echo ""
    else
        echo "Mock swapon: $*"
    fi
}

mock_pvs() {
    if [[ "$*" == *"--noheadings"* ]] && [[ "$*" == *"-o pv_name"* ]]; then
        # 가상 디스크는 LVM PV가 아님
        echo ""
    else
        echo "Mock pvs: $*"
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

# 테스트용 가상 디스크 경로 정의
export TEST_VIRTUAL_DISKS=(
    "/dev/virtual-sda"    # 20GB 가상 디스크
    "/dev/virtual-sdb"    # 10GB 가상 디스크  
    "/dev/virtual-sdc"    # 10GB 가상 디스크
    "/dev/test-empty"     # 빈 디스크 (크기 0)
    "/dev/test-small"     # 작은 디스크 (1KB)
)

# 가상 디스크 인식 함수
is_virtual_disk() {
    local disk="$1"
    for virtual_disk in "${TEST_VIRTUAL_DISKS[@]}"; do
        [[ "$disk" == "$virtual_disk" ]] && return 0
    done
    return 1
}

# 안전한 디스크 체크 함수
safe_disk_check() {
    local disk="$1"
    local operation="${2:-read}"  # read, write, mount 등
    
    # 가상 디스크는 항상 안전
    if is_virtual_disk "$disk"; then
        return 0
    fi
    
    # 실제 디스크의 경우 사용 중인지 분석
    if [[ -b "$disk" ]]; then
        # 마운트된 디스크 체크
        if mount | grep -q "^$disk"; then
            echo "⚠️ 경고: $disk는 현재 마운트되어 있습니다"
            [[ "$operation" == "mount" ]] && return 1
        fi
        
        # 루프백 디바이스 체크 (snap 등에서 사용)
        if [[ "$disk" =~ ^/dev/loop[0-9]+$ ]] && lsblk "$disk" | grep -q "/snap/"; then
            echo "⚠️ 경고: $disk는 snap에서 사용 중입니다"
            return 1
        fi
        
        # RAID 멤버 체크
        if lsblk -n -o FSTYPE "$disk" 2>/dev/null | grep -q "linux_raid_member"; then
            echo "⚠️ 경고: $disk는 RAID 멤버입니다"
            [[ "$operation" == "mount" ]] && return 1
        fi
    fi
    
    return 0
} 

# check_disk_exists Mock 함수
mock_check_disk_exists() {
    local disk="$1"
    
    # 가상 디스크는 항상 존재
    if is_virtual_disk "$disk"; then
        return 0
    fi
    
    # 실제 디스크는 안전성 체크와 함께
    if [[ -b "$disk" ]]; then
        if safe_disk_check "$disk" "read"; then
            return 0
        else
            echo "✗ 디스크 '$disk'는 사용 중이거나 접근할 수 없습니다."
            return 1
        fi
    else
        echo "✗ 디스크 '$disk'를 찾을 수 없습니다."
        return 1
    fi
}

# ===================================================================================
# 확장된 Mock 시스템 명령어들
# ===================================================================================

# blkid Mock 함수 - 블록 디바이스 정보 조회
mock_blkid() {
    local device=""
    local output_option=""
    local type_option=""
    
    # 옵션 파싱
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s)
                type_option="$2"
                shift 2
                ;;
            -o)
                output_option="$2"
                shift 2
                ;;
            *)
                device="$1"
                shift
                ;;
        esac
    done
    
    # 디바이스별 Mock 정보 제공
    case "$device" in
        "/dev/sda"|"/dev/sda1")
            case "$type_option" in
                "UUID")
                    [[ "$output_option" == "value" ]] && echo "12345678-1234-1234-1234-123456781234" || echo "UUID=\"12345678-1234-1234-1234-123456781234\""
                    ;;
                "PARTUUID")
                    [[ "$output_option" == "value" ]] && echo "87654321-4321-4321-4321-876543214321" || echo "PARTUUID=\"87654321-4321-4321-4321-876543214321\""
                    ;;
                "LABEL")
                    [[ "$output_option" == "value" ]] && echo "root" || echo "LABEL=\"root\""
                    ;;
                "TYPE")
                    [[ "$output_option" == "value" ]] && echo "ext4" || echo "TYPE=\"ext4\""
                    ;;
                *)
                    echo "/dev/sda1: UUID=\"12345678-1234-1234-1234-123456781234\" TYPE=\"ext4\" PARTUUID=\"87654321-4321-4321-4321-876543214321\""
                    ;;
            esac
            ;;
        "/dev/sdb"|"/dev/sdb1")
            case "$type_option" in
                "UUID")
                    [[ "$output_option" == "value" ]] && echo "22345678-2234-2234-2234-223456782234" || echo "UUID=\"22345678-2234-2234-2234-223456782234\""
                    ;;
                "TYPE")
                    [[ "$output_option" == "value" ]] && echo "ext4" || echo "TYPE=\"ext4\""
                    ;;
                *)
                    echo "/dev/sdb1: UUID=\"22345678-2234-2234-2234-223456782234\" TYPE=\"ext4\""
                    ;;
            esac
            ;;
        "/dev/test-empty"|"/dev/virtual-sda")
            # 테스트용 빈 디스크는 정보 없음
            return 2
            ;;
        *)
            # 기본 Mock 정보
            if [[ -n "$type_option" ]]; then
                case "$type_option" in
                    "UUID")
                        [[ "$output_option" == "value" ]] && echo "test-uuid-mock" || echo "UUID=\"test-uuid-mock\""
                        ;;
                    "TYPE")
                        [[ "$output_option" == "value" ]] && echo "ext4" || echo "TYPE=\"ext4\""
                        ;;
                esac
            else
                echo "$device: UUID=\"test-uuid-mock\" TYPE=\"ext4\""
            fi
            ;;
    esac
}

# parted Mock 함수 - 파티션 관리
mock_parted() {
    local device=""
    local command=""
    local silent_mode=false
    
    # 옵션 파싱
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s)
                silent_mode=true
                shift
                ;;
            *)
                if [[ -z "$device" ]]; then
                    device="$1"
                else
                    command="$*"
                    break
                fi
                shift
                ;;
        esac
    done
    
    case "$command" in
        "print")
            echo "Model: Virtual disk (virtio)"
            echo "Disk $device: 21.5GB"
            echo "Sector size (logical/physical): 512B/512B"
            echo "Partition Table: gpt"
            echo ""
            echo "Number  Start   End     Size    File system  Name  Flags"
            echo " 1      1049kB  21.5GB  21.5GB  ext4               boot, esp"
            ;;
        mkpart*)
            echo "Information: You may need to update /etc/fstab."
            ;;
        mklabel*)
            echo "Warning: The existing disk label on $device will be destroyed."
            ;;
        *)
            echo "GNU Parted 3.3"
            ;;
    esac
}

# mkfs.ext4 Mock 함수
mock_mkfs_ext4() {
    local device=""
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -F)
                force=true
                shift
                ;;
            *)
                device="$1"
                shift
                ;;
        esac
    done
    
    echo "mke2fs 1.46.3 (27-Jul-2021)"
    echo "Creating filesystem with 5242880 4k blocks and 1310720 inodes"
    echo "Filesystem UUID: $(date +%s | md5sum | cut -c1-8)-1234-5678-9abc-123456789abc"
    echo "Superblock backups stored on blocks:"
    echo "        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208,"
    echo "        4096000"
    echo ""
    echo "Allocating group tables: done"
    echo "Writing inode tables: done"
    echo "Creating journal (32768 blocks): done"
    echo "Writing superblocks and filesystem accounting information: done"
}

# mkfs.xfs Mock 함수
mock_mkfs_xfs() {
    local device=""
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f)
                force=true
                shift
                ;;
            *)
                device="$1"
                shift
                ;;
        esac
    done
    
    echo "meta-data=$device           isize=512    agcount=4, agsize=1310720 blks"
    echo "         =                       sectsz=512   attr=2, projid32bit=1"
    echo "         =                       crc=1        finobt=1, sparse=1, rmapbt=0"
    echo "         =                       reflink=1"
    echo "data     =                       bsize=4096   blocks=5242880, imaxpct=25"
    echo "         =                       sunit=0      swidth=0 blks"
    echo "naming   =version 2              bsize=4096   ascii-ci=0, ftype=1"
    echo "log      =internal log           bsize=4096   blocks=2560, version=2"
    echo "         =                       sectsz=512   sunit=0 blks, lazy-count=1"
    echo "realtime =none                   extsz=4096   blocks=0, rtextents=0"
}

# mkfs.btrfs Mock 함수
mock_mkfs_btrfs() {
    local device=""
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f)
                force=true
                shift
                ;;
            *)
                device="$1"
                shift
                ;;
        esac
    done
    
    echo "btrfs-progs v5.16.2"
    echo "See http://btrfs.wiki.kernel.org for more information."
    echo ""
    echo "Label:              (none)"
    echo "UUID:               $(date +%s | sha256sum | cut -c1-8)-1234-5678-9abc-123456789abc"
    echo "Node size:          16384"
    echo "Sector size:        4096"
    echo "Filesystem size:    20.00GiB"
    echo "Block group profiles:"
    echo "  Data:             single            8.00MiB"
    echo "  Metadata:         DUP               1.00GiB"
    echo "  System:           DUP               8.00MiB"
    echo "SSD detected:       no"
    echo "Incompat features:  extref, skinny-metadata"
    echo "Runtime features:"
    echo "Checksum:           crc32c"
    echo "Number of devices:  1"
    echo "Devices:"
    echo "   ID        SIZE  PATH"
    echo "    1    20.00GiB  $device"
}

# dd Mock 함수 - 디스크 읽기/쓰기
mock_dd() {
    local input_file=""
    local output_file=""
    local block_size="512"
    local count=""
    local status="none"
    
    # 옵션 파싱
    while [[ $# -gt 0 ]]; do
        case "$1" in
            if=*)
                input_file="${1#if=}"
                ;;
            of=*)
                output_file="${1#of=}"
                ;;
            bs=*)
                block_size="${1#bs=}"
                ;;
            count=*)
                count="${1#count=}"
                ;;
            status=*)
                status="${1#status=}"
                ;;
        esac
        shift
    done
    
    # Mock 성능 수치 생성
    local bytes_written
    if [[ -n "$count" ]]; then
        case "$block_size" in
            *M)
                bytes_written=$((${block_size%M} * ${count:-1} * 1024 * 1024))
                ;;
            *k|*K)
                bytes_written=$((${block_size%[kK]} * ${count:-1} * 1024))
                ;;
            *)
                bytes_written=$((block_size * ${count:-1}))
                ;;
        esac
    else
        bytes_written=$((100 * 1024 * 1024))  # 기본 100MB
    fi
    
    # 진행률 표시 (status=progress인 경우)
    if [[ "$status" == "progress" ]]; then
        echo "100+0 records in"
        echo "100+0 records out"
        echo "$bytes_written bytes ($((bytes_written / 1024 / 1024)) MB, $((bytes_written / 1000 / 1000)) MiB) copied, 1.5 s, 67.2 MB/s"
    elif [[ "$status" == "none" ]]; then
        # 조용히 실행
        :
    else
        echo "100+0 records in"
        echo "100+0 records out"
        echo "$bytes_written bytes transferred in 1.5 secs (67239123 bytes/sec)"
    fi
}

# shred Mock 함수 - 안전한 파일 삭제
mock_shred() {
    local verbose=false
    local force=false
    local zero=false
    local iterations=3
    local target=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                verbose=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -z|--zero)
                zero=true
                shift
                ;;
            -n)
                iterations="$2"
                shift 2
                ;;
            *)
                target="$1"
                shift
                ;;
        esac
    done
    
    if [[ "$verbose" == true ]]; then
        for ((i=1; i<=iterations; i++)); do
            echo "shred: $target: pass $i/$iterations (random)..."
        done
        if [[ "$zero" == true ]]; then
            echo "shred: $target: pass $((iterations+1))/$((iterations+1)) (000000)..."
        fi
        echo "shred: $target: removing"
        echo "shred: $target: renamed to $(dirname "$target")/00000000"
        echo "shred: $target: removed"
    fi
}

# wipefs Mock 함수 - 파일시스템 시그니처 제거
mock_wipefs() {
    local all=false
    local force=false
    local device=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)
                all=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            *)
                device="$1"
                shift
                ;;
        esac
    done
    
    if [[ "$all" == true ]]; then
        echo "wipefs: $device: 2 bytes were erased at offset 0x000001fe (dos): 55 aa"
        echo "wipefs: $device: 8 bytes were erased at offset 0x00000200 (ext4): 53 ef 01 00 00 00 00 00"
    else
        echo "DEVICE OFFSET TYPE UUID                                 LABEL"
        echo "$device 0x1fe   dos                                      "
        echo "$device 0x438   ext4 12345678-1234-1234-1234-123456781234 "
    fi
} 
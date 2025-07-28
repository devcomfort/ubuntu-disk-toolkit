#!/bin/bash
# Ubuntu Disk Toolkit - 커버리지 측정 스크립트
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_ROOT/lib"
BIN_DIR="$PROJECT_ROOT/bin"

echo "📊 Ubuntu Disk Toolkit 커버리지 분석"
echo "========================================"

# 이전 커버리지 결과 정리
if [ -d "$PROJECT_ROOT/coverage" ]; then
    rm -rf "$PROJECT_ROOT/coverage"
fi

# 각 라이브러리별 커버리지 측정 (총 12개 모듈)
echo "📚 전체 라이브러리 커버리지 측정 중..."

# 1. common.sh 커버리지 측정
echo "  ▶ lib/common.sh 분석 중..."
cd "$PROJECT_ROOT"

# 임시 테스트 스크립트 생성 (Mock 환경)
cat > /tmp/test_common.sh << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Mock 환경 설정
export TESTING_MODE="true"
export TEST_TEMP_DIR="/tmp/bashcov-common-$$"
mkdir -p "\$TEST_TEMP_DIR/config"

# 테스트용 설정 파일 생성
cat > "\$TEST_TEMP_DIR/config/test.conf" << 'CONFIG_EOF'
# Test configuration
DEBUG_MODE=true
DEFAULT_FORMAT=table
CONFIG_EOF

# Mock 시스템 명령어들 생성
mkdir -p "\$TEST_TEMP_DIR/mocks"
cat > "\$TEST_TEMP_DIR/mocks/test" << 'MOCK_EOF'
#!/bin/bash
if [[ "\$1" == "-e" ]] && [[ "\$2" == "/dev/loop0" ]]; then
    exit 0  # exists
else
    exit 1  # not exists
fi
MOCK_EOF
chmod +x "\$TEST_TEMP_DIR/mocks/test"

export PATH="\$TEST_TEMP_DIR/mocks:\$PATH"

# 라이브러리 로드
source lib/common.sh 2>/dev/null || true

# 실제 테스트에서 사용되는 함수들 실행
print_header "Test Header" 2>/dev/null || true
print_success "Test Success" 2>/dev/null || true
print_error "Test Error" 2>/dev/null || true
print_warning "Test Warning" 2>/dev/null || true
print_info "Test Info" 2>/dev/null || true

# 안전 실행 함수 테스트
safe_execute "echo 'safe test'" 2>/dev/null || true
safe_execute "false" 2>/dev/null || true

# 권한 검사 (비루트 사용자로)
check_root_privileges 2>/dev/null || true

# 설정 로드
load_config 2>/dev/null || true
load_config "\$TEST_TEMP_DIR/config/test.conf" 2>/dev/null || true

# 디스크 존재 확인
check_disk_exists "/dev/loop0" 2>/dev/null || true
check_disk_exists "/dev/nonexistent_disk" 2>/dev/null || true

# 백업 생성 테스트
create_backup "/etc/passwd" "\$TEST_TEMP_DIR" 2>/dev/null || true

# 로그 메시지 테스트  
log_message "Test log message" 2>/dev/null || true

# 시그널 핸들러 설정
setup_signal_handlers 2>/dev/null || true

# 임시 파일 정리
cleanup_temp_files 2>/dev/null || true

# 정리
rm -rf "\$TEST_TEMP_DIR"
EOF
chmod +x /tmp/test_common.sh

bashcov --skip-uncovered --command-name "Common Library" /tmp/test_common.sh

# 2. disk-functions.sh 커버리지 측정 (Mock 환경)
echo "  ▶ lib/disk-functions.sh 분석 중..."
cat > /tmp/test_disk.sh << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Mock 환경 설정
export TESTING_MODE="true"
export TEST_TEMP_DIR="/tmp/bashcov-test-$$"
mkdir -p "\$TEST_TEMP_DIR/mocks"

# Mock 스크립트들 생성
cat > "\$TEST_TEMP_DIR/mocks/lsblk" << 'MOCK_EOF'
#!/bin/bash
echo "/dev/sda"
echo "/dev/sdb"
MOCK_EOF
chmod +x "\$TEST_TEMP_DIR/mocks/lsblk"

cat > "\$TEST_TEMP_DIR/mocks/blockdev" << 'MOCK_EOF'
#!/bin/bash
if [[ "\$1" == "--getsize64" ]]; then
    echo "21474836480"
fi
MOCK_EOF
chmod +x "\$TEST_TEMP_DIR/mocks/blockdev"

cat > "\$TEST_TEMP_DIR/mocks/findmnt" << 'MOCK_EOF'
#!/bin/bash
echo "TARGET SOURCE FSTYPE OPTIONS"
echo "/home /dev/sda2 ext4 rw,relatime"
MOCK_EOF
chmod +x "\$TEST_TEMP_DIR/mocks/findmnt"

# PATH에 Mock 추가
export PATH="\$TEST_TEMP_DIR/mocks:\$PATH"

# 라이브러리 로드 및 함수 실행
source lib/common.sh 2>/dev/null || true
source lib/disk-functions.sh 2>/dev/null || true

# 실제 테스트에서 사용되는 함수들 실행
get_available_disks 2>/dev/null || true
get_disk_size "/dev/sda" 2>/dev/null || true
get_disk_info "/dev/sda" 2>/dev/null || true
is_disk_mounted "/dev/sda" 2>/dev/null || true
is_raid_member "/dev/sda" 2>/dev/null || true
check_disk_compatibility "/dev/sda" "/dev/sdb" 2>/dev/null || true
get_all_disks 2>/dev/null || true

# 정리
rm -rf "\$TEST_TEMP_DIR"
EOF
chmod +x /tmp/test_disk.sh
bashcov --skip-uncovered --command-name "Disk Functions" /tmp/test_disk.sh

# 3. fstab-functions.sh 커버리지 측정 (Mock 환경) 
echo "  ▶ lib/fstab-functions.sh 분석 중..."
cat > /tmp/test_fstab.sh << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Mock 환경 설정
export TESTING_MODE="true"
export TEST_TEMP_DIR="/tmp/bashcov-fstab-$$"
mkdir -p "\$TEST_TEMP_DIR"

# 테스트용 fstab 파일 생성
cat > "\$TEST_TEMP_DIR/test_fstab" << 'FSTAB_EOF'
UUID=test-uuid-1 / ext4 defaults 0 1
UUID=test-uuid-2 /boot ext4 defaults 0 2
UUID=test-uuid-3 /home ext4 defaults 0 2
tmpfs /tmp tmpfs defaults 0 0
FSTAB_EOF

# Mock findmnt 생성
mkdir -p "\$TEST_TEMP_DIR/mocks"
cat > "\$TEST_TEMP_DIR/mocks/findmnt" << 'MOCK_EOF'
#!/bin/bash
echo "TARGET SOURCE FSTYPE OPTIONS"
echo "/ /dev/sda1 ext4 rw,relatime"
echo "/boot /dev/sda2 ext4 rw,relatime"
MOCK_EOF
chmod +x "\$TEST_TEMP_DIR/mocks/findmnt"

export PATH="\$TEST_TEMP_DIR/mocks:\$PATH"

# 라이브러리 로드
source lib/common.sh 2>/dev/null || true
source lib/fstab-functions.sh 2>/dev/null || true

# 실제 테스트에서 사용되는 함수들 실행
parse_fstab_file "\$TEST_TEMP_DIR/test_fstab" 2>/dev/null || true
validate_fstab_entry "/" "/dev/sda1" "ext4" "defaults" "0" "1" 2>/dev/null || true
get_unmounted_devices 2>/dev/null || true
analyze_fstab "\$TEST_TEMP_DIR/test_fstab" "table" 2>/dev/null || true
analyze_fstab "\$TEST_TEMP_DIR/test_fstab" "detailed" 2>/dev/null || true
validate_fstab_file "\$TEST_TEMP_DIR/test_fstab" 2>/dev/null || true

# 정리
rm -rf "\$TEST_TEMP_DIR"
EOF
chmod +x /tmp/test_fstab.sh
bashcov --skip-uncovered --command-name "Fstab Functions" /tmp/test_fstab.sh

# 4. system-functions.sh 커버리지 측정 (Mock 환경)
echo "  ▶ lib/system-functions.sh 분석 중..."
cat > /tmp/test_system.sh << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Mock 환경 설정
export TESTING_MODE="true"
export TEST_TEMP_DIR="/tmp/bashcov-system-$$"
mkdir -p "\$TEST_TEMP_DIR/mocks"

# Mock 시스템 명령어들 생성
cat > "\$TEST_TEMP_DIR/mocks/lsblk" << 'MOCK_EOF'
#!/bin/bash
echo "NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINT"
echo "sda    8:0    0  20G  0 disk"
echo "├─sda1 8:1    0   1G  0 part /boot"
echo "└─sda2 8:2    0  19G  0 part /"
MOCK_EOF
chmod +x "\$TEST_TEMP_DIR/mocks/lsblk"

cat > "\$TEST_TEMP_DIR/mocks/free" << 'MOCK_EOF'
#!/bin/bash
echo "              total        used        free      shared  buff/cache   available"
echo "Mem:        8000000      2000000     4000000      100000     2000000     5500000"
echo "Swap:       2000000            0     2000000"
MOCK_EOF
chmod +x "\$TEST_TEMP_DIR/mocks/free"

cat > "\$TEST_TEMP_DIR/mocks/uname" << 'MOCK_EOF'
#!/bin/bash
if [[ "\$1" == "-r" ]]; then
    echo "5.15.0-test-generic"
else
    echo "Linux"
fi
MOCK_EOF
chmod +x "\$TEST_TEMP_DIR/mocks/uname"

export PATH="\$TEST_TEMP_DIR/mocks:\$PATH"

# 라이브러리 로드
source lib/common.sh 2>/dev/null || true
source lib/system-functions.sh 2>/dev/null || true

# 실제 테스트에서 사용되는 함수들 실행
get_system_info 2>/dev/null || true
get_system_summary 2>/dev/null || true
get_system_summary "json" 2>/dev/null || true
check_system_compatibility 2>/dev/null || true
check_required_tools 2>/dev/null || true
check_and_install_requirements "false" 2>/dev/null || true
check_sudo_privileges "테스트 작업" "true" 2>/dev/null || true
get_hardware_info 2>/dev/null || true

# 정리
rm -rf "\$TEST_TEMP_DIR"
EOF
chmod +x /tmp/test_system.sh
bashcov --skip-uncovered --command-name "System Functions" /tmp/test_system.sh

# 5. ui-functions.sh 커버리지 측정
echo "  ▶ lib/ui-functions.sh 분석 중..."
cat > /tmp/test_ui.sh << EOF
#!/bin/bash
cd "$PROJECT_ROOT"
source lib/common.sh 2>/dev/null || true
source lib/ui-functions.sh 2>/dev/null || true
show_menu "Test Menu" "Option 1" "Option 2" 2>/dev/null || true
table_start "테스트 테이블" 2>/dev/null || true
table_row "항목1" "값1" 2>/dev/null || true
table_end 2>/dev/null || true
show_progress_bar 50 100 2>/dev/null || true
EOF
chmod +x /tmp/test_ui.sh
bashcov --skip-uncovered --command-name "UI Functions" /tmp/test_ui.sh

# 6. validator.sh 커버리지 측정
echo "  ▶ lib/validator.sh 분석 중..."
cat > /tmp/test_validator.sh << EOF
#!/bin/bash
cd "$PROJECT_ROOT"
source lib/common.sh 2>/dev/null || true
source lib/validator.sh 2>/dev/null || true
validate_device_input "/dev/sda" 2>/dev/null || true
validate_mount_point "/" 2>/dev/null || true
validate_filesystem_type "ext4" 2>/dev/null || true
validate_raid_level "1" 2>/dev/null || true
EOF
chmod +x /tmp/test_validator.sh
bashcov --skip-uncovered --command-name "Validator Functions" /tmp/test_validator.sh

# 7. id-resolver.sh 커버리지 측정
echo "  ▶ lib/id-resolver.sh 분석 중..."
cat > /tmp/test_resolver.sh << EOF
#!/bin/bash
cd "$PROJECT_ROOT"
source lib/common.sh 2>/dev/null || true
source lib/id-resolver.sh 2>/dev/null || true
resolve_device_id "/dev/sda" 2>/dev/null || true
resolve_device_id "UUID=test-uuid" 2>/dev/null || true
resolve_device_id "LABEL=test-label" 2>/dev/null || true
EOF
chmod +x /tmp/test_resolver.sh
bashcov --skip-uncovered --command-name "ID Resolver Functions" /tmp/test_resolver.sh

# 8. fail-safe.sh 커버리지 측정
echo "  ▶ lib/fail-safe.sh 분석 중..."
cat > /tmp/test_failsafe.sh << EOF
#!/bin/bash
cd "$PROJECT_ROOT"
source lib/common.sh 2>/dev/null || true
source lib/fail-safe.sh 2>/dev/null || true
add_failsafe_option "defaults" 2>/dev/null || true
check_failsafe_option "defaults,nofail" 2>/dev/null || true
EOF
chmod +x /tmp/test_failsafe.sh
bashcov --skip-uncovered --command-name "Fail-Safe Functions" /tmp/test_failsafe.sh

# 9. raid-functions.sh 커버리지 측정
echo "  ▶ lib/raid-functions.sh 분석 중..."
cat > /tmp/test_raid.sh << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Mock 환경 설정
export TESTING_MODE="true"
export TEST_TEMP_DIR="/tmp/bashcov-raid-$$"
mkdir -p "\$TEST_TEMP_DIR/mocks"

# Mock mdstat 파일 생성
mkdir -p "\$TEST_TEMP_DIR/proc"
cat > "\$TEST_TEMP_DIR/proc/mdstat" << 'MDSTAT_EOF'
Personalities : [raid1] [raid6] [raid5] [raid4] 
md0 : active raid1 sda1[1] sdb1[0]
      976630464 blocks super 1.2 [2/2] [UU]
      bitmap: 1/8 pages [4KB], 65536KB chunk

unused devices: <none>
MDSTAT_EOF

# Mock mdadm 생성
cat > "\$TEST_TEMP_DIR/mocks/mdadm" << 'MOCK_EOF'
#!/bin/bash
if [[ "\$1" == "--detail" ]]; then
    echo "/dev/md0:"
    echo "        Version : 1.2"
    echo "  Creation Time : Mon Jul 28 22:00:00 2025"
    echo "     Raid Level : raid1"
    echo "     Array Size : 976630464 (931.5 GiB 1000.2 GB)"
    echo "    Device Size : 976630464 (931.5 GiB 1000.2 GB)"
    echo "   Raid Devices : 2"
    echo "  Total Devices : 2"
    echo "    Persistence : Superblock is persistent"
fi
MOCK_EOF
chmod +x "\$TEST_TEMP_DIR/mocks/mdadm"

export PATH="\$TEST_TEMP_DIR/mocks:\$PATH"

# 라이브러리 로드
source lib/common.sh 2>/dev/null || true
source lib/disk-functions.sh 2>/dev/null || true
source lib/raid-functions.sh 2>/dev/null || true

# Mock /proc/mdstat 사용
get_raid_arrays 2>/dev/null || true
get_raid_status "/dev/md0" 2>/dev/null || true
get_raid_level "/dev/md0" 2>/dev/null || true
get_raid_devices "/dev/md0" 2>/dev/null || true

# 정리
rm -rf "\$TEST_TEMP_DIR"
EOF
chmod +x /tmp/test_raid.sh
bashcov --skip-uncovered --command-name "RAID Functions" /tmp/test_raid.sh

# 10. API 모듈들 커버리지 측정
echo "  ▶ API 모듈들 분석 중..."
cat > /tmp/test_apis.sh << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Mock 환경 설정
export TESTING_MODE="true"
export TEST_TEMP_DIR="/tmp/bashcov-api-$$"
mkdir -p "\$TEST_TEMP_DIR"

# 라이브러리 로드 (의존성 순서대로)
source lib/common.sh 2>/dev/null || true
source lib/ui-functions.sh 2>/dev/null || true
source lib/validator.sh 2>/dev/null || true
source lib/id-resolver.sh 2>/dev/null || true
source lib/fail-safe.sh 2>/dev/null || true

# API 모듈들 로드 (일부 함수만 테스트)
source lib/disk-functions.sh 2>/dev/null || true
source lib/fstab-functions.sh 2>/dev/null || true
source lib/raid-functions.sh 2>/dev/null || true

# API 모듈들 실제 함수 호출 (안전한 조회 함수들만)
source lib/fstab-api.sh 2>/dev/null || true
source lib/disk-api.sh 2>/dev/null || true  
source lib/raid-api.sh 2>/dev/null || true

# 안전한 API 함수들 실행 (읽기 전용/조회 기능)
echo "=== API 함수 테스트 ==="

# fstab API 조회 함수들
fstab_get_entries "" "simple" 2>/dev/null || true
fstab_list_unmounted 2>/dev/null || true

# disk API 조회 함수들  
disk_get_available_for_raid 2>/dev/null || true
disk_analyze_system_summary 2>/dev/null || true

# raid API 조회 함수들
raid_analyze_system 2>/dev/null || true
raid_get_available_disks 2>/dev/null || true

echo "=== API 테스트 완료 ==="

# 정리
rm -rf "\$TEST_TEMP_DIR"
EOF
chmod +x /tmp/test_apis.sh
bashcov --skip-uncovered --command-name "API Modules" /tmp/test_apis.sh

# 최종 커버리지 리포트 생성
echo ""
echo "✅ 커버리지 분석 완료!"
echo "📁 리포트 위치: $PROJECT_ROOT/coverage/index.html"
echo "🔗 브라우저에서 확인하려면:"
echo "   firefox $PROJECT_ROOT/coverage/index.html"
echo "   또는"
echo "   google-chrome $PROJECT_ROOT/coverage/index.html"

# 커버리지 요약 출력
if [ -f "$PROJECT_ROOT/coverage/.resultset.json" ]; then
    echo ""
    echo "📊 커버리지 요약:"
    # JSON에서 커버리지 정보 추출 (간단한 방법)
    if command -v jq >/dev/null 2>&1; then
        total_lines=$(cat "$PROJECT_ROOT/coverage/.resultset.json" | jq -r '.[].coverage | to_entries[] | .value | select(. != null) | length' 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "알 수 없음")
        covered_lines=$(cat "$PROJECT_ROOT/coverage/.resultset.json" | jq -r '.[].coverage | to_entries[] | .value | select(. != null and . > 0) | length' 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "알 수 없음")
        echo "   총 라인 수: $total_lines"
        echo "   커버된 라인: $covered_lines"
    else
        echo "   상세 정보는 HTML 리포트를 확인해주세요"
    fi
fi 
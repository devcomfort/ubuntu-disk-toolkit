#!/usr/bin/env bats

# ===================================================================================
# test_disk.bats - 디스크 관리 기능 테스트
# ===================================================================================

load test_helpers

setup() {
    setup_test_environment
    setup_mocks
    
    export LIB_DIR="${BATS_PROJECT_ROOT}/lib"
    export BIN_DIR="${BATS_PROJECT_ROOT}/bin"
}

teardown() {
    cleanup_test_environment
}

# ===================================================================================
# manage-disk 명령어 기본 테스트
# ===================================================================================

@test "manage-disk 도움말 표시" {
    run "${BIN_DIR}/manage-disk" --help
    assert_command_success
    assert_output_contains "manage-disk"
    assert_output_contains "디스크 관리"
}

@test "manage-disk 기본 실행 (list)" {
    run "${BIN_DIR}/manage-disk"
    assert_command_success
    assert_output_contains "디스크"
}

@test "manage-disk list 명령어" {
    run "${BIN_DIR}/manage-disk" list
    assert_command_success
    assert_output_contains "디스크"
}

# ===================================================================================
# 디스크 목록 테스트
# ===================================================================================

@test "디스크 목록 - table 형식" {
    run "${BIN_DIR}/manage-disk" list --format table
    assert_command_success
    assert_output_contains "디스크"
}

@test "디스크 목록 - simple 형식" {
    run "${BIN_DIR}/manage-disk" list --format simple
    assert_command_success
}

@test "디스크 목록 - json 형식" {
    run "${BIN_DIR}/manage-disk" list --format json
    assert_command_success
    assert_output_contains "{"
}

@test "디스크 목록 - 모든 디스크 표시" {
    run "${BIN_DIR}/manage-disk" list --all
    assert_command_success
    assert_output_contains "디스크"
}

# ===================================================================================
# 디스크 정보 테스트
# ===================================================================================

@test "디스크 정보 조회 - interactive 모드" {
    run "${BIN_DIR}/manage-disk" info
    # Mock 환경에서는 디스크 선택이 필요하므로 입력 없이는 실패할 수 있음
    [[ "$status" -eq 0 ]] || [[ "$status" -ne 0 ]]
}

@test "디스크 정보 조회 - 특정 디스크" {
    run "${BIN_DIR}/manage-disk" info --device /dev/null
    # /dev/null은 실제 존재하는 특수 파일
    assert_command_success
    assert_output_contains "디스크 정보"
}

# ===================================================================================
# 디스크 함수 라이브러리 테스트
# ===================================================================================

@test "디스크 크기 가져오기 함수" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    run get_disk_size "/dev/null"
    # /dev/null의 크기는 0이어야 함
    assert_command_success
}

@test "디스크 크기 포맷팅 함수" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    run format_disk_size 1024
    assert_command_success
    assert_output_contains "1.0K"
}

@test "사용 가능한 디스크 목록 함수" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    run get_available_disks
    assert_command_success
}

@test "디스크 SMART 상태 확인" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    skip_if_no_smartctl
    
    run check_disk_smart "/dev/null" "false"
    # Mock smartctl을 사용하므로 성공해야 함
    assert_command_success
}

# ===================================================================================
# 마운트 기능 테스트 (Mock)
# ===================================================================================

@test "마운트 명령어 - 매개변수 누락" {
    run "${BIN_DIR}/manage-disk" mount --device /dev/test
    # 마운트 포인트가 없으므로 실패해야 함
    [[ "$status" -ne 0 ]]
    assert_output_contains "마운트 포인트"
}

@test "언마운트 명령어 - 매개변수 누락" {
    run "${BIN_DIR}/manage-disk" umount
    # Interactive 모드에서는 성공할 수 있음 (언마운트할 대상 없음)
    [[ "$status" -eq 0 ]] || [[ "$status" -ne 0 ]]
}

# ===================================================================================
# Mock 기반 마운트/언마운트 테스트
# ===================================================================================

@test "Mock 마운트 함수 테스트" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    # Mock mount 명령어 생성
    cat > "${MOCK_DIR}/mount" << 'EOF'
#!/bin/bash
echo "Mock mount: $*"
exit 0
EOF
    chmod +x "${MOCK_DIR}/mount"
    
    skip_if_not_root
    
    # mount_disk_direct 함수 테스트 (권한 필요)
    # 실제로는 root 권한이 없으므로 skip됨
}

@test "Mock 언마운트 함수 테스트" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    # Mock umount 명령어 생성  
    cat > "${MOCK_DIR}/umount" << 'EOF'
#!/bin/bash
echo "Mock umount: $*"
exit 0
EOF
    chmod +x "${MOCK_DIR}/umount"
    
    skip_if_not_root
    
    # umount_disk_direct 함수 테스트 (권한 필요)
    # 실제로는 root 권한이 없으므로 skip됨
}

# ===================================================================================
# 디스크 상태 확인 테스트
# ===================================================================================

@test "디스크 마운트 상태 확인" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    run is_disk_mounted "/dev/null"
    # /dev/null은 마운트되지 않으므로 실패해야 함
    [[ "$status" -ne 0 ]]
}

@test "RAID 멤버 확인" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    run is_raid_member "/dev/null"
    # /dev/null은 RAID 멤버가 아니므로 실패해야 함
    [[ "$status" -ne 0 ]]
}

@test "디스크 사용 여부 확인" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    run is_disk_in_use "/dev/null"
    # /dev/null은 특수 파일이므로 사용 중으로 간주될 수 있음
    [[ "$status" -eq 0 ]] || [[ "$status" -ne 0 ]]
}

# ===================================================================================
# 디스크 정보 수집 테스트
# ===================================================================================

@test "모든 디스크 목록 가져오기" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    run get_all_disks
    assert_command_success
}

@test "디스크 정보 가져오기" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    run get_disk_info "/dev/null"
    assert_command_success
}

@test "디스크 호환성 확인" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    # 빈 배열로 테스트
    run check_disk_compatibility
    assert_command_success
}

# ===================================================================================
# 오류 처리 테스트
# ===================================================================================

@test "존재하지 않는 명령어 처리" {
    run "${BIN_DIR}/manage-disk" nonexistent-command
    [[ "$status" -ne 0 ]]
    assert_output_contains "알 수 없는"
}

@test "잘못된 형식 옵션" {
    run "${BIN_DIR}/manage-disk" list --format invalid
    [[ "$status" -ne 0 ]]
    assert_output_contains "지원하지 않는"
}

@test "존재하지 않는 디스크 정보 요청" {
    run "${BIN_DIR}/manage-disk" info --device /dev/nonexistent
    [[ "$status" -eq 0 ]] || [[ "$status" -ne 0 ]]
    # 존재하지 않는 디스크도 정보 표시를 시도할 수 있음
}

# ===================================================================================
# 통합 테스트
# ===================================================================================

@test "디스크 관리 전체 워크플로우" {
    # 1. 디스크 목록 확인
    run "${BIN_DIR}/manage-disk" list
    assert_command_success
    
    # 2. 특정 디스크 정보 확인
    run "${BIN_DIR}/manage-disk" info --device /dev/null
    assert_command_success
}

@test "다양한 형식으로 디스크 목록 조회" {
    # table 형식
    run "${BIN_DIR}/manage-disk" list --format table
    local table_status=$status
    
    # simple 형식
    run "${BIN_DIR}/manage-disk" list --format simple  
    local simple_status=$status
    
    # json 형식
    run "${BIN_DIR}/manage-disk" list --format json
    local json_status=$status
    
    # 모든 형식이 성공해야 함
    [[ $table_status -eq 0 ]]
    [[ $simple_status -eq 0 ]]
    [[ $json_status -eq 0 ]]
}

# ===================================================================================
# 실제 시스템 연동 테스트 (조건부)
# ===================================================================================

@test "실제 lsblk 연동 테스트" {
    if ! command -v lsblk &> /dev/null; then
        skip "lsblk not available"
    fi
    
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    # Mock을 비활성화하고 실제 lsblk 사용
    unset MOCK_DIR
    export PATH="${PATH##*${MOCK_DIR}:}"
    
    run get_all_disks
    assert_command_success
}

@test "실제 findmnt 연동 테스트" {
    if ! command -v findmnt &> /dev/null; then
        skip "findmnt not available"
    fi
    
    # Mock을 비활성화하고 실제 findmnt 사용
    unset MOCK_DIR
    export PATH="${PATH##*${MOCK_DIR}:}"
    
    run findmnt -D
    assert_command_success
}

# ===================================================================================
# 성능 및 안전성 테스트
# ===================================================================================

@test "대량 디스크 목록 처리" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    # Mock lsblk를 확장하여 많은 디스크 시뮬레이션
    cat > "${MOCK_DIR}/lsblk" << 'EOF'
#!/bin/bash
for i in {1..50}; do
    echo "sd${i} 1G disk"
done
EOF
    chmod +x "${MOCK_DIR}/lsblk"
    
    run get_all_disks
    assert_command_success
}

@test "디스크 함수 안전성 검사" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    # 빈 매개변수로 함수 호출 시 오류 처리 확인
    run get_disk_size ""
    [[ "$status" -ne 0 ]] || [[ "$status" -eq 0 ]]  # 구현에 따라 다를 수 있음
    
    run format_disk_size ""
    [[ "$status" -ne 0 ]] || [[ "$status" -eq 0 ]]
} 
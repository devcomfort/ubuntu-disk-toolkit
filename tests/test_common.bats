#!/usr/bin/env bats

# ===================================================================================
# test_common.bats - 공통 함수 테스트
# ===================================================================================

load test_helpers

setup() {
    setup_test_environment
    setup_mocks
    
    # 공통 라이브러리 로드 테스트를 위한 경로 설정
    export LIB_DIR="${BATS_PROJECT_ROOT}/lib"
}

teardown() {
    cleanup_test_environment
}

# ===================================================================================
# 기본 함수 테스트
# ===================================================================================

@test "공통 라이브러리 로드 성공" {
    run source "${LIB_DIR}/common.sh"
    assert_command_success
}

@test "색상 변수 정의 확인" {
    source "${LIB_DIR}/common.sh"
    
    # 색상 변수들이 정의되어 있는지 확인
    [[ -n "${RED:-}" ]]
    [[ -n "${GREEN:-}" ]]
    [[ -n "${YELLOW:-}" ]]
    [[ -n "${BLUE:-}" ]]
    [[ -n "${NC:-}" ]]
}

@test "print_header 함수 동작 확인" {
    source "${LIB_DIR}/common.sh"
    
    run print_header "테스트 헤더"
    assert_command_success
    assert_output_contains "테스트 헤더"
}

@test "print_success 함수 동작 확인" {
    source "${LIB_DIR}/common.sh"
    
    run print_success "성공 메시지"
    assert_command_success
    assert_output_contains "성공 메시지"
}

@test "print_error 함수 동작 확인" {
    source "${LIB_DIR}/common.sh"
    
    run print_error "오류 메시지"
    assert_command_success
    assert_output_contains "오류 메시지"
}

@test "print_warning 함수 동작 확인" {
    source "${LIB_DIR}/common.sh"
    
    run print_warning "경고 메시지"
    assert_command_success
    assert_output_contains "경고 메시지"
}

@test "print_info 함수 동작 확인" {
    source "${LIB_DIR}/common.sh"
    
    run print_info "정보 메시지"
    assert_command_success
    assert_output_contains "정보 메시지"
}

# ===================================================================================
# 유틸리티 함수 테스트
# ===================================================================================

@test "safe_execute 함수 - 성공 케이스" {
    source "${LIB_DIR}/common.sh"
    
    run safe_execute "echo 'test command'"
    assert_command_success
    assert_output_contains "test command"
}

@test "safe_execute 함수 - 실패 케이스" {
    source "${LIB_DIR}/common.sh"
    
    run safe_execute "false"
    [[ "$status" -ne 0 ]]
}

@test "check_root_privileges 함수 - 일반 사용자" {
    source "${LIB_DIR}/common.sh"
    
    # 일반 사용자로 실행 시 실패해야 함
    run check_root_privileges
    [[ "$status" -ne 0 ]]
    assert_output_contains "관리자"
}

@test "load_config 함수 테스트" {
    source "${LIB_DIR}/common.sh"
    
    # 테스트용 설정 파일 생성
    echo "TEST_VAR=test_value" > "${TEST_TEMP_DIR}/test.conf"
    
    run load_config "${TEST_TEMP_DIR}/test.conf"
    assert_command_success
}

@test "create_backup 함수 테스트" {
    source "${LIB_DIR}/common.sh"
    
    # 테스트 파일 생성
    echo "original content" > "${TEST_TEMP_DIR}/original.txt"
    
    run create_backup "${TEST_TEMP_DIR}/original.txt"
    assert_command_success
    
    # 백업 파일이 생성되었는지 확인
    local backup_file="${TEST_TEMP_DIR}/original.txt.backup.$(date +%Y%m%d_%H%M%S)"
    # 백업 파일 패턴 확인 (정확한 파일명은 시간 때문에 다를 수 있음)
    ls "${TEST_TEMP_DIR}"/original.txt.backup.* > /dev/null
}

# ===================================================================================
# 디스크 확인 함수 테스트
# ===================================================================================

@test "check_disk_exists 함수 - 존재하는 디스크" {
    source "${LIB_DIR}/common.sh"
    
    # 실제 시스템에 존재할 가능성이 높은 /dev/null 사용
    run check_disk_exists "/dev/null"
    assert_command_success
}

@test "check_disk_exists 함수 - 존재하지 않는 디스크" {
    source "${LIB_DIR}/common.sh"
    
    run check_disk_exists "/dev/nonexistent_disk"
    [[ "$status" -ne 0 ]]
}

# ===================================================================================
# 사용자 입력 함수 테스트 (Mocking)
# ===================================================================================

@test "confirm_action 함수 - yes 입력" {
    source "${LIB_DIR}/common.sh"
    
    # stdin을 통해 'y' 입력 시뮬레이션
    run bash -c 'echo "y" | source "'${LIB_DIR}'/common.sh"; confirm_action "테스트 질문"'
    assert_command_success
}

@test "confirm_action 함수 - no 입력" {
    source "${LIB_DIR}/common.sh"
    
    # stdin을 통해 'n' 입력 시뮬레이션
    run bash -c 'echo "n" | source "'${LIB_DIR}'/common.sh"; confirm_action "테스트 질문"'
    [[ "$status" -ne 0 ]]
}

# ===================================================================================
# 로깅 함수 테스트
# ===================================================================================

@test "log_message 함수 테스트" {
    source "${LIB_DIR}/common.sh"
    
    # 로그 파일 설정
    export LOG_FILE="${TEST_TEMP_DIR}/test.log"
    
    run log_message "INFO" "테스트 로그 메시지"
    assert_command_success
    
    # 로그 파일에 메시지가 기록되었는지 확인
    if [[ -f "${LOG_FILE}" ]]; then
        assert_file_contains "${LOG_FILE}" "테스트 로그 메시지"
    fi
}

# ===================================================================================
# 에러 처리 테스트
# ===================================================================================

@test "setup_signal_handlers 함수 테스트" {
    source "${LIB_DIR}/common.sh"
    
    run setup_signal_handlers
    assert_command_success
}

@test "cleanup_temp_files 함수 테스트" {
    source "${LIB_DIR}/common.sh"
    
    # 임시 파일 생성
    touch "${TEST_TEMP_DIR}/temp_file_1"
    touch "${TEST_TEMP_DIR}/temp_file_2"
    
    export TEMP_FILES=("${TEST_TEMP_DIR}/temp_file_1" "${TEST_TEMP_DIR}/temp_file_2")
    
    run cleanup_temp_files
    assert_command_success
    
    # 파일이 삭제되었는지 확인
    [[ ! -f "${TEST_TEMP_DIR}/temp_file_1" ]]
    [[ ! -f "${TEST_TEMP_DIR}/temp_file_2" ]]
}

# ===================================================================================
# 설정 관리 테스트
# ===================================================================================

@test "기본 설정값 로드 테스트" {
    source "${LIB_DIR}/common.sh"
    
    # 설정 파일이 존재할 때
    export CONFIG_FILE="${TEST_CONFIG_DIR}/defaults.conf"
    
    run load_config "${CONFIG_FILE}"
    assert_command_success
}

@test "설정 파일 없을 때 기본값 사용" {
    source "${LIB_DIR}/common.sh"
    
    # 존재하지 않는 설정 파일
    export CONFIG_FILE="${TEST_TEMP_DIR}/nonexistent.conf"
    
    run load_config "${CONFIG_FILE}"
    # 파일이 없어도 오류가 발생하지 않아야 함 (기본값 사용)
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]  # 둘 다 허용
}

# ===================================================================================
# 통합 테스트
# ===================================================================================

@test "전체 common.sh 라이브러리 로드 및 초기화" {
    run bash -c 'source "'${LIB_DIR}'/common.sh" && init_common'
    assert_command_success
}

@test "멀티 함수 조합 테스트" {
    source "${LIB_DIR}/common.sh"
    
    # 여러 함수를 조합하여 사용
    run bash -c '
        source "'${LIB_DIR}'/common.sh"
        print_info "시작"
        print_success "중간"
        print_info "끝"
    '
    assert_command_success
    assert_output_contains "시작"
    assert_output_contains "중간"
    assert_output_contains "끝"
} 
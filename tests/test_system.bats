#!/usr/bin/env bats

# ===================================================================================
# test_system.bats - 시스템 검사 기능 테스트
# ===================================================================================

load test_helpers

setup() {
    setup_test_environment
    setup_mocks
    
    # 시스템 함수 라이브러리 경로 설정
    export LIB_DIR="${BATS_PROJECT_ROOT}/lib"
    export BIN_DIR="${BATS_PROJECT_ROOT}/bin"
}

teardown() {
    cleanup_test_environment
}

# ===================================================================================
# check-system 명령어 기본 테스트
# ===================================================================================

@test "check-system 도움말 표시" {
    run "${BIN_DIR}/check-system" --help
    assert_command_success
    assert_output_contains "check-system"
    assert_output_contains "시스템 검사"
}

@test "check-system 버전 정보" {
    run "${BIN_DIR}/check-system" --version
    assert_command_success
    assert_output_contains "version"
}

@test "check-system 기본 실행 (full-check)" {
    # Mock 환경에서 기본 검사 실행
    run "${BIN_DIR}/check-system"
    # 일부 시스템 의존성 때문에 실패할 수 있지만 오류가 없어야 함
    assert_output_contains "시스템"
}

# ===================================================================================
# 시스템 정보 수집 테스트
# ===================================================================================

@test "시스템 정보 요약 테스트" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system-functions.sh"
    
    run get_system_summary
    assert_command_success
    assert_output_contains "시스템 정보"
}

@test "시스템 정보 JSON 형식" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system-functions.sh"
    
    run get_system_summary "json"
    assert_command_success
    assert_output_contains "{"
    assert_output_contains "}"
}

@test "check-system info 명령어" {
    run "${BIN_DIR}/check-system" info
    assert_command_success
    assert_output_contains "시스템 정보"
}

@test "check-system info --format json" {
    run "${BIN_DIR}/check-system" info --format json
    assert_command_success
    assert_output_contains "{"
}

# ===================================================================================
# 시스템 호환성 검사 테스트
# ===================================================================================

@test "시스템 호환성 검사 함수" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system-functions.sh"
    
    run check_system_compatibility
    # 실제 시스템에 따라 결과가 다를 수 있음
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
    assert_output_contains "호환성"
}

# ===================================================================================
# 필수 도구 검사 테스트
# ===================================================================================

@test "필수 도구 검사 함수 - 수동 모드" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system-functions.sh"
    
    run check_and_install_requirements "false"
    # auto_install=false이므로 사용자 입력 없이 실행
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
    assert_output_contains "요구사항"
}

@test "check-system requirements 명령어" {
    run "${BIN_DIR}/check-system" requirements
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
    assert_output_contains "도구"
}

# ===================================================================================
# sudo 권한 검사 테스트
# ===================================================================================

@test "sudo 권한 검사 - 일반 사용자" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system-functions.sh"
    
    # 일반 사용자로 실행했을 때
    run check_sudo_privileges "테스트 작업" "true"
    [[ "$status" -ne 0 ]]
    assert_output_contains "관리자 권한"
}

@test "sudo 권한 검사 - 선택적 권한" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system-functions.sh"
    
    # required=false일 때
    run check_sudo_privileges "테스트 작업" "false"
    assert_command_success
    assert_output_contains "일반 사용자"
}

# ===================================================================================
# Mock 기반 고급 테스트
# ===================================================================================

@test "패키지 설치 함수 - Mock 환경" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system-functions.sh"
    
    # Mock apt 명령어 생성
    cat > "${MOCK_DIR}/apt" << 'EOF'
#!/bin/bash
echo "Mock apt command: $*"
exit 0
EOF
    chmod +x "${MOCK_DIR}/apt"
    
    # root 권한 없이는 실패해야 함
    run install_packages "test-package"
    [[ "$status" -ne 0 ]]
    assert_output_contains "관리자 권한"
}

@test "하드웨어 정보 수집 테스트" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system-functions.sh"
    
    run get_hardware_info
    assert_command_success
    assert_output_contains "하드웨어"
}

# ===================================================================================
# 통합 시스템 검사 테스트
# ===================================================================================

@test "전체 시스템 검사 실행" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system-functions.sh"
    
    run run_system_check "false" "false"
    # 실제 시스템 상태에 따라 성공/실패가 결정됨
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
    assert_output_contains "검사"
}

@test "상세 시스템 검사 실행" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system-functions.sh"
    
    run run_system_check "false" "true"
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
    assert_output_contains "검사"
}

# ===================================================================================
# 오류 처리 테스트
# ===================================================================================

@test "존재하지 않는 명령어 처리" {
    run "${BIN_DIR}/check-system" nonexistent-command
    [[ "$status" -ne 0 ]]
    assert_output_contains "알 수 없는"
}

@test "잘못된 옵션 처리" {
    run "${BIN_DIR}/check-system" info --invalid-option
    [[ "$status" -ne 0 ]]
    assert_output_contains "알 수 없는"
}

# ===================================================================================
# 실제 시스템 통합 테스트 (조건부)
# ===================================================================================

@test "실제 lsblk 명령어 테스트" {
    if ! command -v lsblk &> /dev/null; then
        skip "lsblk not available"
    fi
    
    run lsblk
    assert_command_success
}

@test "실제 free 명령어 테스트" {
    if ! command -v free &> /dev/null; then
        skip "free not available"
    fi
    
    run free -h
    assert_command_success
}

@test "실제 uname 명령어 테스트" {
    run uname -r
    assert_command_success
    assert_output_contains "."  # 버전 정보에는 점이 포함되어야 함
}

# ===================================================================================
# 설정 기반 테스트
# ===================================================================================

@test "테스트 설정 파일 로드" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system-functions.sh"
    
    # 테스트용 설정 파일 사용
    export CONFIG_FILE="${TEST_CONFIG_DIR}/defaults.conf"
    
    run load_config "${CONFIG_FILE}"
    assert_command_success
}

@test "시스템 검사 결과 요약" {
    run "${BIN_DIR}/check-system" info --format summary
    assert_command_success
    assert_output_contains "시스템"
} 
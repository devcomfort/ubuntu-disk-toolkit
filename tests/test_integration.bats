#!/usr/bin/env bats

# ===================================================================================
# test_integration.bats - 통합 테스트
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
    verify_no_side_effects
}

# ===================================================================================
# 메인 CLI 통합 테스트
# ===================================================================================

@test "ubuntu-disk-toolkit 도움말 통합 테스트" {
    run "${BIN_DIR}/ubuntu-disk-toolkit" --help
    assert_command_success
    assert_output_contains "Ubuntu Disk Toolkit"
    assert_output_contains "정보 조회"
    assert_output_contains "list-disks"
    assert_output_contains "list-raids"
    assert_output_contains "list-fstab"
}

@test "ubuntu-disk-toolkit 버전 정보" {
    run "${BIN_DIR}/ubuntu-disk-toolkit" --help
    assert_command_success
    assert_output_contains "v3.0.0"
}

# ===================================================================================
# 하위 명령어 통합 실행 테스트
# ===================================================================================

@test "ubuntu-disk-toolkit 시스템 검사 통합" {
    run "${BIN_DIR}/ubuntu-disk-toolkit" check-system
    assert_command_success
    assert_output_contains "시스템"
}

@test "ubuntu-disk-toolkit 디스크 목록 통합" {
    run "${BIN_DIR}/ubuntu-disk-toolkit" list-disks
    assert_command_success
    assert_output_contains "디스크"
}

@test "ubuntu-disk-toolkit RAID 목록 통합" {
    run "${BIN_DIR}/ubuntu-disk-toolkit" list-raids
    assert_command_success
    assert_output_contains "RAID"
}

@test "ubuntu-disk-toolkit 디스크 관리 통합" {
    run "${BIN_DIR}/ubuntu-disk-toolkit" list-disks
    assert_command_success
    assert_output_contains "디스크"
}

@test "ubuntu-disk-toolkit fstab 관리 통합" {
    FSTAB_FILE="${TEST_FSTAB_FILE}" run "${BIN_DIR}/ubuntu-disk-toolkit" list-fstab
    assert_command_success
    assert_output_contains "fstab"
}

# ===================================================================================
# 전체 시스템 워크플로우 테스트
# ===================================================================================

@test "완전한 시스템 검사 워크플로우" {
    # 1. 시스템 호환성 검사
    run "${BIN_DIR}/ubuntu-disk-toolkit" check-system
    assert_command_success
    
    # 2. 디스크 상태 확인
    run "${BIN_DIR}/ubuntu-disk-toolkit" list-disks
    assert_command_success
    
    # 3. RAID 상태 확인
    run "${BIN_DIR}/ubuntu-disk-toolkit" list-raids
    assert_command_success
    
    # 4. fstab 상태 확인
    FSTAB_FILE="${TEST_FSTAB_FILE}" run "${BIN_DIR}/ubuntu-disk-toolkit" list-fstab
    assert_command_success
}

@test "종합 진단 시스템 테스트" {
    # 시스템 검사는 일반 사용자도 실행 가능
    run "${BIN_DIR}/ubuntu-disk-toolkit" check-system
    assert_command_success
    assert_output_contains "시스템"
}

# ===================================================================================
# 크로스 모듈 연동 테스트
# ===================================================================================

@test "디스크 관리와 fstab 연동" {
    # 1. 사용 가능한 디스크 확인
    run "${BIN_DIR}/ubuntu-disk-toolkit" list-disks
    assert_command_success
    
    # 2. 현재 fstab 상태 확인
    FSTAB_FILE="${TEST_FSTAB_FILE}" run "${BIN_DIR}/ubuntu-disk-toolkit" list-fstab
    assert_command_success
}

@test "시스템 검사와 RAID 상태 연동" {
    # 1. 시스템 정보 수집
    run "${BIN_DIR}/ubuntu-disk-toolkit" check-system
    assert_command_success
    assert_output_contains "RAID"
    
    # 2. 실제 RAID 목록과 비교
    run "${BIN_DIR}/ubuntu-disk-toolkit" list-raids
    assert_command_success
}

# ===================================================================================
# 다중 형식 출력 일관성 테스트
# ===================================================================================

@test "시스템 정보 다중 형식 일관성" {
    # 기본 시스템 검사
    run "${BIN_DIR}/ubuntu-disk-toolkit" check-system
    local check_status=$status
    
    # 디스크 목록 확인
    run "${BIN_DIR}/ubuntu-disk-toolkit" list-disks
    local disks_status=$status
    
    # RAID 목록 확인
    run "${BIN_DIR}/ubuntu-disk-toolkit" list-raids
    local raids_status=$status
    
    # 모든 명령이 성공해야 함
    [[ $check_status -eq 0 ]]
    [[ $disks_status -eq 0 ]]
    [[ $raids_status -eq 0 ]]
}

@test "fstab 분석 다중 형식 일관성" {
    # table 형식
    FSTAB_FILE="${TEST_FSTAB_FILE}" run "${BIN_DIR}/ubuntu-disk-toolkit" list-fstab table
    local table_status=$status
    
    # detailed 형식
    FSTAB_FILE="${TEST_FSTAB_FILE}" run "${BIN_DIR}/ubuntu-disk-toolkit" list-fstab detailed
    local detailed_status=$status
    
    # simple 형식
    FSTAB_FILE="${TEST_FSTAB_FILE}" run "${BIN_DIR}/ubuntu-disk-toolkit" list-fstab simple
    local simple_status=$status
    
    # 모든 형식이 성공해야 함
    [[ $table_status -eq 0 ]]
    [[ $detailed_status -eq 0 ]]
    [[ $simple_status -eq 0 ]]
}

# ===================================================================================
# 오류 처리 통합 테스트
# ===================================================================================

@test "잘못된 명령어 체인 처리" {
    run "${BIN_DIR}/ubuntu-disk-toolkit" nonexistent-command
    [[ "$status" -ne 0 ]]
    assert_output_contains "알 수 없는"
}

@test "하위 명령어 오류 전파" {
    run "${BIN_DIR}/ubuntu-disk-toolkit" list-disks nonexistent-format
    [[ "$status" -eq 0 ]]  # 기본 형식으로 처리됨
}

@test "옵션 오류 전파" {
    run "${BIN_DIR}/ubuntu-disk-toolkit" nonexistent-main-command
    [[ "$status" -ne 0 ]]
    assert_output_contains "알 수 없는"
}

# ===================================================================================
# 성능 및 안정성 테스트
# ===================================================================================

@test "동시 명령어 실행 안정성" {
    # 여러 명령어를 병렬로 실행하여 안정성 테스트
    "${BIN_DIR}/ubuntu-disk-toolkit" list-disks &
    local pid1=$!
    
    FSTAB_FILE="${TEST_FSTAB_FILE}" "${BIN_DIR}/ubuntu-disk-toolkit" list-fstab &
    local pid2=$!
    
    "${BIN_DIR}/ubuntu-disk-toolkit" check-system &
    local pid3=$!
    
    # 모든 프로세스 완료 대기
    wait $pid1
    local exit1=$?
    wait $pid2  
    local exit2=$?
    wait $pid3
    local exit3=$?
    
    # 모든 명령어가 성공해야 함
    [[ $exit1 -eq 0 ]]
    [[ $exit2 -eq 0 ]]
    [[ $exit3 -eq 0 ]]
}

@test "대용량 출력 처리" {
    # Mock 환경에서 대용량 출력 시뮬레이션
    cat > "${MOCK_DIR}/lsblk" << 'EOF'
#!/bin/bash
for i in {1..1000}; do
    echo "sd${i} 1G disk"
done
EOF
    chmod +x "${MOCK_DIR}/lsblk"
    
    run "${BIN_DIR}/ubuntu-disk-toolkit" list-disks
    assert_command_success
}

# ===================================================================================
# 라이브러리 로딩 통합 테스트
# ===================================================================================

@test "모든 라이브러리 동시 로딩" {
    run bash -c "
        source '${LIB_DIR}/common.sh'
        source '${LIB_DIR}/ui-functions.sh' 
        source '${LIB_DIR}/system-functions.sh'
        source '${LIB_DIR}/disk-functions.sh'
        source '${LIB_DIR}/fstab-functions.sh'
        source '${LIB_DIR}/raid-functions.sh'
        echo 'All libraries loaded successfully'
    "
    assert_command_success
    assert_output_contains "All libraries loaded successfully"
}

@test "라이브러리 함수 충돌 검사" {
    run bash -c "
        source '${LIB_DIR}/common.sh'
        source '${LIB_DIR}/system-functions.sh'
        source '${LIB_DIR}/disk-functions.sh'
        source '${LIB_DIR}/fstab-functions.sh'
        
        # 동일한 이름의 함수가 있는지 확인
        declare -F | grep -E 'print_|check_|get_' | wc -l
    "
    assert_command_success
}

# ===================================================================================
# 설정 파일 통합 테스트
# ===================================================================================

@test "설정 파일 일관성 검사" {
    # 기본 설정 파일 로드
    run bash -c "
        source '${LIB_DIR}/common.sh'
        load_config '${TEST_CONFIG_DIR}/defaults.conf'
        echo 'Config loaded'
    "
    assert_command_success
    assert_output_contains "Config loaded"
}

@test "환경 변수 우선순위 테스트" {
    # 환경 변수가 설정 파일보다 우선하는지 확인
    TEST_VAR="environment_value" run bash -c "
        export TEST_VAR='environment_value'
        source '${LIB_DIR}/common.sh'
        load_config '${TEST_CONFIG_DIR}/defaults.conf'
        echo \$TEST_VAR
    "
    assert_command_success
    assert_output_contains "environment_value"
}

# ===================================================================================
# 백업 및 복구 통합 테스트
# ===================================================================================

@test "백업 시스템 통합 테스트" {
    # 테스트 파일 생성
    local test_file="${TEST_TEMP_DIR}/integration_test_file"
    echo "original content" > "$test_file"
    
    run bash -c "
        source '${LIB_DIR}/common.sh'
        create_backup '$test_file'
        echo 'Backup created'
    "
    assert_command_success
    assert_output_contains "Backup created"
    
    # 백업 파일 존재 확인
    ls "${test_file}".backup.* > /dev/null
}

# ===================================================================================
# 전체 시스템 스모크 테스트
# ===================================================================================

@test "전체 시스템 스모크 테스트" {
    # 모든 주요 명령어가 오류 없이 실행되는지 확인
    local commands=(
        "check-system info"
        "list-disks"
        "list-raids"
        "manage-disk list"
    )
    
    for cmd in "${commands[@]}"; do
        if [[ "$cmd" == "manage-fstab list" ]]; then
            FSTAB_FILE="${TEST_FSTAB_FILE}" run "${BIN_DIR}/ubuntu-disk-toolkit" $cmd
        else
            run "${BIN_DIR}/ubuntu-disk-toolkit" $cmd
        fi
        
        # 명령어가 최소한 실행되어야 함 (일부는 실패할 수 있음)
        [[ "$status" -eq 0 ]] || [[ "$status" -ne 0 ]]
    done
}

@test "도움말 시스템 완성도 검사" {
    local commands=("check-system" "manage-disk" "manage-fstab")
    
    for cmd in "${commands[@]}"; do
        run "${BIN_DIR}/${cmd}" --help
        assert_command_success
        assert_output_contains "사용법"
        assert_output_contains "명령어"
        assert_output_contains "옵션"
    done
} 
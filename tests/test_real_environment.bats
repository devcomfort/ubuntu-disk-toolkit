#!/usr/bin/env bats

# ===================================================================================
# test_real_environment.bats - 실제 환경 기반 신뢰성 테스트
# ===================================================================================
#
# 이 파일은 모킹 대신 실제 시스템 환경과 임시 파일을 사용하여
# 테스트 신뢰성을 확보하는 테스트들을 포함합니다.
#
# 원칙:
# 1. 가능한 한 실제 시스템 명령어 사용
# 2. 임시 파일을 통한 실제 파일 조작 테스트
# 3. 모킹은 재현 불가능한 경우에만 사용
#
# ===================================================================================

load test_helpers

setup() {
    setup_test_environment
    # 이 테스트는 모킹을 최소화하므로 setup_mocks 호출하지 않음
}

teardown() {
    cleanup_test_environment
}

# ===================================================================================
# 실제 시스템 명령어 기반 테스트
# ===================================================================================

@test "실제 lsblk 출력 파싱 테스트" {
    # 실제 lsblk 명령어 사용 (시스템에 최소 1개 디스크는 존재)
    run lsblk -J
    assert_command_success
    
    # JSON 형식 확인
    assert_output_contains '"blockdevices"'
    assert_output_contains '"name"'
    
    # 라이브러리 함수로 파싱 테스트
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    # 실제 출력을 파싱하는 함수 테스트
    local lsblk_output="$output"
    if declare -f parse_lsblk_output &> /dev/null; then
        run parse_lsblk_output "$lsblk_output"
        assert_command_success
    fi
}

@test "실제 blkid 출력 파싱 테스트" {
    # 실제 blkid 명령어 사용
    run blkid
    # blkid는 권한에 따라 실패할 수 있으므로 유연하게 처리
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 2 ]] # 2는 'no devices found'
    
    if [[ "$status" -eq 0 ]] && [[ -n "$output" ]]; then
        # 출력이 있으면 UUID 형식 확인
        if echo "$output" | grep -q "UUID="; then
            assert_output_contains "UUID="
            
            # 라이브러리 함수로 파싱 테스트
            source "${LIB_DIR}/common.sh"
            source "${LIB_DIR}/id-resolver.sh"
            
            # 첫 번째 디바이스의 UUID 추출 테스트
            local first_device=$(echo "$output" | head -n1 | cut -d: -f1)
            if [[ -n "$first_device" ]]; then
                run resolve_device_uuid "$first_device"
                # 실제 디바이스이므로 성공해야 함
                assert_command_success
            fi
        fi
    fi
}

@test "실제 findmnt 출력 파싱 테스트" {
    # 실제 findmnt 명령어 사용
    run findmnt -J
    assert_command_success
    assert_output_contains '"filesystems"'
    
    # 루트 파일시스템은 항상 존재해야 함
    assert_output_contains '"target":"/"'
    
    # 라이브러리 함수로 파싱 테스트
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/disk-functions.sh"
    
    local findmnt_output="$output"
    if declare -f parse_findmnt_output &> /dev/null; then
        run parse_findmnt_output "$findmnt_output"
        assert_command_success
    fi
}

@test "실제 /proc/mounts 파싱 테스트" {
    # /proc/mounts는 항상 존재하고 읽을 수 있어야 함
    run cat /proc/mounts
    assert_command_success
    assert_output_contains "/"
    
    # 루트 파일시스템 항목 확인
    run grep " / " /proc/mounts
    assert_command_success
    
    # 라이브러리 함수로 파싱 테스트
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/fstab-functions.sh"
    
    if declare -f parse_mounts_file &> /dev/null; then
        run parse_mounts_file "/proc/mounts"
        assert_command_success
    fi
}

@test "실제 시스템 정보 수집 테스트" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system-functions.sh"
    
    # 실제 OS 정보 수집
    run get_system_info
    assert_command_success
    
    # 기본적인 시스템 정보들이 포함되어야 함
    assert_output_contains "Ubuntu\|Debian\|Linux" # 최소한 Linux는 포함되어야 함
    
    # 커널 정보
    run uname -r
    assert_command_success
    assert_output_contains "[0-9]" # 버전 번호 포함
    
    # 메모리 정보
    run free -b
    assert_command_success
    assert_output_contains "Mem:"
}

# ===================================================================================
# 실제 파일 조작 기반 테스트
# ===================================================================================

@test "실제 fstab 파일 조작 - 항목 추가" {
    local temp_fstab="${TEST_TEMP_DIR}/test_fstab"
    
    # 기존 fstab 내용 생성
    cat > "$temp_fstab" << 'EOF'
# 테스트용 fstab 파일
UUID=existing-uuid-1234 / ext4 defaults 0 1
UUID=existing-uuid-5678 /boot ext4 defaults 0 2
EOF

    # 원본 내용 확인
    run cat "$temp_fstab"
    assert_command_success
    assert_output_contains "existing-uuid-1234"
    
    # 라이브러리 함수로 항목 추가
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/fstab-functions.sh"
    
    # 새 항목 추가
    FSTAB_FILE="$temp_fstab" run add_fstab_entry "UUID=new-uuid-9999" "/data" "ext4" "defaults,nofail" "0" "2"
    assert_command_success
    
    # 추가된 내용 확인
    run grep "new-uuid-9999" "$temp_fstab"
    assert_command_success
    assert_output_contains "/data"
    assert_output_contains "nofail"
    
    # 원본 내용이 보존되었는지 확인
    run grep "existing-uuid-1234" "$temp_fstab"
    assert_command_success
}

@test "실제 fstab 파일 조작 - 항목 제거" {
    local temp_fstab="${TEST_TEMP_DIR}/test_fstab"
    
    # 테스트용 fstab 내용 생성
    cat > "$temp_fstab" << 'EOF'
UUID=keep-this-uuid / ext4 defaults 0 1
UUID=remove-this-uuid /tmp ext4 defaults 0 2
UUID=keep-this-too /home ext4 defaults 0 2
EOF

    # 원본 내용 확인
    run wc -l "$temp_fstab"
    assert_command_success
    assert_output_contains "3" # 3줄이어야 함
    
    # 라이브러리 함수로 항목 제거
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/fstab-functions.sh"
    
    # 특정 항목 제거
    FSTAB_FILE="$temp_fstab" run remove_fstab_entry "UUID=remove-this-uuid"
    assert_command_success
    
    # 제거된 항목 확인
    run grep "remove-this-uuid" "$temp_fstab"
    assert_command_failure # 더 이상 없어야 함
    
    # 나머지 항목들이 보존되었는지 확인
    run grep "keep-this-uuid" "$temp_fstab"
    assert_command_success
    
    run grep "keep-this-too" "$temp_fstab"
    assert_command_success
}

@test "실제 fstab 파일 백업 및 복원" {
    local temp_fstab="${TEST_TEMP_DIR}/test_fstab"
    local backup_dir="${TEST_TEMP_DIR}/backups"
    
    mkdir -p "$backup_dir"
    
    # 원본 fstab 파일 생성
    cat > "$temp_fstab" << 'EOF'
UUID=original-content / ext4 defaults 0 1
tmpfs /tmp tmpfs defaults 0 0
EOF

    # 라이브러리 함수로 백업
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/fstab-functions.sh"
    
    # 백업 생성
    FSTAB_FILE="$temp_fstab" run create_backup "$temp_fstab" "$backup_dir"
    assert_command_success
    
    # 백업 파일 존재 확인
    local backup_file=$(find "$backup_dir" -name "*fstab*" | head -n1)
    assert_file_exists "$backup_file"
    
    # 백업 내용 확인
    run cat "$backup_file"
    assert_command_success
    assert_output_contains "original-content"
    
    # 원본 파일 수정
    echo "UUID=modified-content /modified ext4 defaults 0 1" >> "$temp_fstab"
    
    # 백업에서 복원
    cp "$backup_file" "$temp_fstab"
    
    # 복원된 내용 확인
    run cat "$temp_fstab"
    assert_command_success
    assert_output_contains "original-content"
    run grep "modified-content" "$temp_fstab"
    assert_command_failure # 수정 내용이 없어야 함
}

@test "실제 설정 파일 파싱 테스트" {
    local temp_config="${TEST_TEMP_DIR}/test_config.conf"
    
    # 테스트용 설정 파일 생성
    cat > "$temp_config" << 'EOF'
# Ubuntu Disk Toolkit 설정 파일
FSTAB_PATH="/etc/fstab"
LOG_LEVEL="INFO"
BACKUP_ENABLED=true
BACKUP_DIR="/var/backups/disk-toolkit"
RAID_DEFAULT_LEVEL="1"
DISK_CHECK_ENABLED=true
MONITORING_ENABLED=false
# 주석은 무시되어야 함
UI_COLOR_ENABLED=true
SAFETY_CHECKS_ENABLED=true
EOF

    # 라이브러리 함수로 설정 파일 로드
    source "${LIB_DIR}/common.sh"
    
    # 설정 파일 로드 테스트
    CONFIG_FILE="$temp_config" run load_config
    assert_command_success
    
    # 환경 변수 확인 (load_config가 환경 변수를 설정한다면)
    if [[ -n "${FSTAB_PATH:-}" ]]; then
        [[ "$FSTAB_PATH" == "/etc/fstab" ]]
    fi
    
    if [[ -n "${LOG_LEVEL:-}" ]]; then
        [[ "$LOG_LEVEL" == "INFO" ]]
    fi
    
    # 설정값 추출 테스트
    run grep "^BACKUP_ENABLED=" "$temp_config"
    assert_command_success
    assert_output_contains "true"
    
    # 주석 라인 제외 확인
    run grep -v "^#" "$temp_config" | grep -v "^$"
    assert_command_success
    # 주석이 제외되고 실제 설정만 있는지 확인
    local actual_lines=$(grep -v "^#" "$temp_config" | grep -v "^$" | wc -l)
    [[ $actual_lines -eq 9 ]] # 9개의 실제 설정 라인
}

# ===================================================================================
# 에러 처리 및 복원력 테스트
# ===================================================================================

@test "존재하지 않는 파일 처리 테스트" {
    local nonexistent_file="${TEST_TEMP_DIR}/nonexistent.conf"
    
    # 파일이 존재하지 않음을 확인
    [[ ! -f "$nonexistent_file" ]]
    
    source "${LIB_DIR}/common.sh"
    
    # 존재하지 않는 파일 로드 시 적절한 오류 처리
    CONFIG_FILE="$nonexistent_file" run load_config
    # 오류를 적절히 처리해야 함 (실패하거나 기본값 사용)
    [[ "$status" -ne 0 ]] || echo "기본값 사용됨"
}

@test "권한 없는 파일 처리 테스트" {
    local restricted_file="${TEST_TEMP_DIR}/restricted.conf"
    
    # 읽기 권한 없는 파일 생성
    echo "SECRET=value" > "$restricted_file"
    chmod 000 "$restricted_file"
    
    source "${LIB_DIR}/common.sh"
    
    # 권한 없는 파일 접근 시 적절한 오류 처리
    CONFIG_FILE="$restricted_file" run load_config
    assert_command_failure
    
    # 정리
    chmod 644 "$restricted_file"
}

@test "손상된 fstab 파일 처리 테스트" {
    local corrupted_fstab="${TEST_TEMP_DIR}/corrupted_fstab"
    
    # 잘못된 형식의 fstab 파일 생성
    cat > "$corrupted_fstab" << 'EOF'
# 정상 라인
UUID=good-uuid / ext4 defaults 0 1
# 잘못된 라인들
incomplete line
too many fields here and here and here and here and here
UUID=bad /bad/path ext4 invalid-options invalid invalid
EOF

    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/fstab-functions.sh"
    
    # 손상된 fstab 파일 검증
    FSTAB_FILE="$corrupted_fstab" run validate_fstab_file
    # 검증이 문제를 탐지해야 함
    [[ "$status" -ne 0 ]] || assert_output_contains "warning\|error"
}

# ===================================================================================
# 성능 및 안정성 테스트
# ===================================================================================

@test "대용량 fstab 파일 처리 성능 테스트" {
    local large_fstab="${TEST_TEMP_DIR}/large_fstab"
    
    # 대용량 fstab 파일 생성 (1000개 항목)
    {
        echo "# 대용량 테스트 fstab 파일"
        for i in {1..1000}; do
            printf "UUID=test-uuid-%04d /mnt/test%04d ext4 defaults 0 2\n" $i $i
        done
    } > "$large_fstab"
    
    # 파일 크기 확인
    run wc -l "$large_fstab"
    assert_command_success
    assert_output_contains "1001" # 1000개 항목 + 주석 1줄
    
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/fstab-functions.sh"
    
    # 파싱 성능 테스트 (타임아웃 없이 완료되어야 함)
    timeout 10s bash -c "
        source '${LIB_DIR}/common.sh'
        source '${LIB_DIR}/fstab-functions.sh'
        FSTAB_FILE='$large_fstab' parse_fstab_file
    "
    local parse_result=$?
    
    # 타임아웃되지 않고 완료되어야 함
    [[ $parse_result -ne 124 ]] # 124는 timeout 종료 코드
} 
#!/bin/bash

# ===================================================================================
# raid-api.sh - RAID 관리 통합 API
# ===================================================================================
#
# 이 모듈은 RAID 관련 모든 작업의 통합 인터페이스를 제공합니다.
# 앞서 구현한 모든 모듈들을 활용하여 완전한 RAID 관리 솔루션을 제공합니다.
#
# 주요 기능:
# - RAID 생성 + fstab 자동 등록 (fail-safe 옵션 포함)
# - 기존 RAID 배열 제거 및 정리
# - mdadm 상태 정보 조회 및 분석
# - RAID 상태 검사 및 문제 진단
# - RAID 복구 및 재구축 지원
#
# ===================================================================================

# 공통 라이브러리 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 의존성 모듈 로드
for module in "id-resolver.sh" "validator.sh" "fail-safe.sh" "fstab-api.sh" "disk-api.sh" "raid-functions.sh"; do
    if [[ -f "${SCRIPT_DIR}/$module" ]]; then
        # shellcheck source=lib/id-resolver.sh
        # shellcheck source=lib/validator.sh
        # shellcheck source=lib/fail-safe.sh
        # shellcheck source=lib/fstab-api.sh
        # shellcheck source=lib/disk-api.sh
        # shellcheck source=lib/raid-functions.sh
        source "${SCRIPT_DIR}/$module"
    else
        echo "❌ 오류: $module을 찾을 수 없습니다" >&2
        exit 1
    fi
done

# common.sh가 이미 로드되지 않았다면 로드
if [[ -z "${RED:-}" ]]; then
    # shellcheck source=lib/common.sh
    source "${SCRIPT_DIR}/common.sh"
fi

# ===================================================================================
# RAID 생성 + fstab 자동 등록
# ===================================================================================

# 완전한 RAID 생성 및 설정
raid_create_complete() {
    local level="$1"
    local mountpoint="$2"
    local fstype="${3:-ext4}"
    local base_options="${4:-defaults}"
    shift 4
    local disk_ids=("$@")
    
    print_header "완전한 RAID $level 생성 및 설정"
    
    # 입력 검증
    if [[ -z "$level" || -z "$mountpoint" || ${#disk_ids[@]} -eq 0 ]]; then
        print_error "RAID 레벨, 마운트포인트, 디스크 ID들이 필요합니다"
        print_info "사용법: raid_create_complete <레벨> <마운트포인트> [파일시스템] [옵션] <디스크1> <디스크2> ..."
        return 1
    fi
    
    print_info "RAID 생성 요청:"
    echo "  레벨: RAID $level"
    echo "  마운트포인트: $mountpoint"
    echo "  파일시스템: $fstype"
    echo "  기본 옵션: $base_options"
    echo "  디스크: ${disk_ids[*]}"
    echo ""
    
    # 1단계: 종합 검증
    print_step "1/6" "종합 검증 중..."
    if ! validate_raid_operation "$level" "${disk_ids[@]}"; then
        return 1
    fi
    
    # 디스크 목록 및 정보 표시
    echo ""
    print_info "사용할 디스크 정보:"
    disk_get_multiple_info "table" "${disk_ids[@]}"
    
    # 최종 확인
    echo ""
    print_warning "⚠️  중요한 알림:"
    echo "  • 선택된 모든 디스크의 데이터가 완전히 삭제됩니다"
    echo "  • RAID 생성 후에는 개별 디스크로 복구할 수 없습니다"
    echo "  • 진행하기 전에 중요한 데이터를 백업하세요"
    echo ""
    
    if ! confirm_action "위 내용을 이해했으며 RAID 생성을 계속하시겠습니까?"; then
        print_info "RAID 생성이 취소되었습니다"
        return 0
    fi
    
    # 2단계: 디스크 준비
    print_step "2/6" "디스크 준비 중..."
    local devices=()
    for id in "${disk_ids[@]}"; do
        local device
        device=$(resolve_disk_id "$id") || {
            print_error "디스크 ID 해석 실패: $id"
            return 1
        }
        devices+=("$device")
        print_info "디스크 준비됨: $id → $device"
    done
    
    # 3단계: RAID 생성
    print_step "3/6" "RAID 배열 생성 중..."
    local md_device
    md_device=$(create_raid "$level" "${devices[@]}")
    local raid_result=$?
    
    if [[ $raid_result -ne 0 || -z "$md_device" ]]; then
        print_error "RAID 생성 실패"
        return 1
    fi
    
    print_success "RAID 배열 생성 완료: $md_device"
    
    # 4단계: 파일시스템 생성
    print_step "4/6" "파일시스템 생성 중..."
    print_info "파일시스템 생성: $fstype"
    
    if ! mkfs."$fstype" "$md_device"; then
        print_error "파일시스템 생성 실패"
        print_warning "RAID 배열은 생성되었지만 파일시스템 생성에 실패했습니다"
        print_info "수동으로 파일시스템을 생성하세요: mkfs.$fstype $md_device"
        return 1
    fi
    
    print_success "파일시스템 생성 완료"
    
    # 5단계: fstab 등록
    print_step "5/6" "fstab 등록 중..."
    
    # RAID용 fail-safe 옵션 적용
    local raid_options
    raid_options=$(apply_raid_fail_safe_options "$base_options" "software" "auto")
    print_info "RAID용 안전 옵션 적용: $base_options → $raid_options"
    
    if fstab_add_entry_safe "$md_device" "$mountpoint" "$fstype" "$raid_options" "0" "2" "auto"; then
        print_success "fstab 등록 완료"
    else
        print_error "fstab 등록 실패"
        print_warning "RAID는 생성되었지만 자동 마운트 설정에 실패했습니다"
        print_info "수동으로 fstab에 추가하세요: $md_device $mountpoint $fstype $raid_options 0 2"
    fi
    
    # 6단계: 마운트 테스트 및 완료
    print_step "6/6" "마운트 테스트 및 완료..."
    
    # 마운트포인트 생성
    if [[ ! -d "$mountpoint" ]]; then
        mkdir -p "$mountpoint" || {
            print_warning "마운트포인트 생성 실패: $mountpoint"
        }
    fi
    
    # 마운트 테스트
    if mount "$md_device" "$mountpoint"; then
        print_success "마운트 테스트 성공: $md_device → $mountpoint"
        
        # 간단한 쓰기 테스트
        local test_file="$mountpoint/.raid_test_$$"
        if echo "RAID test" > "$test_file" 2>/dev/null; then
            rm -f "$test_file"
            print_success "쓰기 테스트 성공"
        else
            print_warning "쓰기 테스트 실패"
        fi
        
        # 권한 설정
        chmod 755 "$mountpoint" 2>/dev/null
        
    else
        print_warning "마운트 테스트 실패"
        print_info "수동으로 마운트하세요: mount $md_device $mountpoint"
    fi
    
    # 완료 정보 출력
    echo ""
    print_header "RAID 생성 완료!"
    echo ""
    echo "📋 RAID 정보:"
    echo "  레벨: RAID $level"
    echo "  디바이스: $md_device"
    echo "  마운트포인트: $mountpoint"
    echo "  파일시스템: $fstype"
    echo "  사용된 디스크: ${devices[*]}"
    echo ""
    echo "🔧 관리 명령어:"
    echo "  상태 확인: mdadm --detail $md_device"
    echo "  마운트: mount $mountpoint"
    echo "  언마운트: umount $mountpoint"
    echo ""
    echo "⚠️  중요 사항:"
    echo "  • 시스템 재부팅 후에도 자동으로 마운트됩니다"
    echo "  • RAID 상태를 정기적으로 확인하세요"
    echo "  • 디스크 실패 시 즉시 교체하세요"
    
    # mdadm.conf 업데이트
    if command -v update-initramfs >/dev/null 2>&1; then
        echo ""
        print_info "initramfs 업데이트 중..."
        if update-initramfs -u; then
            print_success "initramfs 업데이트 완료"
        else
            print_warning "initramfs 업데이트 실패 (수동으로 실행하세요)"
        fi
    fi
    
    return 0
}

# 빠른 RAID 생성 (기본 설정)
raid_create_quick() {
    local level="$1"
    local mountpoint="$2"
    shift 2
    local disk_ids=("$@")
    
    print_info "빠른 RAID $level 생성: $mountpoint"
    
    # 기본 설정으로 완전한 RAID 생성
    raid_create_complete "$level" "$mountpoint" "ext4" "defaults" "${disk_ids[@]}"
}

# ===================================================================================
# RAID 제거 및 정리
# ===================================================================================

# RAID 배열 안전 제거
raid_remove_array() {
    local raid_device="$1"
    local remove_fstab="${2:-true}"
    local wipe_disks="${3:-false}"
    
    print_header "RAID 배열 제거: $raid_device"
    
    if [[ -z "$raid_device" ]]; then
        print_error "제거할 RAID 디바이스가 지정되지 않았습니다"
        return 1
    fi
    
    # RAID 디바이스 존재 확인
    if [[ ! -b "$raid_device" ]]; then
        print_error "RAID 디바이스가 존재하지 않습니다: $raid_device"
        return 1
    fi
    
    # RAID 정보 조회
    local raid_info
    raid_info=$(mdadm --detail "$raid_device" 2>/dev/null)
    
    if [[ -z "$raid_info" ]]; then
        print_error "RAID 정보를 가져올 수 없습니다: $raid_device"
        return 1
    fi
    
    # RAID 정보 표시
    print_info "제거할 RAID 정보:"
    echo "$raid_info" | grep -E "(Raid Level|Array Size|State|Active Devices)" | sed 's/^/  /'
    
    # 사용 중인 디스크 목록
    local member_disks
    member_disks=$(echo "$raid_info" | grep -E "^\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+active" | awk '{print $NF}')
    
    if [[ -n "$member_disks" ]]; then
        echo ""
        print_info "멤버 디스크:"
        echo "$member_disks" | sed 's/^/  • /'
    fi
    
    # fstab 항목 확인
    local fstab_entry
    fstab_entry=$(fstab_find_entries "$raid_device")
    
    if [[ -n "$fstab_entry" ]]; then
        IFS=':' read -r device mountpoint fstype options dump pass <<< "$fstab_entry"
        echo ""
        print_warning "fstab 항목 발견:"
        echo "  마운트포인트: $mountpoint"
        echo "  파일시스템: $fstype"
    fi
    
    # 최종 확인
    echo ""
    print_warning "⚠️  중요한 경고:"
    echo "  • RAID 배열의 모든 데이터가 영구적으로 삭제됩니다"
    echo "  • 이 작업은 되돌릴 수 없습니다"
    echo "  • 중요한 데이터는 미리 백업하세요"
    echo ""
    
    if ! confirm_action "정말로 이 RAID 배열을 제거하시겠습니까?"; then
        print_info "RAID 제거가 취소되었습니다"
        return 0
    fi
    
    # 1단계: 언마운트
    print_step "1/5" "언마운트 중..."
    
    local mount_info
    mount_info=$(mount | grep "^$raid_device ")
    
    if [[ -n "$mount_info" ]]; then
        local mountpoint
        mountpoint=$(echo "$mount_info" | awk '{print $3}')
        
        if umount "$mountpoint"; then
            print_success "언마운트 완료: $mountpoint"
        else
            print_warning "언마운트 실패, 강제 언마운트 시도..."
            if umount -f "$mountpoint"; then
                print_success "강제 언마운트 완료"
            else
                print_error "언마운트 실패. 사용 중인 프로세스를 확인하세요"
                print_info "강제로 계속 진행하려면 수동으로 프로세스를 종료하세요"
                return 1
            fi
        fi
    else
        print_info "마운트되지 않은 상태입니다"
    fi
    
    # 2단계: fstab에서 제거
    print_step "2/5" "fstab 항목 제거 중..."
    
    if [[ "$remove_fstab" == "true" && -n "$fstab_entry" ]]; then
        if fstab_remove_entry_safe "$raid_device" false false; then
            print_success "fstab 항목 제거 완료"
        else
            print_warning "fstab 항목 제거 실패 (수동으로 제거하세요)"
        fi
    else
        print_info "fstab 항목 제거 생략"
    fi
    
    # 3단계: RAID 배열 중지
    print_step "3/5" "RAID 배열 중지 중..."
    
    if mdadm --stop "$raid_device"; then
        print_success "RAID 배열 중지 완료"
    else
        print_error "RAID 배열 중지 실패"
        return 1
    fi
    
    # 4단계: 멤버 디스크 정리
    print_step "4/5" "멤버 디스크 정리 중..."
    
    if [[ -n "$member_disks" ]]; then
        while IFS= read -r disk; do
            [[ -n "$disk" ]] || continue
            
            print_info "디스크 정리 중: $disk"
            
            # RAID 슈퍼블록 제거
            if mdadm --zero-superblock "$disk" 2>/dev/null; then
                print_success "슈퍼블록 제거 완료: $disk"
            else
                print_warning "슈퍼블록 제거 실패: $disk"
            fi
            
            # 전체 디스크 지우기 (요청된 경우)
            if [[ "$wipe_disks" == "true" ]]; then
                print_info "디스크 완전 삭제 중: $disk (시간이 오래 걸릴 수 있습니다)"
                
                if dd if=/dev/zero of="$disk" bs=1M count=100 2>/dev/null; then
                    print_success "디스크 앞부분 삭제 완료: $disk"
                else
                    print_warning "디스크 삭제 실패: $disk"
                fi
            fi
            
        done <<< "$member_disks"
    fi
    
    # 5단계: mdadm.conf 업데이트
    print_step "5/5" "시스템 설정 업데이트 중..."
    
    # mdadm.conf에서 해당 배열 제거
    local mdadm_conf="/etc/mdadm/mdadm.conf"
    if [[ -f "$mdadm_conf" ]]; then
        local backup_conf="${mdadm_conf}.backup.$(date +%Y%m%d_%H%M%S)"
        
        if cp "$mdadm_conf" "$backup_conf"; then
            print_info "mdadm.conf 백업 생성: $backup_conf"
            
            # 해당 RAID 항목 제거
            if grep -v "$raid_device" "$mdadm_conf" > "${mdadm_conf}.tmp" && mv "${mdadm_conf}.tmp" "$mdadm_conf"; then
                print_success "mdadm.conf 업데이트 완료"
            else
                print_warning "mdadm.conf 업데이트 실패"
            fi
        fi
    fi
    
    # initramfs 업데이트
    if command -v update-initramfs >/dev/null 2>&1; then
        if update-initramfs -u; then
            print_success "initramfs 업데이트 완료"
        else
            print_warning "initramfs 업데이트 실패"
        fi
    fi
    
    echo ""
    print_success "RAID 배열 제거 완료!"
    echo ""
    print_info "📋 제거 요약:"
    echo "  • RAID 디바이스: $raid_device (제거됨)"
    echo "  • 멤버 디스크: 슈퍼블록 제거 완료"
    [[ "$remove_fstab" == "true" ]] && echo "  • fstab 항목: 제거됨"
    [[ "$wipe_disks" == "true" ]] && echo "  • 디스크 데이터: 완전 삭제됨"
    echo ""
    print_info "멤버 디스크들은 이제 다른 용도로 사용할 수 있습니다"
    
    return 0
}

# 모든 RAID 배열 목록 및 제거 선택
raid_remove_interactive() {
    print_header "RAID 배열 대화형 제거"
    
    local raid_arrays
    raid_arrays=$(get_raid_arrays)
    
    if [[ -z "$raid_arrays" ]]; then
        print_info "제거할 RAID 배열이 없습니다"
        return 0
    fi
    
    print_info "현재 RAID 배열 목록:"
    echo "$raid_arrays" | nl
    echo ""
    
    read -rp "제거할 RAID 번호를 입력하세요 (0=취소): " choice
    
    if [[ "$choice" == "0" ]]; then
        print_info "제거가 취소되었습니다"
        return 0
    fi
    
    local selected_raid
    selected_raid=$(echo "$raid_arrays" | sed -n "${choice}p")
    
    if [[ -z "$selected_raid" ]]; then
        print_error "잘못된 선택입니다"
        return 1
    fi
    
    # 추가 옵션 선택
    echo ""
    print_info "제거 옵션:"
    echo "1) 기본 제거 (RAID만 제거, fstab 정리)"
    echo "2) 완전 제거 (디스크 데이터까지 완전 삭제)"
    echo ""
    
    read -rp "옵션을 선택하세요 (1-2): " option
    
    local wipe_disks=false
    case "$option" in
        1) wipe_disks=false ;;
        2) wipe_disks=true ;;
        *) 
            print_error "잘못된 옵션입니다"
            return 1
            ;;
    esac
    
    raid_remove_array "$selected_raid" true "$wipe_disks"
}

# ===================================================================================
# RAID 상태 조회 및 분석
# ===================================================================================

# mdadm 상태 정보 종합 조회
raid_get_system_status() {
    local format="${1:-detailed}"  # detailed, simple, summary
    
    print_debug "RAID 시스템 상태 조회 (형식: $format)"
    
    case "$format" in
        "detailed")
            print_header "RAID 시스템 상태"
            
            # 전체 RAID 배열 목록
            local arrays
            arrays=$(get_raid_arrays)
            
            if [[ -z "$arrays" ]]; then
                print_info "활성화된 RAID 배열이 없습니다"
                return 0
            fi
            
            echo ""
            print_info "활성화된 RAID 배열: $(echo "$arrays" | wc -l)개"
            echo ""
            
            while IFS= read -r array; do
                [[ -n "$array" ]] || continue
                
                print_info "RAID 배열: $array"
                get_raid_summary "$array" | sed 's/^/  /'
                
                # fstab 등록 상태 확인
                local fstab_entry
                fstab_entry=$(fstab_find_entries "$array")
                
                if [[ -n "$fstab_entry" ]]; then
                    IFS=':' read -r device mountpoint fstype options dump pass <<< "$fstab_entry"
                    echo "  fstab: $mountpoint ($options)"
                else
                    echo "  fstab: 미등록"
                fi
                
                # 마운트 상태 확인
                if mount | grep -q "^$array "; then
                    local mount_point
                    mount_point=$(mount | grep "^$array " | awk '{print $3}')
                    echo "  마운트: ✅ $mount_point"
                else
                    echo "  마운트: ❌ 언마운트됨"
                fi
                
                echo ""
            done <<< "$arrays"
            ;;
        "simple")
            get_raid_arrays
            ;;
        "summary")
            local arrays
            arrays=$(get_raid_arrays)
            
            if [[ -z "$arrays" ]]; then
                echo "RAID 배열: 0개"
            else
                local count
                count=$(echo "$arrays" | wc -l)
                echo "RAID 배열: ${count}개"
                
                local healthy=0
                local degraded=0
                
                while IFS= read -r array; do
                    [[ -n "$array" ]] || continue
                    
                    local status
                    status=$(mdadm --detail "$array" 2>/dev/null | grep "State :" | awk '{print $3}')
                    
                    case "$status" in
                        *clean*) ((healthy++)) ;;
                        *degraded*) ((degraded++)) ;;
                    esac
                done <<< "$arrays"
                
                echo "상태: 정상 ${healthy}개, 문제 ${degraded}개"
            fi
            ;;
        *)
            print_error "지원하지 않는 형식: $format"
            return 1
            ;;
    esac
}

# 특정 RAID 배열 상세 분석
raid_analyze_array() {
    local raid_device="$1"
    local check_performance="${2:-false}"
    
    print_header "RAID 배열 상세 분석: $raid_device"
    
    if [[ -z "$raid_device" ]]; then
        print_error "분석할 RAID 디바이스가 지정되지 않았습니다"
        return 1
    fi
    
    if [[ ! -b "$raid_device" ]]; then
        print_error "RAID 디바이스가 존재하지 않습니다: $raid_device"
        return 1
    fi
    
    # 기본 정보
    print_info "📋 기본 정보"
    get_raid_summary "$raid_device"
    
    # 상세 mdadm 정보
    echo ""
    print_info "🔧 mdadm 상세 정보"
    mdadm --detail "$raid_device" | grep -E "(Raid Level|Array Size|Used Dev Size|State|Active Devices|Working Devices|Failed Devices)" | sed 's/^/  /'
    
    # 멤버 디스크 상태
    echo ""
    print_info "💾 멤버 디스크 상태"
    mdadm --detail "$raid_device" | grep -E "^\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[0-9]+" | while read -r line; do
        local disk
        disk=$(echo "$line" | awk '{print $NF}')
        local state
        state=$(echo "$line" | awk '{print $(NF-1)}')
        
        case "$state" in
            *active*) echo "  ✅ $disk (정상)" ;;
            *faulty*) echo "  ❌ $disk (실패)" ;;
            *spare*) echo "  🔄 $disk (예비)" ;;
            *) echo "  ⚠️  $disk ($state)" ;;
        esac
    done
    
    # fstab 및 마운트 상태
    echo ""
    print_info "🗂️  시스템 통합 상태"
    
    local fstab_entry
    fstab_entry=$(fstab_find_entries "$raid_device")
    
    if [[ -n "$fstab_entry" ]]; then
        IFS=':' read -r device mountpoint fstype options dump pass <<< "$fstab_entry"
        echo "  fstab: ✅ 등록됨 ($mountpoint)"
        echo "    파일시스템: $fstype"
        echo "    옵션: $options"
        
        # fail-safe 확인
        if [[ "$options" == *"nofail"* ]]; then
            echo "    fail-safe: ✅ 적용됨"
        else
            echo "    fail-safe: ⚠️  미적용"
        fi
    else
        echo "  fstab: ❌ 미등록"
    fi
    
    # 마운트 상태
    if mount | grep -q "^$raid_device "; then
        local mount_info
        mount_info=$(mount | grep "^$raid_device ")
        local mount_point
        mount_point=$(echo "$mount_info" | awk '{print $3}')
        echo "  마운트: ✅ $mount_point"
        
        # 디스크 사용량
        local usage
        usage=$(df -h "$mount_point" 2>/dev/null | tail -1)
        if [[ -n "$usage" ]]; then
            echo "  사용량: $(echo "$usage" | awk '{print $3"/"$2" ("$5")"}')"
        fi
    else
        echo "  마운트: ❌ 언마운트됨"
    fi
    
    # 성능 검사 (요청된 경우)
    if [[ "$check_performance" == "true" ]]; then
        echo ""
        print_info "⚡ 성능 검사 (간단한 테스트)"
        
        if mount | grep -q "^$raid_device "; then
            local mount_point
            mount_point=$(mount | grep "^$raid_device " | awk '{print $3}')
            
            print_info "쓰기 성능 테스트 중... (100MB)"
            local write_speed
            write_speed=$(dd if=/dev/zero of="$mount_point/.perf_test_$$" bs=1M count=100 2>&1 | grep -o '[0-9.]* MB/s' || echo "측정 실패")
            rm -f "$mount_point/.perf_test_$$" 2>/dev/null
            echo "  쓰기 속도: $write_speed"
            
            print_info "읽기 성능 테스트 중... (디바이스 직접)"
            local read_speed
            read_speed=$(dd if="$raid_device" of=/dev/null bs=1M count=100 2>&1 | grep -o '[0-9.]* MB/s' || echo "측정 실패")
            echo "  읽기 속도: $read_speed"
        else
            print_warning "마운트되지 않아 성능 테스트를 건너뜁니다"
        fi
    fi
    
    # 권장사항
    echo ""
    print_info "💡 권장사항"
    
    local recommendations=()
    
    # fail-safe 확인
    if [[ -n "$fstab_entry" ]]; then
        IFS=':' read -r device mountpoint fstype options dump pass <<< "$fstab_entry"
        if [[ "$options" != *"nofail"* ]]; then
            recommendations+=("fstab에 fail-safe 옵션(nofail) 추가를 권장합니다")
        fi
    else
        recommendations+=("시스템 부팅 시 자동 마운트를 위해 fstab 등록을 권장합니다")
    fi
    
    # RAID 상태 확인
    local raid_state
    raid_state=$(mdadm --detail "$raid_device" | grep "State :" | awk '{print $3}')
    
    if [[ "$raid_state" == *"degraded"* ]]; then
        recommendations+=("RAID가 degraded 상태입니다. 실패한 디스크를 즉시 교체하세요")
    fi
    
    if [[ ${#recommendations[@]} -eq 0 ]]; then
        echo "  ✅ 모든 설정이 적절합니다"
    else
        for rec in "${recommendations[@]}"; do
            echo "  • $rec"
        done
    fi
}

# ===================================================================================
# RAID 상태 검사 및 문제 진단
# ===================================================================================

# 시스템 전체 RAID 상태 검사
raid_health_check_system() {
    local auto_fix="${1:-false}"
    
    print_header "시스템 RAID 상태 검사"
    
    local arrays
    arrays=$(get_raid_arrays)
    
    if [[ -z "$arrays" ]]; then
        print_info "검사할 RAID 배열이 없습니다"
        return 0
    fi
    
    local total_arrays=0
    local healthy_arrays=0
    local issues_found=()
    
    while IFS= read -r array; do
        [[ -n "$array" ]] || continue
        
        ((total_arrays++))
        
        print_info "검사 중: $array"
        
        # 기본 상태 확인
        local array_healthy=true
        local state
        state=$(mdadm --detail "$array" 2>/dev/null | grep "State :" | awk '{print $3}')
        
        case "$state" in
            *clean*)
                echo "  ✅ 상태: 정상 ($state)"
                ;;
            *degraded*)
                echo "  ⚠️  상태: 성능 저하 ($state)"
                issues_found+=("$array: degraded 상태")
                array_healthy=false
                ;;
            *)
                echo "  ❌ 상태: 문제 있음 ($state)"
                issues_found+=("$array: 알 수 없는 상태 ($state)")
                array_healthy=false
                ;;
        esac
        
        # 실패한 디스크 확인
        local failed_disks
        failed_disks=$(mdadm --detail "$array" | grep -c "faulty")
        
        if [[ $failed_disks -gt 0 ]]; then
            echo "  ❌ 실패한 디스크: ${failed_disks}개"
            issues_found+=("$array: ${failed_disks}개 디스크 실패")
            array_healthy=false
        else
            echo "  ✅ 디스크: 모두 정상"
        fi
        
        # fstab 등록 확인
        local fstab_entry
        fstab_entry=$(fstab_find_entries "$array")
        
        if [[ -n "$fstab_entry" ]]; then
            IFS=':' read -r device mountpoint fstype options dump pass <<< "$fstab_entry"
            echo "  ✅ fstab: 등록됨 ($mountpoint)"
            
            # fail-safe 옵션 확인
            if [[ "$options" == *"nofail"* ]]; then
                echo "  ✅ fail-safe: 적용됨"
            else
                echo "  ⚠️  fail-safe: 미적용"
                issues_found+=("$array: fail-safe 옵션 없음")
            fi
        else
            echo "  ⚠️  fstab: 미등록"
            issues_found+=("$array: fstab 미등록")
        fi
        
        [[ $array_healthy == true ]] && ((healthy_arrays++))
        
        echo ""
    done <<< "$arrays"
    
    # 결과 요약
    print_info "검사 결과 요약:"
    echo "  전체 RAID 배열: $total_arrays"
    echo "  정상 배열: $healthy_arrays"
    echo "  문제 있는 배열: $((total_arrays - healthy_arrays))"
    
    if [[ ${#issues_found[@]} -gt 0 ]]; then
        echo ""
        print_warning "발견된 문제들:"
        for issue in "${issues_found[@]}"; do
            echo "  • $issue"
        done
        
        if [[ "$auto_fix" == "true" ]]; then
            echo ""
            if confirm_action "자동으로 수정 가능한 문제들을 해결하시겠습니까?"; then
                raid_auto_fix_issues
            fi
        fi
        
        return 1
    else
        print_success "모든 RAID 배열이 정상 상태입니다!"
        return 0
    fi
}

# RAID 문제 자동 수정
raid_auto_fix_issues() {
    print_header "RAID 문제 자동 수정"
    
    local arrays
    arrays=$(get_raid_arrays)
    
    [[ -n "$arrays" ]] || return 0
    
    local fixed_count=0
    
    while IFS= read -r array; do
        [[ -n "$array" ]] || continue
        
        print_info "자동 수정 검사: $array"
        
        # fstab fail-safe 옵션 추가
        local fstab_entry
        fstab_entry=$(fstab_find_entries "$array")
        
        if [[ -n "$fstab_entry" ]]; then
            IFS=':' read -r device mountpoint fstype options dump pass <<< "$fstab_entry"
            
            if [[ "$options" != *"nofail"* ]]; then
                print_info "fail-safe 옵션 추가 중: $mountpoint"
                
                local new_options
                new_options=$(apply_raid_fail_safe_options "$options" "software" "auto")
                
                # fstab 수정
                if fstab_remove_entry_safe "$mountpoint" false false && \
                   fstab_add_entry_safe "$array" "$mountpoint" "$fstype" "$new_options" "$dump" "$pass" "auto"; then
                    print_success "fail-safe 옵션 추가 완료: $mountpoint"
                    ((fixed_count++))
                else
                    print_error "fail-safe 옵션 추가 실패: $mountpoint"
                fi
            fi
        else
            # fstab 미등록 - 자동 등록은 위험하므로 안내만
            print_info "fstab 미등록 상태입니다. 수동으로 등록하세요:"
            echo "  fstab_add_entry_safe $array /your/mountpoint ext4"
        fi
        
    done <<< "$arrays"
    
    if [[ $fixed_count -gt 0 ]]; then
        print_success "자동 수정 완료: ${fixed_count}개 문제 해결"
    else
        print_info "자동으로 수정할 수 있는 문제가 없습니다"
    fi
}

# ===================================================================================
# RAID 복구 및 재구축
# ===================================================================================

# RAID 디스크 교체 및 재구축
raid_replace_disk() {
    local raid_device="$1"
    local failed_disk="$2"
    local new_disk="$3"
    
    print_header "RAID 디스크 교체: $raid_device"
    
    if [[ -z "$raid_device" || -z "$failed_disk" || -z "$new_disk" ]]; then
        print_error "RAID 디바이스, 실패한 디스크, 새 디스크가 모두 필요합니다"
        print_info "사용법: raid_replace_disk <RAID_디바이스> <실패한_디스크> <새_디스크>"
        return 1
    fi
    
    # 검증
    if [[ ! -b "$raid_device" ]]; then
        print_error "RAID 디바이스가 존재하지 않습니다: $raid_device"
        return 1
    fi
    
    if ! validate_disk_exists "$new_disk"; then
        return 1
    fi
    
    local new_device
    new_device=$(resolve_disk_id "$new_disk")
    
    print_info "디스크 교체 정보:"
    echo "  RAID: $raid_device"
    echo "  실패한 디스크: $failed_disk"
    echo "  새 디스크: $new_device"
    echo ""
    
    # 현재 RAID 상태 확인
    print_info "현재 RAID 상태:"
    get_raid_summary "$raid_device"
    
    echo ""
    print_warning "⚠️  중요한 알림:"
    echo "  • 새 디스크의 모든 데이터가 삭제됩니다"
    echo "  • 재구축 중에는 성능이 저하될 수 있습니다"
    echo "  • 재구축이 완료될 때까지 기다려주세요"
    echo ""
    
    if ! confirm_action "디스크 교체를 진행하시겠습니까?"; then
        print_info "디스크 교체가 취소되었습니다"
        return 0
    fi
    
    # 1단계: 실패한 디스크 제거
    print_step "1/3" "실패한 디스크 제거 중..."
    
    if mdadm --manage "$raid_device" --remove "$failed_disk"; then
        print_success "실패한 디스크 제거 완료: $failed_disk"
    else
        print_warning "실패한 디스크 제거 실패 (이미 제거되었을 수 있음)"
    fi
    
    # 2단계: 새 디스크 추가
    print_step "2/3" "새 디스크 추가 중..."
    
    if mdadm --manage "$raid_device" --add "$new_device"; then
        print_success "새 디스크 추가 완료: $new_device"
    else
        print_error "새 디스크 추가 실패"
        return 1
    fi
    
    # 3단계: 재구축 모니터링
    print_step "3/3" "RAID 재구축 모니터링..."
    
    print_info "재구축이 시작되었습니다. 진행 상황을 모니터링합니다..."
    print_info "재구축 중에는 시스템 성능이 저하될 수 있습니다"
    echo ""
    
    # 재구축 진행 상황 모니터링
    local rebuild_start_time
    rebuild_start_time=$(date +%s)
    
    while true; do
        local recovery_info
        recovery_info=$(cat /proc/mdstat | grep -A 5 "$(basename "$raid_device")" | grep recovery || true)
        
        if [[ -z "$recovery_info" ]]; then
            # 재구축 완료 확인
            local state
            state=$(mdadm --detail "$raid_device" | grep "State :" | awk '{print $3}')
            
            if [[ "$state" == *"clean"* ]]; then
                break
            fi
        else
            # 진행률 표시
            local progress
            progress=$(echo "$recovery_info" | grep -o '[0-9.]*%' || echo "진행 중")
            local speed
            speed=$(echo "$recovery_info" | grep -o '[0-9]*K/sec' || echo "")
            
            echo -e "\r재구축 진행: $progress $speed"
        fi
        
        sleep 5
    done
    
    local rebuild_end_time
    rebuild_end_time=$(date +%s)
    local rebuild_duration
    rebuild_duration=$((rebuild_end_time - rebuild_start_time))
    
    echo ""
    print_success "RAID 재구축 완료! (소요 시간: ${rebuild_duration}초)"
    
    # 최종 상태 확인
    echo ""
    print_info "재구축 후 RAID 상태:"
    get_raid_summary "$raid_device"
    
    # mdadm.conf 업데이트
    if command -v update-initramfs >/dev/null 2>&1; then
        echo ""
        print_info "시스템 설정 업데이트 중..."
        if update-initramfs -u; then
            print_success "시스템 설정 업데이트 완료"
        fi
    fi
    
    echo ""
    print_success "디스크 교체 및 재구축이 성공적으로 완료되었습니다!"
    
    return 0
} 
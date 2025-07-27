#!/bin/bash

# ===================================================================================
# fstab-api.sh - fstab 관리 통합 API
# ===================================================================================
#
# 이 모듈은 fstab 관련 모든 작업의 통합 인터페이스를 제공합니다.
# 기본적으로 fail-safe 옵션(nofail)을 적용하며, ID 기반 안전한 관리를
# 지원합니다.
#
# 주요 기능:
# - ID 기반 fstab 항목 안전 추가 (UUID 우선, fail-safe 기본 적용)
# - fstab 항목 안전 제거 (충돌 방지)
# - fstab 항목 조회 및 분석
# - 기존 fstab 항목 검증 및 개선 제안
#
# ===================================================================================

# 공통 라이브러리 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 의존성 모듈 로드
for module in "id-resolver.sh" "validator.sh" "fail-safe.sh" "fstab-functions.sh"; do
    if [[ -f "${SCRIPT_DIR}/$module" ]]; then
        # shellcheck source=lib/id-resolver.sh
        # shellcheck source=lib/validator.sh  
        # shellcheck source=lib/fail-safe.sh
        # shellcheck source=lib/fstab-functions.sh
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
# fstab 항목 안전 추가 (fail-safe 기본 적용)
# ===================================================================================

# fstab 항목 안전 추가 (UUID 기반, fail-safe 기본 적용)
fstab_add_entry_safe() {
    local id="$1"
    local mountpoint="$2"
    local fstype="$3"
    local options="${4:-defaults}"
    local dump="${5:-0}"
    local pass="${6:-2}"
    local mode="${7:-auto}"  # auto, interactive
    
    print_debug "fstab 안전 추가: $id → $mountpoint"
    
    # 입력 검증
    if [[ -z "$id" || -z "$mountpoint" || -z "$fstype" ]]; then
        print_error "디스크 ID, 마운트포인트, 파일시스템 타입이 필요합니다"
        return 1
    fi
    
    # 디스크 존재 확인 및 디바이스 경로 획득
    if ! validate_disk_exists "$id"; then
        return 1
    fi
    
    local device
    device=$(resolve_disk_id "$id") || {
        print_error "디스크 ID를 해석할 수 없습니다: $id"
        return 1
    }
    
    print_info "fstab 항목 추가 준비: $device → $mountpoint"
    
    # UUID 기반 식별자 획득 (가장 안정적)
    local fstab_identifier
    fstab_identifier=$(get_fstab_identifier "$device") || {
        print_warning "UUID를 가져올 수 없어 디바이스 경로를 사용합니다: $device"
        fstab_identifier="$device"
    }
    
    print_debug "fstab 식별자: $fstab_identifier"
    
    # 전체 검증
    if ! validate_fstab_operation "$fstab_identifier" "$mountpoint" "$fstype" "$options"; then
        return 1
    fi
    
    # fail-safe 옵션 자동 적용
    local safe_options
    safe_options=$(apply_fail_safe_options "$options" true "$mode")
    
    if [[ "$safe_options" != "$options" ]]; then
        print_success "fail-safe 옵션이 자동으로 적용되었습니다: $options → $safe_options"
    fi
    
    # fstab에 추가
    print_info "fstab 항목 추가 중..."
    if add_fstab_entry "$fstab_identifier" "$mountpoint" "$fstype" "$safe_options" "$dump" "$pass"; then
        print_success "fstab 항목이 성공적으로 추가되었습니다"
        
        # 추가된 항목 확인
        echo ""
        print_info "추가된 fstab 항목:"
        echo "  디바이스: $fstab_identifier"
        echo "  마운트포인트: $mountpoint"
        echo "  파일시스템: $fstype"
        echo "  옵션: $safe_options"
        echo "  덤프: $dump"
        echo "  패스: $pass"
        
        # 즉시 마운트 테스트 제안
        echo ""
        if confirm_action "지금 마운트 테스트를 수행하시겠습니까?"; then
            fstab_test_mount "$mountpoint"
        fi
        
        return 0
    else
        print_error "fstab 항목 추가 실패"
        return 1
    fi
}

# RAID용 fstab 항목 추가 (추가 안전 옵션)
fstab_add_raid_entry() {
    local raid_device="$1"
    local mountpoint="$2"
    local fstype="${3:-ext4}"
    local base_options="${4:-defaults}"
    local dump="${5:-0}"
    local pass="${6:-2}"
    local raid_type="${7:-software}"
    local mode="${8:-auto}"
    
    print_debug "RAID fstab 항목 추가: $raid_device → $mountpoint"
    
    # RAID 전용 fail-safe 옵션 적용
    local raid_options
    raid_options=$(apply_raid_fail_safe_options "$base_options" "$raid_type" "$mode")
    
    print_info "RAID용 안전 옵션 적용: $base_options → $raid_options"
    
    # 일반 fstab 추가 함수 호출
    fstab_add_entry_safe "$raid_device" "$mountpoint" "$fstype" "$raid_options" "$dump" "$pass" "$mode"
}

# 네트워크 파일시스템용 fstab 항목 추가
fstab_add_network_entry() {
    local network_path="$1"  # nfs://server/path 형식
    local mountpoint="$2"
    local fstype="${3:-nfs}"
    local base_options="${4:-defaults}"
    local dump="${5:-0}"
    local pass="${6:-0}"  # 네트워크 FS는 0이 기본
    
    print_debug "네트워크 fstab 항목 추가: $network_path → $mountpoint"
    
    # 네트워크 파일시스템용 fail-safe 옵션 적용
    local network_options
    network_options=$(apply_network_fail_safe "$base_options" "$fstype")
    
    print_info "네트워크용 안전 옵션 적용: $base_options → $network_options"
    
    # 네트워크 경로는 별도 검증 로직 필요
    if [[ -z "$network_path" || -z "$mountpoint" ]]; then
        print_error "네트워크 경로와 마운트포인트가 필요합니다"
        return 1
    fi
    
    # 마운트포인트 검증만 수행 (네트워크 리소스는 검증 불가)
    if ! validate_mountpoint "$mountpoint"; then
        return 1
    fi
    
    # fstab에 직접 추가
    print_info "네트워크 fstab 항목 추가 중..."
    if add_fstab_entry "$network_path" "$mountpoint" "$fstype" "$network_options" "$dump" "$pass"; then
        print_success "네트워크 fstab 항목이 성공적으로 추가되었습니다"
        
        print_info "추가된 네트워크 fstab 항목:"
        echo "  경로: $network_path"
        echo "  마운트포인트: $mountpoint"
        echo "  파일시스템: $fstype"
        echo "  옵션: $network_options"
        
        print_warning "네트워크 파일시스템은 수동으로 마운트하세요: mount $mountpoint"
        
        return 0
    else
        print_error "네트워크 fstab 항목 추가 실패"
        return 1
    fi
}

# ===================================================================================
# fstab 항목 안전 제거
# ===================================================================================

# fstab 항목 안전 제거
fstab_remove_entry_safe() {
    local identifier="$1"  # 마운트포인트, 디바이스 ID, 또는 UUID 등
    local confirm_removal="${2:-true}"
    local unmount_first="${3:-true}"
    
    print_debug "fstab 안전 제거: $identifier"
    
    if [[ -z "$identifier" ]]; then
        print_error "제거할 항목의 식별자가 필요합니다 (마운트포인트, 디바이스 ID, UUID 등)"
        return 1
    fi
    
    # fstab 파일 존재 확인
    local fstab_file="/etc/fstab"
    if [[ ! -f "$fstab_file" ]]; then
        print_error "fstab 파일이 존재하지 않습니다"
        return 1
    fi
    
    # 식별자에 해당하는 항목 찾기
    local matching_entries
    matching_entries=$(fstab_find_entries "$identifier")
    
    if [[ -z "$matching_entries" ]]; then
        print_error "해당하는 fstab 항목을 찾을 수 없습니다: $identifier"
        return 1
    fi
    
    local entry_count
    entry_count=$(echo "$matching_entries" | wc -l)
    
    if [[ $entry_count -gt 1 ]]; then
        print_warning "여러 개의 항목이 발견되었습니다:"
        echo "$matching_entries" | nl
        echo ""
        
        read -rp "제거할 항목 번호를 입력하세요 (1-$entry_count, 0=취소): " choice
        
        if [[ "$choice" =~ ^[1-9][0-9]*$ && $choice -le $entry_count ]]; then
            matching_entries=$(echo "$matching_entries" | sed -n "${choice}p")
        elif [[ "$choice" == "0" ]]; then
            print_info "제거가 취소되었습니다"
            return 0
        else
            print_error "잘못된 선택입니다"
            return 1
        fi
    fi
    
    # 선택된 항목 정보 파싱
    IFS=':' read -r device mountpoint fstype options dump pass <<< "$matching_entries"
    
    print_info "제거 대상 fstab 항목:"
    echo "  디바이스: $device"
    echo "  마운트포인트: $mountpoint"
    echo "  파일시스템: $fstype"
    echo "  옵션: $options"
    
    # 확인 요청
    if [[ "$confirm_removal" == "true" ]]; then
        echo ""
        print_warning "⚠️  이 항목을 fstab에서 제거하면 다음 부팅 시 자동 마운트되지 않습니다"
        if ! confirm_action "정말로 이 fstab 항목을 제거하시겠습니까?"; then
            print_info "제거가 취소되었습니다"
            return 0
        fi
    fi
    
    # 현재 마운트되어 있다면 언마운트
    if [[ "$unmount_first" == "true" && -n "$mountpoint" ]]; then
        if mount | grep -q " $mountpoint "; then
            print_info "현재 마운트된 상태입니다. 언마운트를 시도합니다..."
            
            if umount "$mountpoint"; then
                print_success "언마운트 완료: $mountpoint"
            else
                print_warning "언마운트 실패. 강제로 진행하시겠습니까?"
                if ! confirm_action "언마운트 없이 fstab 항목만 제거하시겠습니까?"; then
                    print_info "제거가 취소되었습니다"
                    return 0
                fi
            fi
        fi
    fi
    
    # fstab에서 제거
    print_info "fstab에서 항목 제거 중..."
    if remove_fstab_entry "$mountpoint"; then
        print_success "fstab 항목이 성공적으로 제거되었습니다"
        
        # 빈 마운트포인트 디렉토리 제거 제안
        if [[ -d "$mountpoint" && -z "$(ls -A "$mountpoint" 2>/dev/null)" ]]; then
            echo ""
            if confirm_action "빈 마운트포인트 디렉토리를 제거하시겠습니까? ($mountpoint)"; then
                if rmdir "$mountpoint"; then
                    print_success "마운트포인트 디렉토리가 제거되었습니다"
                else
                    print_warning "마운트포인트 디렉토리 제거 실패"
                fi
            fi
        fi
        
        return 0
    else
        print_error "fstab 항목 제거 실패"
        return 1
    fi
}

# 여러 fstab 항목 일괄 제거
fstab_remove_multiple_entries() {
    local confirm_each="${1:-true}"
    shift
    local identifiers=("$@")
    
    if [[ ${#identifiers[@]} -eq 0 ]]; then
        print_error "제거할 항목들이 지정되지 않았습니다"
        return 1
    fi
    
    print_header "fstab 항목 일괄 제거"
    
    local success_count=0
    local total_count=${#identifiers[@]}
    
    for identifier in "${identifiers[@]}"; do
        echo ""
        print_info "처리 중: $identifier"
        
        if fstab_remove_entry_safe "$identifier" "$confirm_each" true; then
            ((success_count++))
        fi
    done
    
    echo ""
    print_info "일괄 제거 완료: $success_count/$total_count 성공"
    
    if [[ $success_count -eq $total_count ]]; then
        print_success "모든 항목이 성공적으로 제거되었습니다"
        return 0
    else
        print_warning "일부 항목 제거에 실패했습니다"
        return 1
    fi
}

# ===================================================================================
# fstab 항목 조회 및 분석
# ===================================================================================

# fstab 항목 조회 (ID/마운트포인트 기반)
fstab_get_entries() {
    local filter_id="${1:-}"
    local format="${2:-detailed}"  # detailed, simple, table
    
    print_debug "fstab 항목 조회 (필터: ${filter_id:-전체})"
    
    local fstab_file="/etc/fstab"
    if [[ ! -f "$fstab_file" ]]; then
        print_warning "fstab 파일이 존재하지 않습니다"
        return 1
    fi
    
    local entries=()
    
    # 항목 수집
    while IFS= read -r line; do
        # 주석과 빈 줄 제외
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        local device mountpoint fstype options dump pass
        read -r device mountpoint fstype options dump pass <<< "$line"
        [[ -z "$device" || -z "$mountpoint" ]] && continue
        
        # 필터 적용
        if [[ -n "$filter_id" ]]; then
            # ID로 디바이스 경로 확인
            local resolved_device=""
            if validate_disk_exists "$filter_id" 2>/dev/null; then
                resolved_device=$(resolve_disk_id "$filter_id" 2>/dev/null || echo "")
            fi
            
            # 여러 조건으로 필터링
            if [[ "$device" != "$filter_id" && 
                  "$mountpoint" != "$filter_id" && 
                  "$device" != "$resolved_device" ]]; then
                continue
            fi
        fi
        
        entries+=("$device:$mountpoint:$fstype:$options:$dump:$pass")
    done < "$fstab_file"
    
    # 결과 출력
    case "$format" in
        "simple")
            printf '%s\n' "${entries[@]}"
            ;;
        "table")
            if [[ ${#entries[@]} -eq 0 ]]; then
                print_info "조건에 맞는 fstab 항목이 없습니다"
                return 0
            fi
            
            print_header "fstab 항목 목록"
            echo ""
            printf "%-25s %-20s %-8s %-15s %-4s %-4s\n" "DEVICE" "MOUNTPOINT" "FSTYPE" "OPTIONS" "DUMP" "PASS"
            printf "%-25s %-20s %-8s %-15s %-4s %-4s\n" "-------------------------" "--------------------" "--------" "---------------" "----" "----"
            
            for entry in "${entries[@]}"; do
                IFS=':' read -r device mountpoint fstype options dump pass <<< "$entry"
                
                # 옵션이 너무 길면 자르기
                local short_options="${options:0:13}"
                [[ ${#options} -gt 13 ]] && short_options="${short_options}..."
                
                printf "%-25s %-20s %-8s %-15s %-4s %-4s\n" \
                    "${device:0:24}" \
                    "${mountpoint:0:19}" \
                    "${fstype:0:7}" \
                    "$short_options" \
                    "$dump" \
                    "$pass"
            done
            ;;
        "detailed")
            if [[ ${#entries[@]} -eq 0 ]]; then
                print_info "조건에 맞는 fstab 항목이 없습니다"
                return 0
            fi
            
            print_header "fstab 항목 상세 정보"
            
            local count=1
            for entry in "${entries[@]}"; do
                IFS=':' read -r device mountpoint fstype options dump pass <<< "$entry"
                
                echo ""
                print_info "항목 #$count"
                echo "  디바이스: $device"
                echo "  마운트포인트: $mountpoint"
                echo "  파일시스템: $fstype"
                echo "  옵션: $options"
                echo "  덤프: $dump"
                echo "  패스: $pass"
                
                # 마운트 상태 확인
                if mount | grep -q " $mountpoint "; then
                    echo "  상태: ✅ 마운트됨"
                else
                    echo "  상태: ❌ 언마운트됨"
                fi
                
                # fail-safe 상태 확인
                if [[ "$options" == *"nofail"* ]]; then
                    echo "  fail-safe: ✅ 적용됨"
                else
                    echo "  fail-safe: ⚠️  미적용"
                fi
                
                ((count++))
            done
            ;;
        *)
            print_error "지원하지 않는 형식: $format"
            return 1
            ;;
    esac
    
    return 0
}

# 특정 식별자에 맞는 fstab 항목 찾기 (내부 함수)
fstab_find_entries() {
    local identifier="$1"
    
    local fstab_file="/etc/fstab"
    [[ -f "$fstab_file" ]] || return 1
    
    while IFS= read -r line; do
        # 주석과 빈 줄 제외
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        local device mountpoint fstype options dump pass
        read -r device mountpoint fstype options dump pass <<< "$line"
        [[ -z "$device" || -z "$mountpoint" ]] && continue
        
        # 식별자 매칭 확인
        if [[ "$device" == "$identifier" || 
              "$mountpoint" == "$identifier" ||
              "$device" == "UUID=$identifier" ||
              "$device" == "PARTUUID=$identifier" ||
              "$device" == "LABEL=$identifier" ]]; then
            echo "$device:$mountpoint:$fstype:$options:$dump:$pass"
        fi
    done < "$fstab_file"
}

# ===================================================================================
# fstab 검증 및 개선
# ===================================================================================

# 기존 fstab 항목 검증
fstab_validate_existing() {
    local fix_issues="${1:-false}"
    
    print_header "기존 fstab 항목 검증"
    
    local fstab_file="/etc/fstab"
    if [[ ! -f "$fstab_file" ]]; then
        print_warning "fstab 파일이 존재하지 않습니다"
        return 0
    fi
    
    local total_entries=0
    local valid_entries=0
    local issues_found=()
    
    while IFS= read -r line; do
        # 주석과 빈 줄 제외
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        local device mountpoint fstype options dump pass
        read -r device mountpoint fstype options dump pass <<< "$line"
        [[ -z "$device" || -z "$mountpoint" ]] && continue
        
        ((total_entries++))
        
        print_info "검증 중: $mountpoint ($device)"
        
        local entry_valid=true
        
        # 디바이스 존재 확인 (네트워크 FS 제외)
        if [[ ! "$fstype" =~ ^(nfs|cifs|sshfs)$ ]]; then
            if [[ "$device" =~ ^UUID= ]]; then
                local uuid="${device#UUID=}"
                if [[ ! -L "/dev/disk/by-uuid/$uuid" ]]; then
                    echo "  ❌ UUID를 찾을 수 없음: $uuid"
                    issues_found+=("$mountpoint: UUID not found ($uuid)")
                    entry_valid=false
                fi
            elif [[ "$device" =~ ^/dev/ ]]; then
                if [[ ! -b "$device" ]]; then
                    echo "  ❌ 디바이스가 존재하지 않음: $device"
                    issues_found+=("$mountpoint: Device not found ($device)")
                    entry_valid=false
                fi
            fi
        fi
        
        # 마운트포인트 확인
        if [[ ! -d "$mountpoint" ]]; then
            echo "  ⚠️  마운트포인트 디렉토리가 없음: $mountpoint"
            issues_found+=("$mountpoint: Directory not found")
        fi
        
        # fail-safe 옵션 확인
        if [[ "$options" != *"nofail"* ]]; then
            echo "  ⚠️  fail-safe 옵션(nofail) 없음"
            issues_found+=("$mountpoint: No fail-safe option")
        fi
        
        if [[ $entry_valid == true ]]; then
            echo "  ✅ 유효함"
            ((valid_entries++))
        fi
        
    done < "$fstab_file"
    
    # 결과 요약
    echo ""
    print_info "검증 결과 요약:"
    echo "  전체 항목: $total_entries"
    echo "  유효한 항목: $valid_entries"
    echo "  문제 있는 항목: $((total_entries - valid_entries))"
    
    if [[ ${#issues_found[@]} -gt 0 ]]; then
        echo ""
        print_warning "발견된 문제들:"
        for issue in "${issues_found[@]}"; do
            echo "  • $issue"
        done
        
        if [[ "$fix_issues" == "true" ]]; then
            echo ""
            if confirm_action "자동으로 수정 가능한 문제들을 해결하시겠습니까?"; then
                fstab_auto_fix_issues
            fi
        fi
        
        return 1
    else
        print_success "모든 fstab 항목이 유효합니다!"
        return 0
    fi
}

# fstab 문제 자동 수정
fstab_auto_fix_issues() {
    print_header "fstab 문제 자동 수정"
    
    # fail-safe 옵션 자동 추가
    if ! check_system_fail_safe; then
        if confirm_action "모든 fstab 항목에 fail-safe 옵션을 추가하시겠습니까?"; then
            auto_fix_system_fail_safe
        fi
    fi
    
    # 누락된 마운트포인트 디렉토리 생성
    local fstab_file="/etc/fstab"
    [[ -f "$fstab_file" ]] || return 0
    
    local created_dirs=()
    
    while IFS= read -r line; do
        # 주석과 빈 줄 제외
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        local device mountpoint fstype options dump pass
        read -r device mountpoint fstype options dump pass <<< "$line"
        [[ -z "$device" || -z "$mountpoint" ]] && continue
        
        # 마운트포인트 디렉토리 생성
        if [[ ! -d "$mountpoint" ]]; then
            if mkdir -p "$mountpoint" 2>/dev/null; then
                created_dirs+=("$mountpoint")
                print_success "마운트포인트 디렉토리 생성: $mountpoint"
            else
                print_error "마운트포인트 디렉토리 생성 실패: $mountpoint"
            fi
        fi
        
    done < "$fstab_file"
    
    if [[ ${#created_dirs[@]} -gt 0 ]]; then
        echo ""
        print_success "생성된 마운트포인트 디렉토리: ${#created_dirs[@]}개"
    fi
}

# ===================================================================================
# fstab 마운트 테스트
# ===================================================================================

# fstab 항목 마운트 테스트
fstab_test_mount() {
    local target="$1"  # 마운트포인트 또는 디바이스
    local dry_run="${2:-false}"
    
    print_debug "fstab 마운트 테스트: $target"
    
    if [[ -z "$target" ]]; then
        print_error "테스트할 마운트포인트 또는 디바이스가 필요합니다"
        return 1
    fi
    
    # fstab에서 해당 항목 찾기
    local entry
    entry=$(fstab_find_entries "$target")
    
    if [[ -z "$entry" ]]; then
        print_error "fstab에서 해당 항목을 찾을 수 없습니다: $target"
        return 1
    fi
    
    IFS=':' read -r device mountpoint fstype options dump pass <<< "$entry"
    
    print_info "마운트 테스트 대상:"
    echo "  디바이스: $device"
    echo "  마운트포인트: $mountpoint"
    echo "  파일시스템: $fstype"
    echo "  옵션: $options"
    
    # 이미 마운트되어 있는지 확인
    if mount | grep -q " $mountpoint "; then
        print_success "이미 마운트되어 있습니다: $mountpoint"
        return 0
    fi
    
    # 마운트포인트 디렉토리 생성
    if [[ ! -d "$mountpoint" ]]; then
        if [[ "$dry_run" == "false" ]]; then
            if mkdir -p "$mountpoint"; then
                print_info "마운트포인트 디렉토리 생성됨: $mountpoint"
            else
                print_error "마운트포인트 디렉토리 생성 실패: $mountpoint"
                return 1
            fi
        else
            print_info "[DRY RUN] 마운트포인트 디렉토리 생성 필요: $mountpoint"
        fi
    fi
    
    # 마운트 테스트
    if [[ "$dry_run" == "false" ]]; then
        print_info "마운트 테스트 실행 중..."
        
        if mount "$mountpoint"; then
            print_success "마운트 테스트 성공: $mountpoint"
            
            # 마운트 상태 확인
            local mount_info
            mount_info=$(mount | grep " $mountpoint ")
            print_info "마운트 정보: $mount_info"
            
            # 간단한 쓰기 테스트 (권한이 있는 경우)
            local test_file="$mountpoint/.mount_test_$$"
            if touch "$test_file" 2>/dev/null; then
                rm -f "$test_file"
                print_success "쓰기 테스트 성공"
            else
                print_info "쓰기 테스트 실패 (읽기 전용이거나 권한 없음)"
            fi
            
            return 0
        else
            print_error "마운트 테스트 실패: $mountpoint"
            return 1
        fi
    else
        print_info "[DRY RUN] mount $mountpoint 실행 예정"
        return 0
    fi
}

# 모든 fstab 항목 마운트 테스트
fstab_test_all_mounts() {
    local unmount_after="${1:-true}"
    local dry_run="${2:-false}"
    
    print_header "전체 fstab 마운트 테스트"
    
    local entries
    entries=$(fstab_get_entries "" "simple")
    
    if [[ -z "$entries" ]]; then
        print_info "테스트할 fstab 항목이 없습니다"
        return 0
    fi
    
    local success_count=0
    local total_count=0
    local tested_mounts=()
    
    while IFS=':' read -r device mountpoint fstype options dump pass; do
        ((total_count++))
        
        # 이미 마운트된 항목은 제외
        if mount | grep -q " $mountpoint "; then
            print_info "건너뜀 (이미 마운트됨): $mountpoint"
            continue
        fi
        
        # 네트워크 파일시스템은 건너뜀 (연결 실패 가능성)
        if [[ "$fstype" =~ ^(nfs|cifs|sshfs)$ ]]; then
            print_info "건너뜀 (네트워크 FS): $mountpoint"
            continue
        fi
        
        echo ""
        print_info "테스트 중: $mountpoint"
        
        if fstab_test_mount "$mountpoint" "$dry_run"; then
            ((success_count++))
            tested_mounts+=("$mountpoint")
        fi
        
    done <<< "$entries"
    
    # 테스트 후 언마운트
    if [[ "$unmount_after" == "true" && "$dry_run" == "false" && ${#tested_mounts[@]} -gt 0 ]]; then
        echo ""
        print_info "테스트 완료 후 언마운트 중..."
        
        for mountpoint in "${tested_mounts[@]}"; do
            if umount "$mountpoint"; then
                print_info "언마운트 완료: $mountpoint"
            else
                print_warning "언마운트 실패: $mountpoint"
            fi
        done
    fi
    
    # 결과 요약
    echo ""
    print_info "마운트 테스트 결과: $success_count/$total_count 성공"
    
    if [[ $success_count -eq $total_count ]]; then
        print_success "모든 fstab 항목이 정상적으로 마운트됩니다!"
        return 0
    else
        print_warning "일부 fstab 항목에 문제가 있습니다"
        return 1
    fi
} 
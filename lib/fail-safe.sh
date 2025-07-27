#!/bin/bash

# ===================================================================================
# fail-safe.sh - nofail 옵션 자동 관리 시스템
# ===================================================================================
#
# 이 모듈은 시스템의 부팅 안정성을 보장하기 위해 fstab 항목에 fail-safe 옵션을
# 자동으로 적용하는 시스템입니다.
#
# 주요 기능:
# - nofail 옵션 자동 적용 (기본값)
# - RAID용 추가 안전 옵션 (noauto + nofail)
# - 기존 옵션과의 호환성 관리
# - 사용자 선택적 적용 (기존 호환성)
#
# ===================================================================================

# 공통 라이브러리 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${RED:-}" ]]; then
    # shellcheck source=lib/common.sh
    source "${SCRIPT_DIR}/common.sh"
fi

# ===================================================================================
# 기본 fail-safe 옵션 관리
# ===================================================================================

# nofail 옵션 자동 추가 (기본 동작)
apply_fail_safe_options() {
    local options="$1"
    local force_enable="${2:-true}"  # 기본적으로 활성화
    local mode="${3:-auto}"          # auto, interactive, force
    
    print_debug "fail-safe 옵션 적용: $options (모드: $mode)"
    
    # 이미 nofail이 있는지 확인
    if [[ "$options" == *"nofail"* ]]; then
        print_debug "nofail 옵션이 이미 존재합니다"
        echo "$options"
        return 0
    fi
    
    case "$mode" in
        "auto"|"force")
            # 자동 적용 (기본 동작)
            _add_nofail_option "$options"
            ;;
        "interactive")
            # 사용자 선택 (기존 호환성)
            _add_nofail_interactive "$options"
            ;;
        *)
            print_error "알 수 없는 모드: $mode"
            echo "$options"
            return 1
            ;;
    esac
}

# nofail 옵션 추가 (내부 함수)
_add_nofail_option() {
    local options="$1"
    
    if [[ -z "$options" || "$options" == "defaults" ]]; then
        echo "defaults,nofail"
    else
        echo "$options,nofail"
    fi
    
    print_debug "nofail 옵션 추가됨: $options → $(_add_nofail_option "$options")"
}

# nofail 옵션 인터랙티브 추가 (기존 호환성)
_add_nofail_interactive() {
    local options="$1"
    
    print_info "💡 fail-safe 옵션 추천"
    print_info "   nofail: 디스크가 없거나 마운트 실패해도 부팅이 중단되지 않습니다"
    print_info "   이 옵션은 시스템 안정성을 크게 향상시킵니다"
    
    if confirm_action "fail-safe 옵션(nofail)을 활성화하시겠습니까? (강력 권장)"; then
        local result
        result=$(_add_nofail_option "$options")
        print_success "nofail 옵션이 추가되었습니다"
        echo "$result"
    else
        print_warning "fail-safe 옵션을 사용하지 않습니다"
        print_warning "⚠️  디스크 문제 시 시스템이 부팅되지 않을 수 있습니다"
        echo "$options"
    fi
}

# ===================================================================================
# RAID 전용 fail-safe 옵션
# ===================================================================================

# RAID용 fail-safe 옵션 적용 (더 안전하게)
apply_raid_fail_safe_options() {
    local options="$1"
    local raid_type="${2:-software}"  # software, hardware
    local mode="${3:-auto}"
    
    print_debug "RAID fail-safe 옵션 적용: $options (타입: $raid_type)"
    
    case "$mode" in
        "auto"|"force")
            _add_raid_safe_options "$options" "$raid_type"
            ;;
        "interactive")
            _add_raid_safe_interactive "$options" "$raid_type"
            ;;
        *)
            print_error "알 수 없는 모드: $mode"
            echo "$options"
            return 1
            ;;
    esac
}

# RAID 안전 옵션 추가 (내부 함수)
_add_raid_safe_options() {
    local options="$1"
    local raid_type="$2"
    
    # 기본 nofail 옵션 추가
    local safe_options
    safe_options=$(_add_nofail_option "$options")
    
    case "$raid_type" in
        "software")
            # 소프트웨어 RAID: noauto 추가 (재구축 시 안전)
            if [[ "$safe_options" != *"noauto"* ]]; then
                safe_options="$safe_options,noauto"
                print_debug "소프트웨어 RAID용 noauto 옵션 추가"
            fi
            ;;
        "hardware")
            # 하드웨어 RAID: nofail만 적용
            print_debug "하드웨어 RAID용 기본 fail-safe 적용"
            ;;
    esac
    
    echo "$safe_options"
}

# RAID 안전 옵션 인터랙티브 추가
_add_raid_safe_interactive() {
    local options="$1"
    local raid_type="$2"
    
    print_header "RAID fail-safe 옵션 설정"
    print_info "RAID 환경에서는 추가 안전 옵션을 권장합니다:"
    print_info "  nofail: 디스크 실패 시 부팅 중단 방지"
    
    case "$raid_type" in
        "software")
            print_info "  noauto: RAID 재구축 중 자동 마운트 방지"
            print_info ""
            print_warning "소프트웨어 RAID는 degraded 모드에서 불안정할 수 있습니다"
            ;;
        "hardware")
            print_info ""
            print_info "하드웨어 RAID는 일반적으로 더 안정적입니다"
            ;;
    esac
    
    # nofail 옵션은 항상 권장
    local safe_options
    if confirm_action "기본 fail-safe 옵션(nofail)을 활성화하시겠습니까? (필수 권장)"; then
        safe_options=$(_add_nofail_option "$options")
        print_success "nofail 옵션이 추가되었습니다"
    else
        safe_options="$options"
        print_error "⚠️  RAID에서 fail-safe 옵션 없이는 매우 위험합니다!"
    fi
    
    # 소프트웨어 RAID의 경우 noauto 옵션 추가 제안
    if [[ "$raid_type" == "software" && "$safe_options" != *"noauto"* ]]; then
        print_info ""
        print_info "추가 안전 옵션: noauto"
        print_info "  - RAID 재구축 중 자동 마운트 방지"
        print_info "  - 수동 마운트로 안전성 확보"
        
        if confirm_action "noauto 옵션을 추가하시겠습니까? (RAID 재구축 안전성)"; then
            safe_options="$safe_options,noauto"
            print_success "noauto 옵션이 추가되었습니다"
            print_info "💡 RAID 재구축 완료 후 수동으로 마운트하세요: mount /your/mountpoint"
        fi
    fi
    
    echo "$safe_options"
}

# ===================================================================================
# 기존 옵션 분석 및 개선
# ===================================================================================

# 기존 fstab 옵션 분석
analyze_existing_options() {
    local options="$1"
    local context="${2:-general}"  # general, raid
    
    print_debug "기존 옵션 분석: $options (컨텍스트: $context)"
    
    local has_nofail=false
    local has_noauto=false
    local has_unsafe_options=false
    local recommendations=()
    
    # 현재 옵션 분석
    [[ "$options" == *"nofail"* ]] && has_nofail=true
    [[ "$options" == *"noauto"* ]] && has_noauto=true
    
    # 위험한 옵션 확인
    if [[ "$options" == *"_netdev"* ]]; then
        recommendations+=("네트워크 디바이스에는 nofail 옵션이 필수입니다")
        has_unsafe_options=true
    fi
    
    # 분석 결과 출력
    print_info "기존 옵션 분석 결과:"
    echo "  현재 옵션: $options"
    echo "  nofail 상태: $([ $has_nofail = true ] && echo "✅ 적용됨" || echo "❌ 없음")"
    echo "  noauto 상태: $([ $has_noauto = true ] && echo "✅ 적용됨" || echo "⚠️  없음")"
    
    # 컨텍스트별 권장사항
    case "$context" in
        "raid")
            if [ $has_nofail = false ]; then
                recommendations+=("RAID에는 nofail 옵션이 필수입니다")
            fi
            if [ $has_noauto = false ]; then
                recommendations+=("소프트웨어 RAID에는 noauto 옵션을 권장합니다")
            fi
            ;;
        "network")
            if [ $has_nofail = false ]; then
                recommendations+=("네트워크 마운트에는 nofail 옵션이 필수입니다")
            fi
            ;;
        *)
            if [ $has_nofail = false ]; then
                recommendations+=("시스템 안정성을 위해 nofail 옵션을 권장합니다")
            fi
            ;;
    esac
    
    # 권장사항 출력
    if [[ ${#recommendations[@]} -gt 0 ]]; then
        echo ""
        print_warning "권장사항:"
        for rec in "${recommendations[@]}"; do
            echo "  • $rec"
        done
    fi
    
    return $([ $has_unsafe_options = true ] && echo 1 || echo 0)
}

# 기존 옵션 개선 제안
suggest_option_improvements() {
    local current_options="$1"
    local context="${2:-general}"
    
    print_header "옵션 개선 제안"
    
    # 현재 상태 분석
    analyze_existing_options "$current_options" "$context"
    
    # 개선된 옵션 생성
    local improved_options
    case "$context" in
        "raid")
            improved_options=$(apply_raid_fail_safe_options "$current_options" "software" "auto")
            ;;
        *)
            improved_options=$(apply_fail_safe_options "$current_options" true "auto")
            ;;
    esac
    
    if [[ "$improved_options" != "$current_options" ]]; then
        echo ""
        print_success "개선된 옵션 제안:"
        echo "  현재: $current_options"
        echo "  개선: $improved_options"
        echo ""
        
        if confirm_action "개선된 옵션을 적용하시겠습니까?"; then
            echo "$improved_options"
            return 0
        else
            echo "$current_options"
            return 1
        fi
    else
        print_success "현재 옵션이 이미 최적입니다"
        echo "$current_options"
        return 0
    fi
}

# ===================================================================================
# 특수 상황별 fail-safe 처리
# ===================================================================================

# 네트워크 파일시스템용 fail-safe
apply_network_fail_safe() {
    local options="$1"
    local fs_type="${2:-nfs}"
    
    print_debug "네트워크 파일시스템 fail-safe: $fs_type"
    
    # 네트워크 파일시스템에는 nofail 필수
    local safe_options
    safe_options=$(_add_nofail_option "$options")
    
    # _netdev 옵션이 없으면 추가
    if [[ "$safe_options" != *"_netdev"* ]]; then
        safe_options="$safe_options,_netdev"
        print_debug "_netdev 옵션 추가됨"
    fi
    
    # timeo와 retrans 옵션 확인 (NFS)
    if [[ "$fs_type" == "nfs"* ]]; then
        if [[ "$safe_options" != *"timeo="* ]]; then
            safe_options="$safe_options,timeo=14"
            print_debug "NFS timeo 옵션 추가됨"
        fi
        if [[ "$safe_options" != *"retrans="* ]]; then
            safe_options="$safe_options,retrans=2"
            print_debug "NFS retrans 옵션 추가됨"
        fi
    fi
    
    echo "$safe_options"
}

# 이동식 미디어용 fail-safe
apply_removable_fail_safe() {
    local options="$1"
    local device_type="${2:-usb}"  # usb, cd, floppy
    
    print_debug "이동식 미디어 fail-safe: $device_type"
    
    # 기본 nofail 적용
    local safe_options
    safe_options=$(_add_nofail_option "$options")
    
    # noauto 옵션 추가 (이동식 미디어는 수동 마운트)
    if [[ "$safe_options" != *"noauto"* ]]; then
        safe_options="$safe_options,noauto"
        print_debug "이동식 미디어용 noauto 옵션 추가됨"
    fi
    
    # user 옵션 추가 (일반 사용자 마운트 허용)
    if [[ "$safe_options" != *"user"* && "$safe_options" != *"users"* ]]; then
        safe_options="$safe_options,user"
        print_debug "user 옵션 추가됨"
    fi
    
    echo "$safe_options"
}

# ===================================================================================
# 시스템 전체 fail-safe 검사 및 수정
# ===================================================================================

# 전체 fstab fail-safe 상태 검사
check_system_fail_safe() {
    local fstab_file="/etc/fstab"
    
    if [[ ! -f "$fstab_file" ]]; then
        print_info "fstab 파일이 없습니다"
        return 0
    fi
    
    print_header "시스템 fail-safe 상태 검사"
    
    local total_entries=0
    local safe_entries=0
    local unsafe_entries=()
    
    # fstab 항목별 검사
    while IFS= read -r line; do
        # 주석과 빈 줄 제외
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # 필드 분할
        read -r device mountpoint fstype options dump pass <<< "$line"
        [[ -z "$device" || -z "$mountpoint" ]] && continue
        
        ((total_entries++))
        
        # nofail 옵션 확인
        if [[ "$options" == *"nofail"* ]]; then
            ((safe_entries++))
            print_success "✅ $mountpoint (nofail 적용됨)"
        else
            unsafe_entries+=("$mountpoint:$options")
            print_warning "⚠️  $mountpoint (nofail 없음: $options)"
        fi
        
    done < "$fstab_file"
    
    # 결과 요약
    echo ""
    print_info "검사 결과 요약:"
    echo "  전체 항목: $total_entries"
    echo "  안전한 항목: $safe_entries"
    echo "  개선 필요: $((total_entries - safe_entries))"
    
    if [[ ${#unsafe_entries[@]} -gt 0 ]]; then
        echo ""
        print_warning "개선이 필요한 항목들:"
        for entry in "${unsafe_entries[@]}"; do
            IFS=':' read -r mp opts <<< "$entry"
            echo "  • $mp ($opts)"
        done
        
        return 1
    else
        print_success "모든 fstab 항목이 fail-safe 옵션을 사용합니다!"
        return 0
    fi
}

# 전체 fstab fail-safe 자동 적용
auto_fix_system_fail_safe() {
    local fstab_file="/etc/fstab"
    local backup_file
    
    if [[ ! -f "$fstab_file" ]]; then
        print_error "fstab 파일이 없습니다"
        return 1
    fi
    
    print_header "시스템 fail-safe 자동 수정"
    
    # 백업 생성
    backup_file="${fstab_file}.backup.$(date +%Y%m%d_%H%M%S)"
    if ! cp "$fstab_file" "$backup_file"; then
        print_error "fstab 백업 실패"
        return 1
    fi
    print_success "fstab 백업 생성: $backup_file"
    
    # 임시 파일 생성
    local temp_file
    temp_file=$(mktemp)
    
    # fstab 수정
    local modified_count=0
    while IFS= read -r line; do
        # 주석과 빈 줄은 그대로 유지
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            echo "$line" >> "$temp_file"
            continue
        fi
        
        # 필드 분할
        read -r device mountpoint fstype options dump pass <<< "$line"
        if [[ -z "$device" || -z "$mountpoint" ]]; then
            echo "$line" >> "$temp_file"
            continue
        fi
        
        # nofail 옵션이 없으면 추가
        if [[ "$options" != *"nofail"* ]]; then
            local new_options
            new_options=$(_add_nofail_option "$options")
            echo "$device $mountpoint $fstype $new_options $dump $pass" >> "$temp_file"
            print_info "수정됨: $mountpoint ($options → $new_options)"
            ((modified_count++))
        else
            echo "$line" >> "$temp_file"
        fi
        
    done < "$fstab_file"
    
    # 수정된 fstab 적용
    if [[ $modified_count -gt 0 ]]; then
        if mv "$temp_file" "$fstab_file"; then
            print_success "fstab 수정 완료: ${modified_count}개 항목 개선"
            print_info "백업 파일: $backup_file"
        else
            print_error "fstab 수정 실패"
            rm -f "$temp_file"
            return 1
        fi
    else
        print_success "모든 항목이 이미 fail-safe 옵션을 사용합니다"
        rm -f "$temp_file"
    fi
    
    return 0
}

# ===================================================================================
# 테스트 및 진단 함수
# ===================================================================================

# fail-safe 옵션 테스트
test_fail_safe_options() {
    local test_options="$1"
    local context="${2:-general}"
    
    print_header "fail-safe 옵션 테스트"
    
    echo "입력 옵션: $test_options"
    echo "컨텍스트: $context"
    echo ""
    
    case "$context" in
        "raid")
            local result
            result=$(apply_raid_fail_safe_options "$test_options" "software" "auto")
            echo "RAID 결과: $result"
            ;;
        "network")
            local result
            result=$(apply_network_fail_safe "$test_options" "nfs")
            echo "네트워크 결과: $result"
            ;;
        *)
            local result
            result=$(apply_fail_safe_options "$test_options" true "auto")
            echo "일반 결과: $result"
            ;;
    esac
} 
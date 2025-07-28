#!/bin/bash

# ===================================================================================
# disk-functions.sh - 디스크 관련 함수 라이브러리
# ===================================================================================

# 공통 라이브러리 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/common.sh"

# ===================================================================================
# 디스크 탐지 및 정보 수집
# ===================================================================================

# 모든 디스크 목록 가져오기
get_all_disks() {
    local include_partitions="${1:-false}"
    local output_format="${2:-simple}"  # simple, detailed, json
    
    if [[ "$include_partitions" == "true" ]]; then
        lsblk -d -n -o NAME,SIZE,TYPE,MODEL,SERIAL | grep -E "disk|part"
    else
        lsblk -d -n -o NAME,SIZE,TYPE,MODEL,SERIAL | grep "disk"
    fi
}

# 특정 디스크 정보 가져오기
get_disk_info() {
    local disk="$1"
    local format="${2:-detailed}"
    
    check_disk_exists "$disk" || return 1
    
    case "$format" in
        "simple")
            lsblk -n -o NAME,SIZE,TYPE "$disk"
            ;;
        "detailed")
            lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID,MODEL "$disk"
            ;;
        "json")
            lsblk -J -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID,MODEL "$disk"
            ;;
        *)
            print_error "지원하지 않는 포맷: $format"
            return 1
            ;;
    esac
}

# 디스크 크기 가져오기 (바이트 단위)
get_disk_size() {
    local disk="$1"
    
    check_disk_exists "$disk" || return 1
    
    if command -v blockdev &> /dev/null; then
        blockdev --getsize64 "$disk" 2>/dev/null
    else
        # fallback: lsblk 사용
        local size_str
        size_str=$(lsblk -b -d -n -o SIZE "$disk" 2>/dev/null)
        echo "${size_str// /}"  # 공백 제거
    fi
}

# 디스크 크기를 읽기 쉬운 형태로 변환
format_disk_size() {
    local size_bytes="$1"
    
    if [[ ! "$size_bytes" =~ ^[0-9]+$ ]]; then
        echo "Invalid size"
        return 1
    fi
    
    local units=("B" "KB" "MB" "GB" "TB")
    local size=$size_bytes
    local unit_index=0
    
    while [[ $size -ge 1024 && $unit_index -lt $((${#units[@]} - 1)) ]]; do
        size=$((size / 1024))
        ((unit_index++))
    done
    
    printf "%.1f %s" "$size" "${units[$unit_index]}"
}

# 사용 가능한 디스크 목록 (RAID에 사용 가능한)
get_available_disks() {
    local min_size="${1:-$MIN_DISK_SIZE}"
    local exclude_mounted="${2:-true}"
    
    local available_disks=()
    
    while IFS= read -r line; do
        local disk="/dev/${line%% *}"
        local size_bytes
        
        # 크기 확인
        size_bytes=$(get_disk_size "$disk")
        if [[ -z "$size_bytes" ]] || [[ "$size_bytes" -lt "$min_size" ]]; then
            print_debug "디스크 $disk 크기가 너무 작음: $size_bytes bytes"
            continue
        fi
        
        # 마운트 상태 확인
        if [[ "$exclude_mounted" == "true" ]]; then
            if is_disk_mounted "$disk"; then
                print_debug "디스크 $disk가 이미 마운트됨"
                continue
            fi
        fi
        
        # RAID 멤버 여부 확인
        if is_raid_member "$disk"; then
            print_debug "디스크 $disk가 이미 RAID 멤버임"
            continue
        fi
        
        available_disks+=("$disk")
        
    done <<< "$(get_all_disks false)"
    
    printf '%s\n' "${available_disks[@]}"
}

# ===================================================================================
# 디스크 상태 검사
# ===================================================================================

# SMART 상태 확인
check_disk_smart() {
    local disk="$1"
    local detailed="${2:-false}"
    
    check_disk_exists "$disk" || return 1
    
    if ! command -v smartctl &> /dev/null; then
        print_warning "smartctl이 설치되지 않음"
        return 2
    fi
    
    # SMART 지원 여부 확인
    if ! smartctl -i "$disk" | grep -q "SMART support is: Available"; then
        print_warning "$disk는 SMART를 지원하지 않음"
        return 2
    fi
    
    local health_output
    health_output=$(smartctl -H "$disk" 2>/dev/null)
    local health_status=$?
    
    if [[ $health_status -eq 0 ]]; then
        if echo "$health_output" | grep -q "PASSED"; then
            [[ "$detailed" == "true" ]] && echo "$health_output"
            return 0  # 건강함
        else
            [[ "$detailed" == "true" ]] && echo "$health_output"
            return 1  # 문제 있음
        fi
    else
        print_error "$disk SMART 검사 실패"
        return 3
    fi
}

# 디스크 마운트 상태 확인
is_disk_mounted() {
    local disk="$1"
    
    # 디스크 자체와 파티션들 확인
    if mount | grep -q "^${disk}"; then
        return 0  # 마운트됨
    fi
    
    return 1  # 마운트되지 않음
}

# RAID 멤버 여부 확인
is_raid_member() {
    local disk="$1"
    
    # lsblk로 RAID 멤버 확인
    if lsblk -n -o FSTYPE "$disk" 2>/dev/null | grep -q "linux_raid_member"; then
        return 0  # RAID 멤버임
    fi
    
    # mdadm으로 추가 확인
    if command -v mdadm &> /dev/null; then
        if mdadm --examine "$disk" &>/dev/null; then
            return 0  # RAID 멤버임
        fi
    fi
    
    return 1  # RAID 멤버가 아님
}

# 디스크 사용 중 여부 확인
is_disk_in_use() {
    local disk="$1"
    
    # 마운트 확인
    if is_disk_mounted "$disk"; then
        return 0
    fi
    
    # RAID 멤버 확인
    if is_raid_member "$disk"; then
        return 0
    fi
    
    # 스왑 확인
    if swapon --show=NAME --noheadings | grep -q "^${disk}"; then
        return 0
    fi
    
    # LVM 확인
    if command -v pvs &> /dev/null; then
        if pvs --noheadings -o pv_name | grep -q "^${disk}"; then
            return 0
        fi
    fi
    
    return 1  # 사용 중이 아님
}

# ===================================================================================
# 디스크 작업
# ===================================================================================

# 디스크 포맷 (파티션 테이블 생성)
format_disk() {
    local disk="$1"
    local partition_type="${2:-gpt}"  # gpt, msdos
    local confirm="${3:-true}"
    
    check_disk_exists "$disk" || return 1
    
    if [[ "$confirm" == "true" ]]; then
        if ! confirm_action "디스크 $disk를 포맷하시겠습니까? (모든 데이터가 삭제됩니다)"; then
            print_info "포맷이 취소되었습니다."
            return 1
        fi
    fi
    
    print_info "디스크 $disk 포맷 중..."
    
    # 파티션 테이블 생성
    if safe_execute "parted -s $disk mklabel $partition_type"; then
        print_success "디스크 $disk 포맷 완료"
        return 0
    else
        print_error "디스크 $disk 포맷 실패"
        return 1
    fi
}

# 디스크 초기화 (데이터 완전 삭제)
wipe_disk() {
    local disk="$1"
    local method="${2:-quick}"  # quick, secure, zero
    local confirm="${3:-true}"
    
    check_disk_exists "$disk" || return 1
    
    if [[ "$confirm" == "true" ]]; then
        if ! confirm_action "디스크 $disk를 완전히 초기화하시겠습니까? (복구 불가능)"; then
            print_info "초기화가 취소되었습니다."
            return 1
        fi
    fi
    
    case "$method" in
        "quick")
            print_info "디스크 $disk 빠른 초기화 중..."
            safe_execute "dd if=/dev/zero of=$disk bs=1M count=100 status=progress"
            ;;
        "zero")
            print_info "디스크 $disk 완전 초기화 중..."
            safe_execute "dd if=/dev/zero of=$disk bs=1M status=progress"
            ;;
        "secure")
            print_info "디스크 $disk 보안 초기화 중..."
            if command -v shred &> /dev/null; then
                safe_execute "shred -vfz -n 3 $disk"
            else
                print_warning "shred 명령어가 없어 zero 방식으로 대체"
                safe_execute "dd if=/dev/zero of=$disk bs=1M status=progress"
            fi
            ;;
        *)
            print_error "지원하지 않는 초기화 방법: $method"
            return 1
            ;;
    esac
}

# 디스크 파티션 생성
create_partition() {
    local disk="$1"
    local partition_type="${2:-primary}"  # primary, extended, logical
    local filesystem="${3:-ext4}"
    local size="${4:-100%}"  # 크기 (100%는 전체)
    
    check_disk_exists "$disk" || return 1
    
    print_info "디스크 $disk에 파티션 생성 중..."
    
    # GPT 파티션 테이블인지 확인
    local table_type
    table_type=$(parted -s "$disk" print | grep "Partition Table:" | awk '{print $3}')
    
    if [[ "$table_type" == "gpt" ]]; then
        # GPT 파티션 생성
        safe_execute "parted -s $disk mkpart primary $filesystem 0% $size"
    else
        # MBR 파티션 생성
        safe_execute "parted -s $disk mkpart $partition_type $filesystem 0% $size"
    fi
    
    # 파티션 디바이스명 결정
    local partition="${disk}1"
    if [[ "$disk" =~ nvme ]]; then
        partition="${disk}p1"
    fi
    
    # 파티션 테이블 재로드
    safe_execute "partprobe $disk"
    sleep 2
    
    echo "$partition"
}

# ===================================================================================
# 디스크 정보 비교 및 검증
# ===================================================================================

# 디스크 크기 비교
compare_disk_sizes() {
    local -a disks=("$@")
    local sizes=()
    local min_size=0
    local max_size=0
    
    # 각 디스크 크기 수집
    for disk in "${disks[@]}"; do
        local size
        size=$(get_disk_size "$disk")
        if [[ -n "$size" && "$size" =~ ^[0-9]+$ ]]; then
            sizes+=("$size")
            
            if [[ $min_size -eq 0 || $size -lt $min_size ]]; then
                min_size=$size
            fi
            
            if [[ $size -gt $max_size ]]; then
                max_size=$size
            fi
        else
            print_error "디스크 $disk 크기를 확인할 수 없음"
            return 1
        fi
    done
    
    # 크기 차이 계산 (백분율)
    if [[ $min_size -gt 0 ]]; then
        local size_diff_percent=$(( (max_size - min_size) * 100 / min_size ))
        
        if [[ $size_diff_percent -gt ${WARN_DISK_SIZE_DIFF:-10} ]]; then
            print_warning "디스크 크기 차이가 ${size_diff_percent}%입니다"
            return 2  # 경고
        fi
    fi
    
    return 0  # 크기가 유사함
}

# 디스크 호환성 검사
check_disk_compatibility() {
    local -a disks=("$@")
    local issues=0
    
    print_info "디스크 호환성 검사 중..."
    
    # 최소 개수 확인
    if [[ ${#disks[@]} -lt 2 ]]; then
        print_error "최소 2개의 디스크가 필요합니다"
        return 1
    fi
    
    # 각 디스크 개별 검사
    for disk in "${disks[@]}"; do
        print_debug "디스크 $disk 검사 중..."
        
        # 존재 여부
        if ! check_disk_exists "$disk"; then
            ((issues++))
            continue
        fi
        
        # 사용 중 여부
        if is_disk_in_use "$disk"; then
            print_warning "디스크 $disk가 사용 중입니다"
            ((issues++))
        fi
        
        # SMART 상태 (선택적)
        if [[ "${SMART_CHECK_ENABLED:-true}" == "true" ]]; then
            if ! check_disk_smart "$disk"; then
                print_warning "디스크 $disk SMART 상태에 문제가 있습니다"
                # SMART 문제는 치명적 오류로 처리하지 않음
            fi
        fi
    done
    
    # 크기 비교
    if ! compare_disk_sizes "${disks[@]}"; then
        local comparison_result=$?
        if [[ $comparison_result -eq 2 ]]; then
            # 경고만 출력, 계속 진행 가능
            print_warning "디스크 크기가 다릅니다. 작은 디스크 크기에 맞춰집니다."
        fi
    fi
    
    if [[ $issues -gt 0 ]]; then
        print_error "총 $issues개의 문제가 발견되었습니다"
        return 1
    fi
    
    print_success "모든 디스크가 호환 가능합니다"
    return 0
} 
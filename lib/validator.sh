#!/bin/bash

# ===================================================================================
# validator.sh - 통합 검증 시스템
# ===================================================================================
#
# 이 모듈은 모든 디스크 관련 작업에서 사용하는 검증 로직을 제공합니다.
# id-resolver.sh를 활용하여 ID 기반 검증을 수행하며, 다음과 같은 검증을 지원합니다:
#
# - 디스크 존재 여부 검증
# - RAID용 디스크 사용 가능성 검증
# - fstab 항목 유효성 검증
# - 마운트포인트 충돌 검사
# - 파일시스템 호환성 검증
#
# ===================================================================================

# 공통 라이브러리 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# id-resolver.sh 로드
if [[ -f "${SCRIPT_DIR}/id-resolver.sh" ]]; then
    # shellcheck source=lib/id-resolver.sh
    source "${SCRIPT_DIR}/id-resolver.sh"
else
    echo "❌ 오류: id-resolver.sh를 찾을 수 없습니다" >&2
    exit 1
fi

# common.sh가 이미 로드되지 않았다면 로드
if [[ -z "${RED:-}" ]]; then
    # shellcheck source=lib/common.sh
    source "${SCRIPT_DIR}/common.sh"
fi

# ===================================================================================
# 기본 디스크 검증 함수
# ===================================================================================

# 디스크 존재 여부 검증 (ID 기반)
validate_disk_exists() {
    local id="$1"
    
    if [[ -z "$id" ]]; then
        print_error "디스크 ID가 지정되지 않았습니다"
        return 1
    fi
    
    print_debug "디스크 존재 확인: $id"
    
    # ID 형식 검증
    if ! validate_id_format "$id"; then
        print_error "유효하지 않은 디스크 ID 형식: $id"
        return 1
    fi
    
    # 실제 디바이스로 변환 및 존재 확인
    local device
    if device=$(resolve_disk_id "$id"); then
        if [[ -b "$device" ]]; then
            print_debug "디스크 존재 확인됨: $id → $device"
            return 0
        else
            print_error "디스크가 존재하지 않습니다: $device"
            return 1
        fi
    else
        print_error "디스크 ID를 해석할 수 없습니다: $id"
        return 1
    fi
}

# 디스크 읽기 가능 여부 검증
validate_disk_readable() {
    local id="$1"
    
    validate_disk_exists "$id" || return 1
    
    local device
    device=$(resolve_disk_id "$id")
    
    # 읽기 권한 확인
    if [[ -r "$device" ]]; then
        print_debug "디스크 읽기 가능: $device"
        return 0
    else
        print_error "디스크 읽기 권한이 없습니다: $device"
        return 1
    fi
}

# 디스크 쓰기 가능 여부 검증
validate_disk_writable() {
    local id="$1"
    
    validate_disk_exists "$id" || return 1
    
    local device
    device=$(resolve_disk_id "$id")
    
    # 쓰기 권한 확인
    if [[ -w "$device" ]]; then
        print_debug "디스크 쓰기 가능: $device"
        return 0
    else
        print_error "디스크 쓰기 권한이 없습니다: $device"
        return 1
    fi
}

# ===================================================================================
# RAID용 디스크 검증 함수
# ===================================================================================

# RAID용 디스크 사용 가능 여부 검증
validate_disk_available_for_raid() {
    local id="$1"
    
    print_debug "RAID용 디스크 검증: $id"
    
    # 기본 존재 확인
    validate_disk_exists "$id" || return 1
    
    local device
    device=$(resolve_disk_id "$id")
    
    # 1. 현재 마운트되지 않았는지 확인
    if mount | grep -q "^$device "; then
        print_error "디스크가 현재 마운트되어 있습니다: $device"
        return 1
    fi
    
    # 2. 이미 RAID 멤버가 아닌지 확인
    local fstype
    fstype=$(blkid -s TYPE -o value "$device" 2>/dev/null)
    if [[ "$fstype" == "linux_raid_member" ]]; then
        print_error "디스크가 이미 RAID 멤버입니다: $device"
        return 1
    fi
    
    # 3. LVM이나 다른 시스템에서 사용 중이 아닌지 확인
    if [[ "$fstype" == "LVM2_member" ]]; then
        print_error "디스크가 LVM에서 사용 중입니다: $device"
        return 1
    fi
    
    # 4. 파티션이 있는 전체 디스크인지 확인
    local parent_device
    parent_device=$(lsblk -n -o PKNAME "$device" 2>/dev/null)
    if [[ -n "$parent_device" ]]; then
        # 파티션인 경우 - 사용 가능
        print_debug "파티션 디스크 사용 가능: $device"
    else
        # 전체 디스크인 경우 - 파티션 테이블 확인
        if parted -s "$device" print 2>/dev/null | grep -q "Partition Table"; then
            print_warning "디스크에 파티션 테이블이 있습니다: $device"
            print_warning "RAID 생성 시 모든 데이터가 삭제됩니다"
        fi
    fi
    
    print_debug "RAID용 디스크 사용 가능: $device"
    return 0
}

# 여러 디스크의 RAID 호환성 검증
validate_disks_raid_compatible() {
    local raid_level="$1"
    shift
    local disk_ids=("$@")
    
    print_debug "RAID $raid_level 호환성 검증: ${disk_ids[*]}"
    
    # 최소 디스크 수 확인
    local min_disks
    case "$raid_level" in
        0) min_disks=2 ;;
        1) min_disks=2 ;;
        5) min_disks=3 ;;
        6) min_disks=4 ;;
        10) min_disks=4 ;;
        *)
            print_error "지원하지 않는 RAID 레벨: $raid_level"
            return 1
            ;;
    esac
    
    if [[ ${#disk_ids[@]} -lt $min_disks ]]; then
        print_error "RAID $raid_level에는 최소 ${min_disks}개의 디스크가 필요합니다 (현재: ${#disk_ids[@]}개)"
        return 1
    fi
    
    # 각 디스크 개별 검증
    local devices=()
    for id in "${disk_ids[@]}"; do
        if ! validate_disk_available_for_raid "$id"; then
            return 1
        fi
        
        local device
        device=$(resolve_disk_id "$id")
        devices+=("$device")
    done
    
    # 디스크 크기 호환성 검증 (경고만)
    local sizes=()
    for device in "${devices[@]}"; do
        local size
        size=$(blockdev --getsize64 "$device" 2>/dev/null || echo "0")
        sizes+=("$size")
    done
    
    # 크기 차이 확인
    local min_size max_size
    min_size=$(printf '%s\n' "${sizes[@]}" | sort -n | head -1)
    max_size=$(printf '%s\n' "${sizes[@]}" | sort -n | tail -1)
    
    if [[ $min_size -gt 0 && $max_size -gt 0 ]]; then
        local size_diff=$(( (max_size - min_size) * 100 / max_size ))
        if [[ $size_diff -gt 10 ]]; then
            print_warning "디스크 크기 차이가 큽니다 (${size_diff}% 차이)"
            print_warning "작은 디스크 크기에 맞춰 RAID가 생성됩니다"
        fi
    fi
    
    print_success "RAID $raid_level 호환성 검증 완료"
    return 0
}

# ===================================================================================
# fstab 관련 검증 함수
# ===================================================================================

# fstab 항목 유효성 검증
validate_fstab_entry() {
    local device_id="$1"
    local mountpoint="$2"
    local fstype="$3"
    local options="${4:-defaults}"
    
    print_debug "fstab 항목 검증: $device_id → $mountpoint"
    
    # 디스크 존재 확인
    if ! validate_disk_exists "$device_id"; then
        return 1
    fi
    
    # 마운트포인트 검증
    if ! validate_mountpoint "$mountpoint"; then
        return 1
    fi
    
    # 파일시스템 타입 검증
    if ! validate_filesystem_type "$fstype"; then
        return 1
    fi
    
    # 마운트 옵션 검증
    if ! validate_mount_options "$options"; then
        return 1
    fi
    
    # fstab 중복 확인
    if ! validate_fstab_no_conflicts "$device_id" "$mountpoint"; then
        return 1
    fi
    
    print_debug "fstab 항목 검증 완료"
    return 0
}

# 마운트포인트 유효성 검증
validate_mountpoint() {
    local mountpoint="$1"
    
    # 빈 값 확인
    if [[ -z "$mountpoint" ]]; then
        print_error "마운트포인트가 지정되지 않았습니다"
        return 1
    fi
    
    # 절대 경로 확인
    if [[ "$mountpoint" != /* ]]; then
        print_error "마운트포인트는 절대 경로여야 합니다: $mountpoint"
        return 1
    fi
    
    # 예약된 경로 확인
    case "$mountpoint" in
        / | /boot | /etc | /bin | /sbin | /usr | /lib | /lib64)
            print_error "시스템 예약 경로는 사용할 수 없습니다: $mountpoint"
            return 1
            ;;
        /dev/* | /proc/* | /sys/* | /run/*)
            print_error "가상 파일시스템 경로는 사용할 수 없습니다: $mountpoint"
            return 1
            ;;
    esac
    
    # 상위 디렉토리 확인
    local parent_dir
    parent_dir=$(dirname "$mountpoint")
    if [[ ! -d "$parent_dir" ]]; then
        print_warning "상위 디렉토리가 존재하지 않습니다: $parent_dir"
        print_info "마운트 시 자동으로 생성됩니다"
    fi
    
    # 이미 마운트포인트로 사용 중인지 확인
    if mount | grep -q " $mountpoint "; then
        print_error "마운트포인트가 이미 사용 중입니다: $mountpoint"
        return 1
    fi
    
    print_debug "마운트포인트 검증 완료: $mountpoint"
    return 0
}

# 파일시스템 타입 유효성 검증
validate_filesystem_type() {
    local fstype="$1"
    
    if [[ -z "$fstype" ]]; then
        print_error "파일시스템 타입이 지정되지 않았습니다"
        return 1
    fi
    
    # 지원하는 파일시스템 타입
    local supported_fs="ext2 ext3 ext4 xfs btrfs ntfs vfat exfat swap auto"
    
    if [[ " $supported_fs " == *" $fstype "* ]]; then
        print_debug "지원하는 파일시스템: $fstype"
        return 0
    else
        print_warning "일반적이지 않은 파일시스템 타입: $fstype"
        return 0  # 경고만 하고 통과
    fi
}

# 마운트 옵션 유효성 검증
validate_mount_options() {
    local options="$1"
    
    if [[ -z "$options" ]]; then
        print_warning "마운트 옵션이 비어있습니다. 'defaults' 사용 권장"
        return 0
    fi
    
    # 잘못된 옵션 조합 확인
    if [[ "$options" == *"ro"* && "$options" == *"rw"* ]]; then
        print_error "읽기 전용(ro)과 읽기/쓰기(rw) 옵션을 동시에 사용할 수 없습니다"
        return 1
    fi
    
    # 위험한 옵션 경고
    if [[ "$options" == *"exec"* && "$options" == *"noexec"* ]]; then
        print_error "exec과 noexec 옵션을 동시에 사용할 수 없습니다"
        return 1
    fi
    
    print_debug "마운트 옵션 검증 완료: $options"
    return 0
}

# fstab 중복 및 충돌 검사
validate_fstab_no_conflicts() {
    local device_id="$1"
    local mountpoint="$2"
    
    local fstab_file="/etc/fstab"
    
    if [[ ! -f "$fstab_file" ]]; then
        print_debug "fstab 파일이 없습니다. 새로 생성됩니다"
        return 0
    fi
    
    # 디바이스를 fstab 형식으로 변환
    local device
    device=$(resolve_disk_id "$device_id")
    local fstab_device
    fstab_device=$(get_fstab_identifier "$device")
    
    # 같은 마운트포인트 확인
    if grep -q "^[^#]*[[:space:]]$mountpoint[[:space:]]" "$fstab_file"; then
        print_error "마운트포인트가 이미 fstab에 등록되어 있습니다: $mountpoint"
        return 1
    fi
    
    # 같은 디바이스 확인 (다른 형식 포함)
    local existing_entry
    existing_entry=$(grep -E "^[^#]*($device|$fstab_device|$device_id)" "$fstab_file" || true)
    if [[ -n "$existing_entry" ]]; then
        print_error "디바이스가 이미 fstab에 등록되어 있습니다:"
        echo "  $existing_entry"
        return 1
    fi
    
    print_debug "fstab 충돌 검사 완료"
    return 0
}

# ===================================================================================
# 시스템 환경 검증 함수
# ===================================================================================

# 관리자 권한 확인
validate_root_permissions() {
    if [[ $EUID -ne 0 ]]; then
        print_error "이 작업은 관리자 권한이 필요합니다"
        print_info "다음 명령어로 실행하세요: sudo $0"
        return 1
    fi
    
    print_debug "관리자 권한 확인됨"
    return 0
}

# 필수 명령어 존재 확인
validate_required_commands() {
    local commands=("$@")
    local missing_commands=()
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        print_error "다음 명령어들이 설치되어 있지 않습니다: ${missing_commands[*]}"
        return 1
    fi
    
    print_debug "필수 명령어 확인 완료: ${commands[*]}"
    return 0
}

# RAID 도구 사용 가능 확인
validate_raid_tools() {
    local required_tools=("mdadm" "parted" "mkfs.ext4")
    
    if ! validate_required_commands "${required_tools[@]}"; then
        print_error "RAID 작업에 필요한 도구가 부족합니다"
        print_info "설치하려면: sudo apt install mdadm parted e2fsprogs"
        return 1
    fi
    
    # mdadm 설정 파일 확인
    if [[ ! -f /etc/mdadm/mdadm.conf ]]; then
        print_warning "mdadm 설정 파일이 없습니다. 자동으로 생성됩니다"
    fi
    
    print_debug "RAID 도구 확인 완료"
    return 0
}

# ===================================================================================
# 종합 검증 함수
# ===================================================================================

# 디스크 관리 작업 전 전체 검증
validate_disk_operation() {
    local operation="$1"
    shift
    local disk_ids=("$@")
    
    print_header "디스크 작업 검증: $operation"
    
    # 기본 환경 확인
    validate_root_permissions || return 1
    validate_required_commands "lsblk" "blkid" "mount" "umount" || return 1
    
    # 디스크별 검증
    for id in "${disk_ids[@]}"; do
        case "$operation" in
            "mount"|"unmount"|"info")
                validate_disk_exists "$id" || return 1
                ;;
            "raid")
                validate_disk_available_for_raid "$id" || return 1
                ;;
            *)
                validate_disk_readable "$id" || return 1
                ;;
        esac
    done
    
    print_success "디스크 작업 검증 완료"
    return 0
}

# RAID 작업 전 전체 검증
validate_raid_operation() {
    local raid_level="$1"
    shift
    local disk_ids=("$@")
    
    print_header "RAID 작업 검증"
    
    # RAID 도구 확인
    validate_raid_tools || return 1
    
    # 디스크 호환성 확인
    validate_disks_raid_compatible "$raid_level" "${disk_ids[@]}" || return 1
    
    print_success "RAID 작업 검증 완료"
    return 0
}

# fstab 작업 전 전체 검증
validate_fstab_operation() {
    local device_id="$1"
    local mountpoint="$2"
    local fstype="$3"
    local options="$4"
    
    print_header "fstab 작업 검증"
    
    # 기본 환경 확인
    validate_root_permissions || return 1
    
    # fstab 항목 검증
    validate_fstab_entry "$device_id" "$mountpoint" "$fstype" "$options" || return 1
    
    print_success "fstab 작업 검증 완료"
    return 0
} 
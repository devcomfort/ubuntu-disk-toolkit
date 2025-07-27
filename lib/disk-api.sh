#!/bin/bash

# ===================================================================================
# disk-api.sh - 디스크 관리 통합 API
# ===================================================================================
#
# 이 모듈은 모든 디스크 관련 작업의 통합 인터페이스를 제공합니다.
# fstab을 변경하지 않는 임시 작업에 특화되어 있으며, 다른 모듈들이
# 디스크 정보를 조회하거나 임시 마운트 작업을 수행할 때 사용됩니다.
#
# 주요 기능:
# - ID 기반 임시 마운트/언마운트 (fstab 업데이트 없음)
# - 디스크 정보 조회 및 상태 확인
# - 사용 가능한 디스크 목록 제공 (RAID/fstab 모듈용)
# - 디스크 호환성 검사
#
# ===================================================================================

# 공통 라이브러리 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 의존성 모듈 로드
for module in "id-resolver.sh" "validator.sh" "disk-functions.sh"; do
    if [[ -f "${SCRIPT_DIR}/$module" ]]; then
        # shellcheck source=lib/id-resolver.sh
        # shellcheck source=lib/validator.sh
        # shellcheck source=lib/disk-functions.sh
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
# 임시 마운트 관리 (fstab 업데이트 없음)
# ===================================================================================

# 임시 마운트 (fstab 업데이트 없음)
disk_mount_temporary() {
    local id="$1"
    local mountpoint="$2"
    local fstype="${3:-auto}"
    local options="${4:-defaults}"
    local create_dir="${5:-true}"
    
    print_debug "임시 마운트 요청: $id → $mountpoint"
    
    # 입력 검증
    if [[ -z "$id" || -z "$mountpoint" ]]; then
        print_error "디스크 ID와 마운트포인트가 필요합니다"
        return 1
    fi
    
    # 디스크 존재 확인
    if ! validate_disk_exists "$id"; then
        return 1
    fi
    
    # 실제 디바이스 경로 획득
    local device
    device=$(resolve_disk_id "$id") || {
        print_error "디스크 ID를 해석할 수 없습니다: $id"
        return 1
    }
    
    print_info "임시 마운트 진행: $device → $mountpoint"
    
    # 마운트포인트 생성
    if [[ "$create_dir" == "true" && ! -d "$mountpoint" ]]; then
        if mkdir -p "$mountpoint"; then
            print_debug "마운트포인트 생성됨: $mountpoint"
        else
            print_error "마운트포인트 생성 실패: $mountpoint"
            return 1
        fi
    fi
    
    # 이미 마운트되어 있는지 확인
    if mount | grep -q "^$device "; then
        local current_mount
        current_mount=$(mount | grep "^$device " | awk '{print $3}')
        if [[ "$current_mount" == "$mountpoint" ]]; then
            print_info "이미 마운트되어 있습니다: $device → $mountpoint"
            return 0
        else
            print_error "디스크가 다른 위치에 마운트되어 있습니다: $current_mount"
            return 1
        fi
    fi
    
    # 마운트 실행
    if mount -t "$fstype" -o "$options" "$device" "$mountpoint"; then
        print_success "임시 마운트 완료: $device → $mountpoint"
        
        # 마운트 정보 출력
        local mount_info
        mount_info=$(mount | grep "^$device ")
        print_info "마운트 정보: $mount_info"
        
        return 0
    else
        print_error "마운트 실패: $device → $mountpoint"
        
        # 실패 시 생성한 디렉토리 정리 (비어있는 경우만)
        if [[ "$create_dir" == "true" && -d "$mountpoint" ]]; then
            rmdir "$mountpoint" 2>/dev/null && print_debug "빈 마운트포인트 제거됨: $mountpoint"
        fi
        
        return 1
    fi
}

# 임시 언마운트
disk_unmount_temporary() {
    local target="$1"  # 마운트포인트 또는 디바이스 ID
    local force="${2:-false}"
    local remove_dir="${3:-false}"
    
    print_debug "임시 언마운트 요청: $target (강제: $force)"
    
    if [[ -z "$target" ]]; then
        print_error "마운트포인트 또는 디바이스 ID가 필요합니다"
        return 1
    fi
    
    local mountpoint device
    
    # 타겟이 마운트포인트인지 디바이스 ID인지 판단
    if [[ -d "$target" ]]; then
        # 디렉토리인 경우 마운트포인트로 간주
        mountpoint="$target"
        device=$(mount | grep " $mountpoint " | awk '{print $1}')
        
        if [[ -z "$device" ]]; then
            print_error "마운트되지 않은 디렉토리입니다: $mountpoint"
            return 1
        fi
    else
        # 디렉토리가 아닌 경우 디바이스 ID로 간주
        if validate_disk_exists "$target"; then
            device=$(resolve_disk_id "$target")
            mountpoint=$(mount | grep "^$device " | awk '{print $3}')
            
            if [[ -z "$mountpoint" ]]; then
                print_error "마운트되지 않은 디바이스입니다: $device"
                return 1
            fi
        else
            print_error "유효하지 않은 타겟입니다: $target"
            return 1
        fi
    fi
    
    print_info "임시 언마운트 진행: $device ($mountpoint)"
    
    # 언마운트 실행
    local umount_cmd="umount"
    [[ "$force" == "true" ]] && umount_cmd="umount -f"
    
    if $umount_cmd "$mountpoint"; then
        print_success "임시 언마운트 완료: $mountpoint"
        
        # 마운트포인트 디렉토리 제거 (요청된 경우)
        if [[ "$remove_dir" == "true" && -d "$mountpoint" ]]; then
            if rmdir "$mountpoint" 2>/dev/null; then
                print_info "마운트포인트 디렉토리 제거됨: $mountpoint"
            else
                print_warning "마운트포인트 디렉토리를 제거할 수 없습니다 (비어있지 않음): $mountpoint"
            fi
        fi
        
        return 0
    else
        print_error "언마운트 실패: $mountpoint"
        
        if [[ "$force" != "true" ]]; then
            print_info "강제 언마운트를 시도해보세요: disk_unmount_temporary \"$target\" true"
        fi
        
        return 1
    fi
}

# 현재 마운트된 디스크 목록 조회
disk_list_mounted() {
    local filter_pattern="${1:-}"
    local format="${2:-table}"  # table, simple, detailed
    
    print_debug "마운트된 디스크 목록 조회 (필터: ${filter_pattern:-없음})"
    
    case "$format" in
        "table")
            print_header "현재 마운트된 디스크"
            echo ""
            printf "%-20s %-30s %-10s %-20s\n" "DEVICE" "MOUNTPOINT" "FSTYPE" "OPTIONS"
            printf "%-20s %-30s %-10s %-20s\n" "--------------------" "------------------------------" "----------" "--------------------"
            ;;
        "simple")
            # 간단한 형식 (스크립트용)
            ;;
        "detailed")
            print_header "마운트된 디스크 상세 정보"
            echo ""
            ;;
    esac
    
    local count=0
    while IFS= read -r line; do
        # 가상 파일시스템 제외
        [[ "$line" =~ ^(proc|sysfs|devpts|tmpfs|devtmpfs|cgroup|pstore|bpf|tracefs|debugfs|hugetlbfs|mqueue|fusectl|configfs|securityfs) ]] && continue
        
        # mount 출력 파싱: "/dev/device on /mountpoint type fstype (options)"
        local device mountpoint fstype options
        
        # 더 간단한 파싱 방법
        device=$(echo "$line" | cut -d' ' -f1)
        mountpoint=$(echo "$line" | sed 's/^[^ ]* on \([^ ]*\) type.*/\1/')
        fstype=$(echo "$line" | sed 's/.* type \([^ ]*\) .*/\1/')
        options=$(echo "$line" | sed 's/.*(\([^)]*\)).*/\1/')
        
        # 빈 값 체크
        [[ -z "$device" || -z "$mountpoint" || -z "$fstype" ]] && continue
        
        # 필터 적용
        if [[ -n "$filter_pattern" ]]; then
            if [[ ! "$device" =~ $filter_pattern && ! "$mountpoint" =~ $filter_pattern ]]; then
                continue
            fi
        fi
        
        count=$((count + 1))
        
        case "$format" in
            "table")
                # 옵션이 너무 길면 자르기
                local short_options="${options:0:18}"
                [[ ${#options} -gt 18 ]] && short_options="${short_options}..."
                
                printf "%-20s %-30s %-10s %-20s\n" \
                    "${device:0:19}" \
                    "${mountpoint:0:29}" \
                    "${fstype:0:9}" \
                    "$short_options"
                ;;
            "simple")
                echo "$device:$mountpoint:$fstype"
                ;;
            "detailed")
                print_info "디바이스: $device"
                echo "  마운트포인트: $mountpoint"
                echo "  파일시스템: $fstype"
                echo "  옵션: $options"
                
                # 추가 정보
                local uuid label
                uuid=$(get_device_uuid "$device" 2>/dev/null || echo "N/A")
                label=$(get_device_label "$device" 2>/dev/null || echo "N/A")
                echo "  UUID: $uuid"
                echo "  LABEL: $label"
                echo ""
                ;;
        esac
        
    done < <(mount | grep "^/dev/" | sort)
    
    if [[ $count -eq 0 ]]; then
        case "$format" in
            "table")
                echo "마운트된 디스크가 없습니다."
                ;;
        esac
    fi
}

# ===================================================================================
# 디스크 정보 조회 (ID 기반)
# ===================================================================================

# 디스크 정보 조회 (ID 기반)
disk_get_info() {
    local id="$1"
    local format="${2:-detailed}"  # detailed, simple, json
    local include_mount="${3:-true}"
    
    print_debug "디스크 정보 조회: $id"
    
    # 디스크 존재 확인
    if ! validate_disk_exists "$id"; then
        return 1
    fi
    
    # 실제 디바이스 경로 획득
    local device
    device=$(resolve_disk_id "$id") || return 1
    
    # 기본 정보 수집
    local size uuid partuuid label fstype
    size=$(lsblk -n -o SIZE "$device" 2>/dev/null | head -1 | xargs)
    uuid=$(get_device_uuid "$device" 2>/dev/null || echo "")
    partuuid=$(get_device_partuuid "$device" 2>/dev/null || echo "")
    label=$(get_device_label "$device" 2>/dev/null || echo "")
    fstype=$(lsblk -n -o FSTYPE "$device" 2>/dev/null | head -1 | xargs)
    
    # 마운트 정보
    local is_mounted=false
    local mountpoint=""
    local mount_options=""
    if [[ "$include_mount" == "true" ]]; then
        local mount_info
        mount_info=$(mount | grep "^$device " || true)
        if [[ -n "$mount_info" ]]; then
            is_mounted=true
            mountpoint=$(echo "$mount_info" | awk '{print $3}')
            mount_options=$(echo "$mount_info" | sed 's/.*(\(.*\)).*/\1/')
        fi
    fi
    
    # 형식에 따른 출력
    case "$format" in
        "detailed")
            print_header "디스크 정보: $id"
            echo ""
            echo "기본 정보:"
            echo "  디바이스: $device"
            echo "  크기: ${size:-N/A}"
            echo "  파일시스템: ${fstype:-N/A}"
            echo ""
            echo "식별자:"
            echo "  UUID: ${uuid:-N/A}"
            echo "  PARTUUID: ${partuuid:-N/A}"
            echo "  LABEL: ${label:-N/A}"
            
            if [[ "$include_mount" == "true" ]]; then
                echo ""
                echo "마운트 상태:"
                if [[ $is_mounted == true ]]; then
                    echo "  상태: ✅ 마운트됨"
                    echo "  마운트포인트: $mountpoint"
                    echo "  마운트 옵션: $mount_options"
                else
                    echo "  상태: ❌ 언마운트됨"
                fi
            fi
            ;;
        "simple")
            echo "$device:${size:-}:${fstype:-}:${uuid:-}:$is_mounted:${mountpoint:-}"
            ;;
        "json")
            cat << EOF
{
  "device": "$device",
  "size": "${size:-}",
  "fstype": "${fstype:-}",
  "uuid": "${uuid:-}",
  "partuuid": "${partuuid:-}",
  "label": "${label:-}",
  "mounted": $is_mounted,
  "mountpoint": "${mountpoint:-}",
  "mount_options": "${mount_options:-}"
}
EOF
            ;;
        *)
            print_error "지원하지 않는 형식: $format"
            return 1
            ;;
    esac
    
    return 0
}

# 여러 디스크 정보 일괄 조회
disk_get_multiple_info() {
    local format="${1:-table}"
    shift
    local disk_ids=("$@")
    
    if [[ ${#disk_ids[@]} -eq 0 ]]; then
        print_error "조회할 디스크 ID가 지정되지 않았습니다"
        return 1
    fi
    
    case "$format" in
        "table")
            print_header "디스크 정보 목록"
            echo ""
            printf "%-15s %-20s %-8s %-10s %-12s %-20s\n" "ID" "DEVICE" "SIZE" "FSTYPE" "MOUNTED" "MOUNTPOINT"
            printf "%-15s %-20s %-8s %-10s %-12s %-20s\n" "---------------" "--------------------" "--------" "----------" "------------" "--------------------"
            
            for id in "${disk_ids[@]}"; do
                if validate_disk_exists "$id" 2>/dev/null; then
                    local info
                    info=$(disk_get_info "$id" "simple")
                    IFS=':' read -r device size fstype uuid mounted mountpoint <<< "$info"
                    
                    local mounted_status="❌ No"
                    [[ "$mounted" == "true" ]] && mounted_status="✅ Yes"
                    
                    printf "%-15s %-20s %-8s %-10s %-12s %-20s\n" \
                        "${id:0:14}" \
                        "${device:0:19}" \
                        "${size:0:7}" \
                        "${fstype:0:9}" \
                        "$mounted_status" \
                        "${mountpoint:0:19}"
                else
                    printf "%-15s %-20s %-8s %-10s %-12s %-20s\n" \
                        "${id:0:14}" \
                        "ERROR" \
                        "-" \
                        "-" \
                        "-" \
                        "-"
                fi
            done
            ;;
        "simple")
            for id in "${disk_ids[@]}"; do
                if validate_disk_exists "$id" 2>/dev/null; then
                    disk_get_info "$id" "simple"
                fi
            done
            ;;
        *)
            print_error "지원하지 않는 형식: $format"
            return 1
            ;;
    esac
}

# ===================================================================================
# 사용 가능한 디스크 목록 (다른 모듈용)
# ===================================================================================

# 마운트되지 않은 디스크 목록
disk_list_unmounted() {
    local format="${1:-simple}"
    local include_partitions="${2:-true}"
    
    print_debug "언마운트된 디스크 목록 조회"
    
    local devices=()
    
    # 모든 블록 디바이스 조회
    local all_devices
    if [[ "$include_partitions" == "true" ]]; then
        all_devices=$(lsblk -n -o NAME,TYPE | awk '$2=="disk" || $2=="part" {print "/dev/"$1}')
    else
        all_devices=$(lsblk -n -o NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}')
    fi
    
    while IFS= read -r device; do
        [[ -b "$device" ]] || continue
        
        # 디스크 사용 여부 종합 검사
        if _is_disk_unused "$device"; then
            devices+=("$device")
        fi
    done <<< "$all_devices"
    
    case "$format" in
        "simple")
            printf '%s\n' "${devices[@]}"
            ;;
        "table")
            if [[ ${#devices[@]} -eq 0 ]]; then
                print_info "마운트되지 않은 디스크가 없습니다"
                return 0
            fi
            
            print_header "마운트되지 않은 디스크 목록"
            echo ""
            printf "%-20s %-8s %-10s %-36s\n" "DEVICE" "SIZE" "FSTYPE" "UUID"
            printf "%-20s %-8s %-10s %-36s\n" "--------------------" "--------" "----------" "------------------------------------"
            
            for device in "${devices[@]}"; do
                local size fstype uuid
                size=$(lsblk -n -o SIZE "$device" 2>/dev/null | head -1 | xargs || echo "-")
                fstype=$(lsblk -n -o FSTYPE "$device" 2>/dev/null | head -1 | xargs || echo "-")
                uuid=$(get_device_uuid "$device" 2>/dev/null || echo "-")
                
                printf "%-20s %-8s %-10s %-36s\n" \
                    "${device:0:19}" \
                    "${size:0:7}" \
                    "${fstype:0:9}" \
                    "${uuid:0:35}"
            done
            ;;
        *)
            print_error "지원하지 않는 형식: $format"
            return 1
            ;;
    esac
}

# 디스크가 실제로 사용되지 않는지 확인하는 내부 함수
_is_disk_unused() {
    local device="$1"
    
    # 1. 직접 마운트 확인
    if mount | grep -q "^$device "; then
        return 1  # 사용 중
    fi
    
    # 2. 파티션들이 마운트되어 있거나 사용 중인지 확인 (전체 디스크인 경우)
    if [[ "$device" =~ /dev/sd[a-z]$ ]] || [[ "$device" =~ /dev/nvme[0-9]+n[0-9]+$ ]]; then
        # 해당 디스크의 파티션들 확인 - 더 안전한 방법
        local partitions
        partitions=$(lsblk -n -o NAME "$device" | grep -v "^$(basename "$device")$")
        
        while IFS= read -r partition_line; do
            [[ -z "$partition_line" ]] && continue
            
            # lsblk 출력에서 파티션 이름만 추출 (├─, └─ 등 제거)
            local partition
            partition=$(echo "$partition_line" | sed 's/^[[:space:]]*[├└]─//' | sed 's/^[[:space:]]*//')
            [[ -z "$partition" ]] && continue
            
            local part_device="/dev/$partition"
            
            # 파티션이 마운트되어 있으면 디스크는 사용 중
            if mount | grep -q "^$part_device "; then
                return 1  # 사용 중
            fi
            
            # LVM 체크
            if lsblk -n -o TYPE "$part_device" 2>/dev/null | grep -q "lvm"; then
                return 1  # LVM으로 사용 중
            fi
            
            # RAID 체크 (TYPE으로 확인)
            if lsblk -n -o TYPE "$part_device" 2>/dev/null | grep -q "raid"; then
                return 1  # RAID로 사용 중
            fi
            
            # mdadm으로 RAID 멤버 확인
            if command -v mdadm >/dev/null 2>&1; then
                if mdadm --examine "$part_device" >/dev/null 2>&1; then
                    return 1  # RAID 멤버로 사용 중
                fi
            fi
            
        done <<< "$partitions"
    fi
    
    # 3. /proc/mdstat에서 RAID 멤버 확인
    if [[ -f /proc/mdstat ]]; then
        local basename_device
        basename_device=$(basename "$device")
        if grep -q "$basename_device" /proc/mdstat 2>/dev/null; then
            return 1  # RAID 멤버로 사용 중
        fi
    fi
    
    # 4. LVM Physical Volume인지 확인
    if command -v pvs >/dev/null 2>&1; then
        if pvs "$device" >/dev/null 2>&1; then
            return 1  # LVM PV로 사용 중
        fi
    fi
    
    # 5. 파티션 테이블이 있는지 확인
    if command -v parted >/dev/null 2>&1; then
        local partition_count
        partition_count=$(lsblk -n "$device" | wc -l)
        if [[ $partition_count -gt 1 ]]; then
            return 1  # 파티션이 있으므로 사용 중
        fi
    fi
    
    return 0  # 실제로 사용되지 않음
}

# RAID에 사용 가능한 디스크 목록 (validator 활용)
disk_list_available_for_raid() {
    local format="${1:-simple}"
    
    print_debug "RAID 사용 가능 디스크 목록 조회"
    
    local available_devices=()
    
    # 모든 언마운트된 디스크 검사
    local unmounted_devices
    unmounted_devices=$(disk_list_unmounted "simple")
    
    while IFS= read -r device; do
        [[ -n "$device" ]] || continue
        
        # RAID 사용 가능성 검증
        if validate_disk_available_for_raid "$device" 2>/dev/null; then
            available_devices+=("$device")
        fi
    done <<< "$unmounted_devices"
    
    case "$format" in
        "simple")
            printf '%s\n' "${available_devices[@]}"
            ;;
        "table")
            if [[ ${#available_devices[@]} -eq 0 ]]; then
                print_info "RAID에 사용 가능한 디스크가 없습니다"
                return 0
            fi
            
            print_header "RAID 사용 가능한 디스크 목록"
            echo ""
            printf "%-20s %-8s %-10s %-36s\n" "DEVICE" "SIZE" "TYPE" "STATUS"
            printf "%-20s %-8s %-10s %-36s\n" "--------------------" "--------" "----------" "------------------------------------"
            
            for device in "${available_devices[@]}"; do
                local size fstype status
                size=$(lsblk -n -o SIZE "$device" 2>/dev/null | head -1 | xargs || echo "-")
                fstype=$(lsblk -n -o FSTYPE "$device" 2>/dev/null | head -1 | xargs || echo "empty")
                
                # 상태 결정
                if [[ -z "$fstype" || "$fstype" == "-" ]]; then
                    status="✅ 사용 가능 (빈 디스크)"
                else
                    status="⚠️  사용 가능 (데이터 삭제됨)"
                fi
                
                printf "%-20s %-8s %-10s %-36s\n" \
                    "${device:0:19}" \
                    "${size:0:7}" \
                    "${fstype:0:9}" \
                    "${status:0:35}"
            done
            ;;
        *)
            print_error "지원하지 않는 형식: $format"
            return 1
            ;;
    esac
}

# ===================================================================================
# 디스크 호환성 및 권장사항
# ===================================================================================

# 디스크 호환성 검사
disk_check_compatibility() {
    local primary_id="$1"
    shift
    local secondary_ids=("$@")
    
    print_header "디스크 호환성 검사"
    
    # 기준 디스크 정보
    if ! validate_disk_exists "$primary_id"; then
        return 1
    fi
    
    local primary_device
    primary_device=$(resolve_disk_id "$primary_id")
    local primary_size
    primary_size=$(blockdev --getsize64 "$primary_device" 2>/dev/null || echo "0")
    
    print_info "기준 디스크: $primary_device (크기: $(numfmt --to=iec "$primary_size" 2>/dev/null || echo "unknown"))"
    echo ""
    
    local compatible_count=0
    local total_count=${#secondary_ids[@]}
    
    for id in "${secondary_ids[@]}"; do
        echo -n "검사 중: $id ... "
        
        if ! validate_disk_exists "$id" 2>/dev/null; then
            echo "❌ 존재하지 않음"
            continue
        fi
        
        local device
        device=$(resolve_disk_id "$id")
        local size
        size=$(blockdev --getsize64 "$device" 2>/dev/null || echo "0")
        
        # 크기 차이 계산
        if [[ $primary_size -gt 0 && $size -gt 0 ]]; then
            local size_diff
            if [[ $size -gt $primary_size ]]; then
                size_diff=$(( (size - primary_size) * 100 / size ))
            else
                size_diff=$(( (primary_size - size) * 100 / primary_size ))
            fi
            
            if [[ $size_diff -le 5 ]]; then
                echo "✅ 호환 (크기 차이: ${size_diff}%)"
                ((compatible_count++))
            elif [[ $size_diff -le 15 ]]; then
                echo "⚠️  주의 (크기 차이: ${size_diff}%)"
                ((compatible_count++))
            else
                echo "❌ 비호환 (크기 차이: ${size_diff}%)"
            fi
        else
            echo "❌ 크기 정보 없음"
        fi
    done
    
    echo ""
    print_info "호환성 검사 결과: ${compatible_count}/${total_count} 호환"
    
    if [[ $compatible_count -eq $total_count ]]; then
        print_success "모든 디스크가 호환됩니다"
        return 0
    else
        print_warning "일부 디스크가 호환되지 않습니다"
        return 1
    fi
}

# 디스크 사용 권장사항
disk_get_recommendations() {
    local context="${1:-general}"  # general, raid, backup
    local min_size="${2:-}"
    
    print_header "디스크 사용 권장사항"
    
    case "$context" in
        "raid")
            echo "RAID 구성을 위한 권장사항:"
            echo ""
            echo "✅ 권장사항:"
            echo "  • 동일한 크기의 디스크 사용"
            echo "  • 동일한 제조사/모델 사용 (성능 일관성)"
            echo "  • SSD의 경우 동일한 웨어 레벨링 알고리즘"
            echo "  • 최소 2개 이상의 디스크 (RAID 레벨에 따라)"
            echo ""
            echo "⚠️  주의사항:"
            echo "  • 서로 다른 크기 디스크 사용 시 작은 크기에 맞춰짐"
            echo "  • 기존 데이터는 모두 삭제됨"
            echo "  • RAID 0은 하나라도 실패 시 전체 데이터 손실"
            ;;
        "backup")
            echo "백업용 디스크 권장사항:"
            echo ""
            echo "✅ 권장사항:"
            echo "  • 원본 데이터보다 최소 2배 이상 큰 용량"
            echo "  • 신뢰성 높은 디스크 사용"
            echo "  • 정기적인 디스크 상태 검사"
            echo ""
            echo "⚠️  주의사항:"
            echo "  • 백업 디스크도 실패할 수 있음 (다중 백업 권장)"
            echo "  • 암호화 고려 (민감한 데이터)"
            ;;
        *)
            echo "일반 디스크 사용 권장사항:"
            echo ""
            echo "✅ 권장사항:"
            echo "  • 용도에 맞는 파일시스템 선택 (ext4, xfs, btrfs)"
            echo "  • 적절한 마운트 옵션 설정"
            echo "  • 정기적인 백업"
            echo ""
            echo "⚠️  주의사항:"
            echo "  • 시스템 디스크와 데이터 디스크 분리"
            echo "  • 중요한 데이터는 반드시 백업"
            ;;
    esac
    
    # 최소 크기 요구사항이 있는 경우
    if [[ -n "$min_size" ]]; then
        echo ""
        print_info "최소 크기 요구사항: $min_size"
        
        # 조건에 맞는 디스크 찾기
        local suitable_disks=()
        local min_bytes
        min_bytes=$(numfmt --from=iec "$min_size" 2>/dev/null || echo "0")
        
        if [[ $min_bytes -gt 0 ]]; then
            local unmounted
            unmounted=$(disk_list_unmounted "simple")
            
            while IFS= read -r device; do
                [[ -n "$device" ]] || continue
                
                local size_bytes
                size_bytes=$(blockdev --getsize64 "$device" 2>/dev/null || echo "0")
                
                if [[ $size_bytes -ge $min_bytes ]]; then
                    suitable_disks+=("$device")
                fi
            done <<< "$unmounted"
            
            if [[ ${#suitable_disks[@]} -gt 0 ]]; then
                echo ""
                print_success "조건에 맞는 사용 가능한 디스크:"
                for disk in "${suitable_disks[@]}"; do
                    local size
                    size=$(lsblk -n -o SIZE "$disk" 2>/dev/null | head -1 | xargs)
                    echo "  • $disk ($size)"
                done
            else
                echo ""
                print_warning "조건에 맞는 사용 가능한 디스크가 없습니다"
            fi
        fi
    fi
} 
#!/bin/bash

# ===================================================================================
# id-resolver.sh - ID 기반 디스크 해석 시스템
# ===================================================================================
# 
# 이 모듈은 다양한 형태의 디스크 식별자를 실제 디바이스 경로로 변환하거나
# 그 반대 작업을 수행하는 핵심 유틸리티입니다.
#
# 지원하는 ID 형식:
# - UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# - PARTUUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  
# - LABEL=my-disk-label
# - /dev/sdX (직접 디바이스 경로)
# - sdX (디바이스명만)
#
# ===================================================================================

# 공통 라이브러리 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${RED:-}" ]]; then
    # shellcheck source=lib/common.sh
    source "${SCRIPT_DIR}/common.sh"
fi

# ===================================================================================
# ID 타입별 해석 함수
# ===================================================================================

# UUID를 디바이스로 변환
resolve_by_uuid() {
    local uuid="$1"
    
    if [[ -z "$uuid" ]]; then
        print_debug "UUID가 비어있습니다"
        return 1
    fi
    
    local uuid_path="/dev/disk/by-uuid/$uuid"
    if [[ -L "$uuid_path" ]]; then
        readlink -f "$uuid_path"
        return 0
    else
        print_debug "UUID를 찾을 수 없습니다: $uuid"
        return 1
    fi
}

# PARTUUID를 디바이스로 변환  
resolve_by_partuuid() {
    local partuuid="$1"
    
    if [[ -z "$partuuid" ]]; then
        print_debug "PARTUUID가 비어있습니다"
        return 1
    fi
    
    local partuuid_path="/dev/disk/by-partuuid/$partuuid"
    if [[ -L "$partuuid_path" ]]; then
        readlink -f "$partuuid_path"
        return 0
    else
        print_debug "PARTUUID를 찾을 수 없습니다: $partuuid"
        return 1
    fi
}

# LABEL을 디바이스로 변환
resolve_by_label() {
    local label="$1"
    
    if [[ -z "$label" ]]; then
        print_debug "LABEL이 비어있습니다"
        return 1
    fi
    
    local label_path="/dev/disk/by-label/$label"
    if [[ -L "$label_path" ]]; then
        readlink -f "$label_path"
        return 0
    else
        print_debug "LABEL을 찾을 수 없습니다: $label"
        return 1
    fi
}

# ===================================================================================
# 통합 ID 해석 함수 (메인 함수)
# ===================================================================================

# 다양한 ID 형식을 실제 디바이스 경로로 변환
resolve_disk_id() {
    local id="$1"
    
    if [[ -z "$id" ]]; then
        print_debug "디스크 ID가 비어있습니다"
        return 1
    fi
    
    print_debug "디스크 ID 해석 중: $id"
    
    case "$id" in
        UUID=*)
            resolve_by_uuid "${id#UUID=}"
            return $?
            ;;
        PARTUUID=*)
            resolve_by_partuuid "${id#PARTUUID=}"
            return $?
            ;;
        LABEL=*)
            resolve_by_label "${id#LABEL=}"
            return $?
            ;;
        /dev/*)
            # 이미 디바이스 경로인 경우 존재 확인만
            if [[ -b "$id" ]]; then
                echo "$id"
                return 0
            else
                print_debug "디바이스가 존재하지 않습니다: $id"
                return 1
            fi
            ;;
        *)
            # 디바이스명만 있는 경우 (/dev/ 추가)
            local device="/dev/$id"
            if [[ -b "$device" ]]; then
                echo "$device"
                return 0
            else
                print_debug "디바이스가 존재하지 않습니다: $device"
                return 1
            fi
            ;;
    esac
}

# ===================================================================================
# 역방향 변환 함수 (디바이스 → ID)
# ===================================================================================

# 디바이스에서 UUID 추출
get_device_uuid() {
    local device="$1"
    
    if [[ ! -b "$device" ]]; then
        print_debug "디바이스가 존재하지 않습니다: $device"
        return 1
    fi
    
    local uuid
    uuid=$(blkid -s UUID -o value "$device" 2>/dev/null)
    
    if [[ -n "$uuid" ]]; then
        echo "$uuid"
        return 0
    else
        print_debug "UUID를 가져올 수 없습니다: $device"
        return 1
    fi
}

# 디바이스에서 PARTUUID 추출
get_device_partuuid() {
    local device="$1"
    
    if [[ ! -b "$device" ]]; then
        print_debug "디바이스가 존재하지 않습니다: $device"
        return 1
    fi
    
    local partuuid
    partuuid=$(blkid -s PARTUUID -o value "$device" 2>/dev/null)
    
    if [[ -n "$partuuid" ]]; then
        echo "$partuuid"
        return 0
    else
        print_debug "PARTUUID를 가져올 수 없습니다: $device"
        return 1
    fi
}

# 디바이스에서 LABEL 추출
get_device_label() {
    local device="$1"
    
    if [[ ! -b "$device" ]]; then
        print_debug "디바이스가 존재하지 않습니다: $device"
        return 1
    fi
    
    local label
    label=$(blkid -s LABEL -o value "$device" 2>/dev/null)
    
    if [[ -n "$label" ]]; then
        echo "$label"
        return 0
    else
        print_debug "LABEL을 가져올 수 없습니다: $device"
        return 1
    fi
}

# ===================================================================================
# 유틸리티 함수
# ===================================================================================

# 디바이스의 모든 ID 정보 조회
get_device_all_ids() {
    local device="$1"
    
    if [[ ! -b "$device" ]]; then
        print_error "디바이스가 존재하지 않습니다: $device"
        return 1
    fi
    
    print_info "디바이스 ID 정보: $device"
    
    local uuid partuuid label
    uuid=$(get_device_uuid "$device" 2>/dev/null)
    partuuid=$(get_device_partuuid "$device" 2>/dev/null)
    label=$(get_device_label "$device" 2>/dev/null)
    
    echo "Device: $device"
    [[ -n "$uuid" ]] && echo "UUID: $uuid"
    [[ -n "$partuuid" ]] && echo "PARTUUID: $partuuid"
    [[ -n "$label" ]] && echo "LABEL: $label"
    
    # 적어도 하나의 ID가 있으면 성공
    [[ -n "$uuid" || -n "$partuuid" || -n "$label" ]]
}

# ID가 유효한 형식인지 검증
validate_id_format() {
    local id="$1"
    
    case "$id" in
        UUID=*)
            local uuid="${id#UUID=}"
            # UUID 형식 검증 (8-4-4-4-12)
            [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
            ;;
        PARTUUID=*)
            local partuuid="${id#PARTUUID=}"
            # PARTUUID 형식 검증 (8-4-4-4-12)
            [[ "$partuuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
            ;;
        LABEL=*)
            local label="${id#LABEL=}"
            # LABEL은 비어있지 않고 특수문자 제한
            [[ -n "$label" && ! "$label" =~ [[:space:]/] ]]
            ;;
        /dev/*)
            # 디바이스 경로 형식 검증
            [[ "$id" =~ ^/dev/[a-zA-Z0-9]+$ ]]
            ;;
        *)
            # 디바이스명 형식 검증
            [[ "$id" =~ ^[a-zA-Z0-9]+$ ]]
            ;;
    esac
}

# ID에서 fstab에 사용할 최적의 형식 반환 (UUID 우선)
get_fstab_identifier() {
    local device="$1"
    
    if [[ ! -b "$device" ]]; then
        print_debug "디바이스가 존재하지 않습니다: $device"
        echo "$device"  # fallback
        return 1
    fi
    
    # UUID가 있으면 UUID 사용 (가장 안정적)
    local uuid
    uuid=$(get_device_uuid "$device" 2>/dev/null)
    if [[ -n "$uuid" ]]; then
        echo "UUID=$uuid"
        return 0
    fi
    
    # UUID가 없으면 PARTUUID 사용
    local partuuid
    partuuid=$(get_device_partuuid "$device" 2>/dev/null)
    if [[ -n "$partuuid" ]]; then
        echo "PARTUUID=$partuuid"
        return 0
    fi
    
    # 둘 다 없으면 디바이스 경로 사용 (fallback)
    echo "$device"
    return 1
}

# ===================================================================================
# 테스트 및 진단 함수
# ===================================================================================

# ID 해석 테스트
test_id_resolution() {
    local id="$1"
    
    print_header "ID 해석 테스트: $id"
    
    # 형식 검증
    if validate_id_format "$id"; then
        print_success "ID 형식이 유효합니다"
    else
        print_error "ID 형식이 유효하지 않습니다"
        return 1
    fi
    
    # 해석 시도
    local device
    if device=$(resolve_disk_id "$id"); then
        print_success "해석 성공: $id → $device"
        
        # 디바이스 존재 확인
        if [[ -b "$device" ]]; then
            print_success "디바이스 존재 확인됨: $device"
            
            # 역방향 확인
            get_device_all_ids "$device"
        else
            print_error "디바이스가 존재하지 않습니다: $device"
            return 1
        fi
    else
        print_error "해석 실패: $id"
        return 1
    fi
}

# 시스템의 모든 디스크 ID 조회
list_all_disk_ids() {
    print_header "시스템 디스크 ID 목록"
    
    # 모든 블록 디바이스 조회
    local devices
    devices=$(lsblk -n -o NAME,TYPE | awk '$2=="disk" || $2=="part" {print "/dev/"$1}')
    
    if [[ -z "$devices" ]]; then
        print_info "디스크를 찾을 수 없습니다"
        return 0
    fi
    
    while IFS= read -r device; do
        [[ -b "$device" ]] || continue
        
        echo ""
        print_info "디바이스: $device"
        get_device_all_ids "$device" | grep -E "^(UUID|PARTUUID|LABEL):" | sed 's/^/  /'
        
    done <<< "$devices"
} 
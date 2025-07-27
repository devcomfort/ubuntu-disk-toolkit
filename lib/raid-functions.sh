#!/bin/bash

# ===================================================================================
# raid-functions.sh - RAID 관련 함수 라이브러리
# ===================================================================================

# 공통 라이브러리 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=lib/disk-functions.sh
source "${SCRIPT_DIR}/disk-functions.sh"

# ===================================================================================
# RAID 탐지 및 정보 수집
# ===================================================================================

# 현재 RAID 배열 목록 가져오기
get_raid_arrays() {
    if [[ -f /proc/mdstat ]] && [[ -s /proc/mdstat ]]; then
        awk '/^md/ {print "/dev/"$1}' /proc/mdstat
    fi
}

# RAID 배열 상태 확인
get_raid_status() {
    local raid_device="$1"
    
    if [[ ! -b "$raid_device" ]]; then
        print_error "RAID 디바이스를 찾을 수 없습니다: $raid_device"
        return 1
    fi
    
    mdadm --detail "$raid_device" 2>/dev/null
}

# RAID 레벨 확인
get_raid_level() {
    local raid_device="$1"
    
    get_raid_status "$raid_device" | awk '/Raid Level/ {print $4}'
}

# RAID 구성 디스크 목록
get_raid_devices() {
    local raid_device="$1"
    
    get_raid_status "$raid_device" | awk '/\/dev\// {print $NF}' | grep '^/dev/'
}

# RAID 상태 요약
get_raid_summary() {
    local raid_device="$1"
    local status_output
    
    status_output=$(get_raid_status "$raid_device")
    
    local state=$(echo "$status_output" | awk '/State/ {for(i=3;i<=NF;i++) printf "%s ", $i; print ""}')
    local level=$(echo "$status_output" | awk '/Raid Level/ {print $4}')
    local size=$(echo "$status_output" | awk '/Array Size/ {print $4, $5}')
    local active=$(echo "$status_output" | awk '/Active Devices/ {print $4}')
    local failed=$(echo "$status_output" | awk '/Failed Devices/ {print $4}')
    
    echo "Level: $level"
    echo "State: $state"
    echo "Size: $size"
    echo "Active: $active"
    echo "Failed: $failed"
}

# ===================================================================================
# RAID 생성 함수
# ===================================================================================

# RAID 배열 생성
create_raid() {
    local raid_level="$1"
    shift
    local disks=("$@")
    local mount_point=""
    local filesystem="ext4"
    
    # 마운트 포인트와 파일시스템이 마지막 인수들일 수 있음
    if [[ ${#disks[@]} -gt 2 ]]; then
        # 마지막 두 인수가 마운트 포인트와 파일시스템일 가능성 확인
        local last_arg="${disks[-1]}"
        local second_last_arg="${disks[-2]}"
        
        if [[ "$last_arg" =~ ^(ext[234]|xfs|btrfs)$ ]]; then
            filesystem="$last_arg"
            unset 'disks[-1]'
            
            if [[ "$second_last_arg" =~ ^/ ]]; then
                mount_point="$second_last_arg"
                unset 'disks[-1]'
            fi
        elif [[ "$last_arg" =~ ^/ ]]; then
            mount_point="$last_arg"
            unset 'disks[-1]'
        fi
    fi
    
    print_info "RAID $raid_level 생성 시작..."
    print_debug "디스크: ${disks[*]}"
    print_debug "마운트 포인트: $mount_point"
    print_debug "파일시스템: $filesystem"
    
    # RAID 레벨 검증
    if ! validate_raid_level "$raid_level" "${#disks[@]}"; then
        return 1
    fi
    
    # 다음 사용 가능한 md 디바이스 찾기
    local md_device
    md_device=$(get_next_md_device)
    print_info "RAID 디바이스: $md_device"
    
    # 디스크 준비
    if ! prepare_disks_for_raid "${disks[@]}"; then
        print_error "디스크 준비 실패"
        return 1
    fi
    
    # RAID 배열 생성
    local mdadm_cmd="mdadm --create $md_device --level=$raid_level --raid-devices=${#disks[@]}"
    
    # RAID 레벨별 추가 옵션
    case "$raid_level" in
        5|6)
            mdadm_cmd+=" --chunk=${DEFAULT_CHUNK_SIZE:-64K}"
            ;;
    esac
    
    mdadm_cmd+=" ${disks[*]}"
    
    print_info "RAID 배열 생성 중..."
    print_debug "실행: $mdadm_cmd"
    
    if safe_execute "$mdadm_cmd"; then
        print_success "RAID 배열 생성 완료: $md_device"
    else
        print_error "RAID 배열 생성 실패"
        return 1
    fi
    
    # 동기화 대기 (선택적)
    if confirm_action "RAID 초기 동기화를 기다리시겠습니까?"; then
        wait_for_raid_sync "$md_device"
    fi
    
    # 파일시스템 생성
    if create_filesystem "$md_device" "$filesystem"; then
        print_success "파일시스템 생성 완료: $filesystem"
    else
        print_warning "파일시스템 생성 실패"
    fi
    
    # 마운트 (옵션)
    if [[ -n "$mount_point" ]]; then
        if mount_raid "$md_device" "$mount_point"; then
            print_success "RAID $md_device를 $mount_point에 마운트했습니다"
        else
            print_warning "마운트 실패"
        fi
    fi
    
    # mdadm.conf 업데이트
    update_mdadm_conf
    
    print_success "RAID $raid_level 설정 완료!"
    return 0
}

# ===================================================================================
# RAID 검증 및 유틸리티
# ===================================================================================

# RAID 레벨 유효성 검사
validate_raid_level() {
    local level="$1"
    local disk_count="$2"
    
    case "$level" in
        0)
            if [[ $disk_count -lt 2 ]]; then
                print_error "RAID 0은 최소 2개의 디스크가 필요합니다"
                return 1
            fi
            ;;
        1)
            if [[ $disk_count -lt 2 ]]; then
                print_error "RAID 1은 최소 2개의 디스크가 필요합니다"
                return 1
            fi
            if [[ $((disk_count % 2)) -ne 0 ]]; then
                print_warning "RAID 1은 짝수 개의 디스크를 권장합니다"
            fi
            ;;
        5)
            if [[ $disk_count -lt 3 ]]; then
                print_error "RAID 5는 최소 3개의 디스크가 필요합니다"
                return 1
            fi
            ;;
        6)
            if [[ $disk_count -lt 4 ]]; then
                print_error "RAID 6은 최소 4개의 디스크가 필요합니다"
                return 1
            fi
            ;;
        *)
            print_error "지원하지 않는 RAID 레벨: $level"
            print_info "지원되는 레벨: 0, 1, 5, 6"
            return 1
            ;;
    esac
    
    return 0
}

# 다음 사용 가능한 md 디바이스 찾기
get_next_md_device() {
    local i=0
    while [[ $i -lt 32 ]]; do
        local md_device="/dev/md$i"
        if [[ ! -b "$md_device" ]] && ! grep -q "md$i" /proc/mdstat 2>/dev/null; then
            echo "$md_device"
            return 0
        fi
        ((i++))
    done
    
    print_error "사용 가능한 md 디바이스를 찾을 수 없습니다"
    return 1
}

# RAID용 디스크 준비
prepare_disks_for_raid() {
    local disks=("$@")
    
    print_info "디스크 준비 중..."
    
    for disk in "${disks[@]}"; do
        print_debug "디스크 $disk 준비 중..."
        
        # 기존 RAID 메타데이터 제거
        if mdadm --examine "$disk" &>/dev/null; then
            print_info "$disk에서 기존 RAID 메타데이터 제거 중..."
            safe_execute "mdadm --zero-superblock $disk"
        fi
        
        # 파티션 테이블 초기화
        print_debug "$disk 파티션 테이블 초기화..."
        if ! wipe_disk "$disk" "quick" "false"; then
            print_warning "$disk 초기화 실패 - 계속 진행"
        fi
        
        # GPT 파티션 테이블 생성
        if ! format_disk "$disk" "gpt" "false"; then
            print_error "$disk 포맷 실패"
            return 1
        fi
        
        # RAID 파티션 생성
        local partition
        partition=$(create_raid_partition "$disk")
        if [[ -z "$partition" ]]; then
            print_error "$disk에 RAID 파티션 생성 실패"
            return 1
        fi
        
        print_success "$disk 준비 완료 (파티션: $partition)"
    done
    
    return 0
}

# RAID 파티션 생성
create_raid_partition() {
    local disk="$1"
    
    # Linux RAID 파티션 생성
    safe_execute "parted -s $disk mkpart primary 0% 100%"
    safe_execute "parted -s $disk set 1 raid on"
    
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
# RAID 관리 함수
# ===================================================================================

# RAID 동기화 대기
wait_for_raid_sync() {
    local raid_device="$1"
    local timeout="${2:-3600}"  # 1시간 기본 타임아웃
    
    print_info "RAID 동기화 진행률 모니터링 중..."
    
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            print_warning "동기화 대기 시간 초과"
            break
        fi
        
        # 동기화 상태 확인
        local sync_status
        sync_status=$(cat /proc/mdstat | grep -A 4 "${raid_device##*/}")
        
        if echo "$sync_status" | grep -q "resync"; then
            # 진행률 표시
            local progress
            progress=$(echo "$sync_status" | grep -o '[0-9]\+\.[0-9]\+%' | head -1)
            if [[ -n "$progress" ]]; then
                printf "\r동기화 진행률: %s" "$progress"
            fi
            sleep 5
        else
            printf "\r동기화 완료                    \n"
            break
        fi
    done
}

# 파일시스템 생성
create_filesystem() {
    local device="$1"
    local fstype="${2:-ext4}"
    
    print_info "$device에 $fstype 파일시스템 생성 중..."
    
    case "$fstype" in
        ext2|ext3|ext4)
            safe_execute "mkfs.$fstype -F $device"
            ;;
        xfs)
            safe_execute "mkfs.xfs -f $device"
            ;;
        btrfs)
            safe_execute "mkfs.btrfs -f $device"
            ;;
        *)
            print_error "지원하지 않는 파일시스템: $fstype"
            return 1
            ;;
    esac
}

# RAID 마운트
mount_raid() {
    local device="$1"
    local mount_point="$2"
    local options="${3:-${DEFAULT_MOUNT_OPTIONS:-defaults}}"
    
    # 마운트 포인트 생성
    if [[ ! -d "$mount_point" ]]; then
        mkdir -p "$mount_point"
        print_info "마운트 포인트 생성: $mount_point"
    fi
    
    # 마운트 실행
    if safe_execute "mount -o $options $device $mount_point"; then
        print_success "$device를 $mount_point에 마운트했습니다"
        
        # fstab 업데이트 (선택적)
        if confirm_action "부팅 시 자동 마운트를 위해 /etc/fstab에 추가하시겠습니까?"; then
            add_to_fstab "$device" "$mount_point" "$options"
        fi
        
        return 0
    else
        print_error "마운트 실패"
        return 1
    fi
}

# fstab에 추가
add_to_fstab() {
    local device="$1"
    local mount_point="$2"
    local options="$3"
    
    # UUID 확인
    local uuid
    uuid=$(blkid -s UUID -o value "$device" 2>/dev/null)
    
    if [[ -n "$uuid" ]]; then
        local fstab_entry="UUID=$uuid $mount_point auto $options 0 2"
    else
        local fstab_entry="$device $mount_point auto $options 0 2"
    fi
    
    # fstab 백업
    create_backup "/etc/fstab"
    
    # 중복 엔트리 확인
    if grep -q "$mount_point" /etc/fstab; then
        print_warning "/etc/fstab에 이미 $mount_point 엔트리가 존재합니다"
        return 1
    fi
    
    # fstab에 추가
    echo "$fstab_entry" >> /etc/fstab
    print_success "/etc/fstab에 엔트리 추가됨"
}

# mdadm.conf 업데이트
update_mdadm_conf() {
    local mdadm_conf="${MDADM_CONFIG:-/etc/mdadm/mdadm.conf}"
    
    print_info "mdadm 설정 업데이트 중..."
    
    # 백업 생성
    if [[ -f "$mdadm_conf" ]]; then
        create_backup "$mdadm_conf"
    fi
    
    # 새 설정 생성
    {
        echo "# mdadm.conf - auto-generated by ubuntu-disk-toolkit"
        echo "# $(date)"
        echo ""
        mdadm --detail --scan
    } > "$mdadm_conf"
    
    # initramfs 업데이트
    if command -v update-initramfs &> /dev/null; then
        print_info "initramfs 업데이트 중..."
        safe_execute "update-initramfs -u"
    fi
    
    print_success "mdadm 설정 업데이트 완료"
}

# ===================================================================================
# RAID 제거 함수
# ===================================================================================

# RAID 배열 제거
remove_raid() {
    local raid_device="$1"
    local force="${2:-false}"
    
    if [[ ! -b "$raid_device" ]]; then
        print_error "RAID 디바이스를 찾을 수 없습니다: $raid_device"
        return 1
    fi
    
    print_header "RAID $raid_device 제거"
    
    # 경고
    if [[ "$force" != "true" ]]; then
        show_danger_warning "RAID 배열 제거" "$raid_device의 모든 데이터가 영구적으로 삭제됩니다"
    fi
    
    # 마운트 해제
    if mount | grep -q "$raid_device"; then
        print_info "$raid_device 마운트 해제 중..."
        if ! safe_execute "umount $raid_device"; then
            print_error "마운트 해제 실패"
            return 1
        fi
    fi
    
    # RAID 배열 중지
    print_info "RAID 배열 중지 중..."
    if ! safe_execute "mdadm --stop $raid_device"; then
        print_error "RAID 배열 중지 실패"
        return 1
    fi
    
    # 구성 디스크에서 메타데이터 제거
    local devices
    devices=$(get_raid_devices "$raid_device")
    
    for device in $devices; do
        print_info "$device에서 RAID 메타데이터 제거 중..."
        safe_execute "mdadm --zero-superblock $device"
    done
    
    # mdadm.conf 업데이트
    update_mdadm_conf
    
    print_success "RAID $raid_device 제거 완료"
}

# ===================================================================================
# RAID 복구 함수
# ===================================================================================

# 실패한 디스크 교체
replace_failed_disk() {
    local raid_device="$1"
    local failed_disk="$2"
    local new_disk="$3"
    
    print_header "실패한 디스크 교체"
    print_info "RAID: $raid_device"
    print_info "실패한 디스크: $failed_disk"
    print_info "새 디스크: $new_disk"
    
    # 실패한 디스크 제거
    if safe_execute "mdadm --manage $raid_device --remove $failed_disk"; then
        print_success "실패한 디스크 제거 완료"
    else
        print_error "실패한 디스크 제거 실패"
        return 1
    fi
    
    # 새 디스크 준비
    if ! prepare_disks_for_raid "$new_disk"; then
        print_error "새 디스크 준비 실패"
        return 1
    fi
    
    # 새 디스크 추가
    local new_partition="${new_disk}1"
    [[ "$new_disk" =~ nvme ]] && new_partition="${new_disk}p1"
    
    if safe_execute "mdadm --manage $raid_device --add $new_partition"; then
        print_success "새 디스크 추가 완료"
        print_info "RAID 재구축이 시작됩니다..."
        
        if confirm_action "재구축 진행률을 모니터링하시겠습니까?"; then
            wait_for_raid_sync "$raid_device"
        fi
    else
        print_error "새 디스크 추가 실패"
        return 1
    fi
}

# RAID 상태 모니터링
monitor_raid() {
    local raid_device="$1"
    local interval="${2:-60}"  # 60초 기본 간격
    
    print_header "RAID $raid_device 모니터링 시작"
    print_info "모니터링 간격: ${interval}초"
    print_info "중지하려면 Ctrl+C를 누르세요"
    
    while true; do
        clear
        print_header "RAID $raid_device 상태 - $(date)"
        
        get_raid_summary "$raid_device"
        
        echo ""
        echo "다음 업데이트: ${interval}초 후"
        
        sleep "$interval"
    done
} 
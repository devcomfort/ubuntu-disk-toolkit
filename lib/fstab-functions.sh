#!/bin/bash

# ===================================================================================
# fstab-functions.sh - fstab 관리 함수 라이브러리
# ===================================================================================

# 공통 라이브러리 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${RED:-}" ]]; then
    # shellcheck source=lib/common.sh
    source "${SCRIPT_DIR}/common.sh"
    # shellcheck source=lib/ui-functions.sh
    source "${SCRIPT_DIR}/ui-functions.sh"
    # shellcheck source=lib/disk-functions.sh
    source "${SCRIPT_DIR}/disk-functions.sh"
fi

# fstab 파일 경로
FSTAB_FILE="${FSTAB_PATH:-/etc/fstab}"

# ===================================================================================
# fstab 파싱 및 분석
# ===================================================================================

# fstab 항목 구조체 (associative array 시뮬레이션)
# device:mountpoint:fstype:options:dump:pass

# fstab 파일 읽기 및 파싱
parse_fstab() {
    local fstab_file="${1:-$FSTAB_FILE}"
    
    if [[ ! -f "$fstab_file" ]]; then
        print_error "fstab 파일을 찾을 수 없습니다: $fstab_file"
        return 1
    fi
    
    # 주석과 빈 줄 제외하고 파싱
    grep -v '^\s*#' "$fstab_file" | grep -v '^\s*$' | while IFS= read -r line; do
        # 공백으로 분할
        read -r device mountpoint fstype options dump pass <<< "$line"
        
        # 유효한 항목인지 확인
        if [[ -n "$device" && -n "$mountpoint" && -n "$fstype" ]]; then
            echo "$device:${mountpoint}:${fstype}:${options:-defaults}:${dump:-0}:${pass:-0}"
        fi
    done
}

# fstab 분석 정보 출력
analyze_fstab() {
    local fstab_file="${1:-$FSTAB_FILE}"
    local format="${2:-table}"
    
    print_header "fstab 분석 결과"
    
    if [[ ! -f "$fstab_file" ]]; then
        print_error "fstab 파일이 존재하지 않습니다: $fstab_file"
        return 1
    fi
    
    local entries
    entries=$(parse_fstab "$fstab_file")
    
    if [[ -z "$entries" ]]; then
        print_info "fstab에 마운트 항목이 없습니다"
        return 0
    fi
    
    case "$format" in
        "table")
            table_start "fstab 마운트 항목"
            table_row "장치" "마운트 포인트" "파일시스템" "상태"
            table_separator
            
            while IFS=':' read -r device mountpoint fstype options dump pass; do
                local status="Unknown"
                local device_real="$device"
                
                # UUID 또는 LABEL을 실제 장치로 변환
                if [[ "$device" =~ ^UUID= ]]; then
                    device_real=$(findfs "$device" 2>/dev/null || echo "Not Found")
                elif [[ "$device" =~ ^LABEL= ]]; then
                    device_real=$(findfs "$device" 2>/dev/null || echo "Not Found")
                fi
                
                # 마운트 상태 확인
                if [[ "$device_real" == "Not Found" ]]; then
                    status="❌ 장치 없음"
                elif findmnt "$mountpoint" &>/dev/null; then
                    status="✅ 마운트됨"
                elif [[ "$options" == *"noauto"* ]]; then
                    status="⚠️  수동 마운트"
                else
                    status="❌ 미마운트"
                fi
                
                # 장치명 단축
                local device_short="$device"
                if [[ ${#device} -gt 20 ]]; then
                    device_short="${device:0:17}..."
                fi
                
                table_row "$device_short" "$mountpoint" "$fstype" "$status"
            done <<< "$entries"
            
            table_end
            ;;
        "detailed")
            local count=0
            while IFS=':' read -r device mountpoint fstype options dump pass; do
                ((count++))
                
                print_header "fstab 항목 #$count"
                table_start "상세 정보"
                table_row "장치" "$device"
                table_row "마운트 포인트" "$mountpoint"
                table_row "파일시스템" "$fstype"
                table_row "마운트 옵션" "$options"
                table_row "덤프" "$dump"
                table_row "Pass" "$pass"
                
                # 실제 장치 확인
                local device_real="$device"
                if [[ "$device" =~ ^UUID= ]]; then
                    device_real=$(findfs "$device" 2>/dev/null || echo "Not Found")
                    table_row "실제 장치" "$device_real"
                elif [[ "$device" =~ ^LABEL= ]]; then
                    device_real=$(findfs "$device" 2>/dev/null || echo "Not Found")
                    table_row "실제 장치" "$device_real"
                fi
                
                # 마운트 상태
                if findmnt "$mountpoint" &>/dev/null; then
                    table_row "상태" "✅ 마운트됨"
                    
                    # 마운트 정보
                    local mount_info
                    mount_info=$(findmnt -n -o SOURCE,FSTYPE,OPTIONS "$mountpoint" 2>/dev/null)
                    if [[ -n "$mount_info" ]]; then
                        table_row "현재 마운트" "$mount_info"
                    fi
                else
                    table_row "상태" "❌ 미마운트"
                fi
                
                table_end
                echo ""
            done <<< "$entries"
            ;;
        "json")
            echo "{"
            echo "  \"fstab_file\": \"$fstab_file\","
            echo "  \"entries\": ["
            
            local first=true
            while IFS=':' read -r device mountpoint fstype options dump pass; do
                [[ "$first" != "true" ]] && echo "    ,"
                
                local device_real="$device"
                if [[ "$device" =~ ^UUID= ]]; then
                    device_real=$(findfs "$device" 2>/dev/null || echo "Not Found")
                elif [[ "$device" =~ ^LABEL= ]]; then
                    device_real=$(findfs "$device" 2>/dev/null || echo "Not Found")
                fi
                
                local mounted="false"
                if findmnt "$mountpoint" &>/dev/null; then
                    mounted="true"
                fi
                
                echo "    {"
                echo "      \"device\": \"$device\","
                echo "      \"device_real\": \"$device_real\","
                echo "      \"mountpoint\": \"$mountpoint\","
                echo "      \"fstype\": \"$fstype\","
                echo "      \"options\": \"$options\","
                echo "      \"dump\": $dump,"
                echo "      \"pass\": $pass,"
                echo "      \"mounted\": $mounted"
                echo "    }"
                
                first=false
            done <<< "$entries"
            
            echo "  ]"
            echo "}"
            ;;
        *)
            print_error "지원하지 않는 형식: $format"
            return 1
            ;;
    esac
}

# ===================================================================================
# fstab 항목 관리
# ===================================================================================

# fstab에 새 항목 추가 (interactive)
add_fstab_entry_interactive() {
    print_header "fstab 항목 추가"
    
    # 관리자 권한 확인
    check_root_privileges || return 1
    
    # 1. 장치 선택
    print_info "1단계: 마운트할 장치 선택"
    local available_devices
    available_devices=$(get_unmounted_devices)
    
    if [[ -z "$available_devices" ]]; then
        print_warning "마운트할 수 있는 장치가 없습니다"
        return 1
    fi
    
    echo "사용 가능한 장치:"
    local device_array=()
    local count=1
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local device="/dev/${line%% *}"
        local info=($line)
        local size="${info[1]:-Unknown}"
        local fstype="${info[3]:-Unknown}"
        
        device_array+=("$device")
        printf "%2d) %s (%s, %s)\n" $count "$device" "$size" "$fstype"
        ((count++))
    done <<< "$available_devices"
    
    local choice
    choice=$(get_user_choice "장치를 선택하세요" "${#device_array[@]}")
    local selected_device="${device_array[$((choice-1))]}"
    
    print_success "선택된 장치: $selected_device"
    
    # 2. 마운트 포인트 입력
    print_info "2단계: 마운트 포인트 지정"
    local mountpoint
    while true; do
        read -r -p "마운트 포인트 (예: /mnt/data): " mountpoint
        
        if [[ -z "$mountpoint" ]]; then
            print_error "마운트 포인트를 입력해야 합니다"
            continue
        fi
        
        if [[ "$mountpoint" != /* ]]; then
            print_error "절대 경로를 입력해야 합니다 (/로 시작)"
            continue
        fi
        
        # 기존 fstab 항목과 중복 검사
        if grep -q " $mountpoint " "$FSTAB_FILE" 2>/dev/null; then
            print_error "이미 fstab에 등록된 마운트 포인트입니다"
            continue
        fi
        
        break
    done
    
    # 3. 파일시스템 타입 확인
    print_info "3단계: 파일시스템 타입 확인"
    local fstype
    fstype=$(lsblk -n -o FSTYPE "$selected_device" 2>/dev/null | grep -v '^$' | head -1)
    
    if [[ -z "$fstype" ]]; then
        print_warning "파일시스템을 감지할 수 없습니다"
        read -r -p "파일시스템 타입을 입력하세요 (기본: auto): " fstype
        fstype="${fstype:-auto}"
    else
        print_success "감지된 파일시스템: $fstype"
        if ! confirm_action "이 파일시스템을 사용하시겠습니까?"; then
            read -r -p "파일시스템 타입을 입력하세요: " fstype
        fi
    fi
    
    # 4. 마운트 옵션 설정
    print_info "4단계: 마운트 옵션 설정"
    
    local base_options="defaults"
    local additional_options=()
    
    # fail-safe 옵션 추천
    if confirm_action "fail-safe 옵션을 활성화하시겠습니까? (권장)"; then
        additional_options+=("nofail")
        print_info "nofail 옵션 추가됨 (장치가 없어도 부팅 계속)"
    fi
    
    # noatime 옵션 (성능 향상)
    if confirm_action "noatime 옵션을 추가하시겠습니까? (성능 향상)"; then
        additional_options+=("noatime")
    fi
    
    # 사용자 정의 옵션
    local custom_options
    read -r -p "추가 마운트 옵션 (선택사항, 쉼표로 구분): " custom_options
    
    if [[ -n "$custom_options" ]]; then
        IFS=',' read -ra custom_array <<< "$custom_options"
        additional_options+=("${custom_array[@]}")
    fi
    
    # 최종 옵션 조합
    local final_options="$base_options"
    if [[ ${#additional_options[@]} -gt 0 ]]; then
        final_options="$base_options,$(IFS=','; echo "${additional_options[*]}")"
    fi
    
    # 5. dump와 pass 설정
    print_info "5단계: 백업 및 검사 옵션"
    
    local dump=0
    if confirm_action "dump 백업을 활성화하시겠습니까?"; then
        dump=1
    fi
    
    local pass=0
    if [[ "$mountpoint" == "/" ]]; then
        pass=1
        print_info "루트 파티션은 pass=1로 설정됩니다"
    elif confirm_action "부팅 시 파일시스템 검사를 활성화하시겠습니까?"; then
        pass=2
    fi
    
    # 6. UUID 사용 여부
    print_info "6단계: 장치 식별 방법"
    local device_identifier="$selected_device"
    
    if confirm_action "UUID를 사용하시겠습니까? (권장)"; then
        local uuid
        uuid=$(blkid -s UUID -o value "$selected_device" 2>/dev/null)
        
        if [[ -n "$uuid" ]]; then
            device_identifier="UUID=$uuid"
            print_success "UUID 사용: $uuid"
        else
            print_warning "UUID를 찾을 수 없어 장치명을 사용합니다"
        fi
    fi
    
    # 7. 최종 확인 및 추가
    print_header "fstab 항목 최종 확인"
    table_start "추가할 항목"
    table_row "장치" "$device_identifier"
    table_row "마운트 포인트" "$mountpoint"
    table_row "파일시스템" "$fstype"
    table_row "옵션" "$final_options"
    table_row "덤프" "$dump"
    table_row "Pass" "$pass"
    table_end
    
    if ! confirm_action "이 항목을 fstab에 추가하시겠습니까?"; then
        print_info "취소되었습니다"
        return 1
    fi
    
    # fstab에 추가
    add_fstab_entry "$device_identifier" "$mountpoint" "$fstype" "$final_options" "$dump" "$pass"
    
    # 마운트 포인트 생성
    if [[ ! -d "$mountpoint" ]]; then
        if confirm_action "마운트 포인트 디렉토리를 생성하시겠습니까?"; then
            mkdir -p "$mountpoint"
            print_success "마운트 포인트 생성됨: $mountpoint"
        fi
    fi
    
    # 즉시 마운트 여부
    if confirm_action "지금 마운트를 시도하시겠습니까?"; then
        if mount "$mountpoint"; then
            print_success "마운트 성공: $mountpoint"
        else
            print_error "마운트 실패. 설정을 확인하세요"
        fi
    fi
    
    print_success "fstab 항목 추가 완료!"
}

# fstab 항목 추가 (프로그래매틱)
add_fstab_entry() {
    local device="$1"
    local mountpoint="$2"
    local fstype="$3"
    local options="${4:-defaults}"
    local dump="${5:-0}"
    local pass="${6:-0}"
    
    # 입력 검증
    if [[ -z "$device" || -z "$mountpoint" || -z "$fstype" ]]; then
        print_error "필수 매개변수가 누락되었습니다"
        return 1
    fi
    
    # fstab 백업
    create_backup "$FSTAB_FILE"
    
    # 중복 검사
    if grep -q " $mountpoint " "$FSTAB_FILE" 2>/dev/null; then
        print_error "마운트 포인트가 이미 fstab에 존재합니다: $mountpoint"
        return 1
    fi
    
    # 항목 추가
    local fstab_entry="$device $mountpoint $fstype $options $dump $pass"
    
    print_info "fstab에 항목 추가 중..."
    echo "$fstab_entry" >> "$FSTAB_FILE"
    
    print_success "fstab 항목 추가됨:"
    echo "  $fstab_entry"
    
    return 0
}

# ===================================================================================
# fstab 항목 제거
# ===================================================================================

# fstab 항목 제거 (interactive)
remove_fstab_entry_interactive() {
    print_header "fstab 항목 제거"
    
    # 관리자 권한 확인
    check_root_privileges || return 1
    
    # 현재 fstab 항목 목록
    local entries
    entries=$(parse_fstab "$FSTAB_FILE")
    
    if [[ -z "$entries" ]]; then
        print_info "제거할 fstab 항목이 없습니다"
        return 0
    fi
    
    print_info "현재 fstab 항목:"
    local entry_array=()
    local count=1
    
    while IFS=':' read -r device mountpoint fstype options dump pass; do
        entry_array+=("$mountpoint")
        
        # 마운트 상태 확인
        local status="미마운트"
        if findmnt "$mountpoint" &>/dev/null; then
            status="마운트됨"
        fi
        
        printf "%2d) %s (%s) - %s\n" $count "$mountpoint" "$device" "$status"
        ((count++))
    done <<< "$entries"
    
    # 사용자 선택
    local choice
    choice=$(get_user_choice "제거할 항목을 선택하세요" "${#entry_array[@]}")
    local selected_mountpoint="${entry_array[$((choice-1))]}"
    
    # 선택된 항목 정보 표시
    local selected_entry
    selected_entry=$(echo "$entries" | sed -n "${choice}p")
    IFS=':' read -r device mountpoint fstype options dump pass <<< "$selected_entry"
    
    print_header "제거할 항목 정보"
    table_start "선택된 항목"
    table_row "장치" "$device"
    table_row "마운트 포인트" "$mountpoint"
    table_row "파일시스템" "$fstype"
    table_row "옵션" "$options"
    table_end
    
    # 마운트 상태 확인 및 언마운트
    if findmnt "$mountpoint" &>/dev/null; then
        print_warning "이 항목은 현재 마운트되어 있습니다"
        
        if confirm_action "언마운트를 진행하시겠습니까?"; then
            if umount "$mountpoint"; then
                print_success "언마운트 완료: $mountpoint"
            else
                print_error "언마운트 실패. fstab 제거를 중단합니다"
                return 1
            fi
        else
            print_warning "마운트된 상태에서 fstab 항목을 제거하면 다음 부팅 시 문제가 발생할 수 있습니다"
            if ! confirm_action "그래도 계속하시겠습니까?"; then
                print_info "취소되었습니다"
                return 1
            fi
        fi
    fi
    
    # 최종 확인
    if ! confirm_action "정말로 이 fstab 항목을 제거하시겠습니까?"; then
        print_info "취소되었습니다"
        return 1
    fi
    
    # fstab에서 제거
    remove_fstab_entry "$mountpoint"
}

# fstab 항목 제거 (프로그래매틱)
remove_fstab_entry() {
    local mountpoint="$1"
    
    if [[ -z "$mountpoint" ]]; then
        print_error "마운트 포인트를 지정해야 합니다"
        return 1
    fi
    
    # 항목 존재 확인
    if ! grep -q " $mountpoint " "$FSTAB_FILE" 2>/dev/null; then
        print_error "fstab에서 마운트 포인트를 찾을 수 없습니다: $mountpoint"
        return 1
    fi
    
    # fstab 백업
    create_backup "$FSTAB_FILE"
    
    # 항목 제거
    print_info "fstab에서 항목 제거 중: $mountpoint"
    
    # 임시 파일을 사용하여 안전하게 제거
    local temp_file
    temp_file=$(mktemp)
    
    grep -v " $mountpoint " "$FSTAB_FILE" > "$temp_file"
    
    if mv "$temp_file" "$FSTAB_FILE"; then
        print_success "fstab 항목 제거됨: $mountpoint"
        return 0
    else
        print_error "fstab 수정 실패"
        rm -f "$temp_file"
        return 1
    fi
}

# ===================================================================================
# 유틸리티 함수
# ===================================================================================

# 마운트되지 않은 장치 목록
get_unmounted_devices() {
    lsblk -n -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | while read -r name size type fstype mountpoint; do
        # 파티션만 대상 (전체 디스크 제외)
        if [[ "$type" == "part" && -z "$mountpoint" && -n "$fstype" ]]; then
            echo "$name $size $type $fstype"
        fi
    done
}

# fstab 검증
validate_fstab() {
    local fstab_file="${1:-$FSTAB_FILE}"
    
    print_header "fstab 검증"
    
    if [[ ! -f "$fstab_file" ]]; then
        print_error "fstab 파일이 존재하지 않습니다: $fstab_file"
        return 1
    fi
    
    local issues=0
    local line_number=0
    
    while IFS= read -r line; do
        ((line_number++))
        
        # 주석이나 빈 줄 건너뛰기
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi
        
        # 필드 수 확인
        local field_count
        field_count=$(echo "$line" | wc -w)
        
        if [[ $field_count -lt 3 ]]; then
            print_error "라인 $line_number: 필드가 부족합니다 ($field_count/6)"
            echo "  $line"
            ((issues++))
            continue
        fi
        
        read -r device mountpoint fstype options dump pass <<< "$line"
        
        # 장치 존재 확인
        if [[ "$device" =~ ^UUID= ]]; then
            if ! findfs "$device" &>/dev/null; then
                print_warning "라인 $line_number: UUID 장치를 찾을 수 없습니다"
                echo "  $device"
                ((issues++))
            fi
        elif [[ "$device" =~ ^LABEL= ]]; then
            if ! findfs "$device" &>/dev/null; then
                print_warning "라인 $line_number: LABEL 장치를 찾을 수 없습니다"
                echo "  $device"
                ((issues++))
            fi
        elif [[ "$device" =~ ^/dev/ ]]; then
            if [[ ! -b "$device" ]]; then
                print_warning "라인 $line_number: 블록 장치가 존재하지 않습니다"
                echo "  $device"
                ((issues++))
            fi
        fi
        
        # 마운트 포인트 확인
        if [[ "$mountpoint" != "none" && "$mountpoint" != "swap" ]]; then
            if [[ ! -d "$mountpoint" ]]; then
                print_warning "라인 $line_number: 마운트 포인트 디렉토리가 존재하지 않습니다"
                echo "  $mountpoint"
                ((issues++))
            fi
        fi
        
    done < "$fstab_file"
    
    if [[ $issues -eq 0 ]]; then
        print_success "fstab 검증 통과 ($line_number 라인 검사)"
    else
        print_warning "fstab 검증에서 $issues개의 문제가 발견되었습니다"
    fi
    
    return $issues
}

# fstab 테스트 마운트
test_fstab_mount() {
    local fstab_file="${1:-$FSTAB_FILE}"
    
    print_header "fstab 테스트 마운트"
    
    if ! validate_fstab "$fstab_file"; then
        print_error "fstab 검증에 실패하여 테스트를 중단합니다"
        return 1
    fi
    
    print_info "모든 fstab 항목을 테스트 마운트합니다 (읽기 전용)"
    
    local entries
    entries=$(parse_fstab "$fstab_file")
    
    while IFS=':' read -r device mountpoint fstype options dump pass; do
        # 특수 마운트 포인트 건너뛰기
        if [[ "$mountpoint" == "none" || "$mountpoint" == "swap" || "$fstype" == "swap" ]]; then
            continue
        fi
        
        print_info "테스트 중: $mountpoint"
        
        # 이미 마운트된 경우 건너뛰기
        if findmnt "$mountpoint" &>/dev/null; then
            print_success "이미 마운트됨: $mountpoint"
            continue
        fi
        
        # 테스트 마운트 (읽기 전용)
        local test_options="ro,${options}"
        
        if mount -o "$test_options" "$device" "$mountpoint" 2>/dev/null; then
            print_success "테스트 마운트 성공: $mountpoint"
            
            # 즉시 언마운트
            if umount "$mountpoint"; then
                print_debug "테스트 언마운트 완료: $mountpoint"
            else
                print_warning "테스트 언마운트 실패: $mountpoint"
            fi
        else
            print_error "테스트 마운트 실패: $mountpoint"
        fi
        
    done <<< "$entries"
    
    print_success "fstab 테스트 마운트 완료"
} 
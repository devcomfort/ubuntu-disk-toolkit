#!/bin/bash

# ===================================================================================
# system-functions.sh - 시스템 검사 및 관리 함수 라이브러리
# ===================================================================================

# 공통 라이브러리 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${RED:-}" ]]; then
    # shellcheck source=lib/common.sh
    source "${SCRIPT_DIR}/common.sh"
fi

# ===================================================================================
# 시스템 검사 함수
# ===================================================================================

# 필수 CLI 도구 검사 및 설치
check_and_install_requirements() {
    local auto_install="${1:-false}"
    local missing_tools=()
    local missing_packages=()
    
    print_header "시스템 요구사항 검사"
    
    # 필수 CLI 도구 정의
    local required_tools=(
        "lsblk:util-linux"
        "mount:util-linux" 
        "umount:util-linux"
        "mdadm:mdadm"
        "smartctl:smartmontools"
        "parted:parted"
        "mkfs.ext4:e2fsprogs"
        "blkid:util-linux"
        "findmnt:util-linux"
    )
    
    # 각 도구 확인
    for tool_package in "${required_tools[@]}"; do
        local tool="${tool_package%%:*}"
        local package="${tool_package##*:}"
        
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
            missing_packages+=("$package")
            print_error "필수 도구 누락: $tool (패키지: $package)"
        else
            print_success "확인됨: $tool"
        fi
    done
    
    # 누락된 도구가 있는 경우
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_warning "총 ${#missing_tools[@]}개의 필수 도구가 설치되지 않았습니다"
        
        # 패키지 중복 제거
        local unique_packages
        readarray -t unique_packages < <(printf '%s\n' "${missing_packages[@]}" | sort -u)
        
        echo "설치가 필요한 패키지: ${unique_packages[*]}"
        
        if [[ "$auto_install" == "true" ]] || confirm_action "지금 설치하시겠습니까?"; then
            install_packages "${unique_packages[@]}"
        else
            print_error "필수 도구가 설치되지 않아 일부 기능이 제한될 수 있습니다"
            return 1
        fi
    else
        print_success "모든 필수 도구가 설치되어 있습니다"
    fi
    
    return 0
}

# 패키지 설치
install_packages() {
    local packages=("$@")
    
    print_info "패키지 설치 중: ${packages[*]}"
    
    # 관리자 권한 확인
    if [[ $EUID -ne 0 ]]; then
        print_error "패키지 설치에는 관리자 권한이 필요합니다"
        print_info "다음 명령어를 실행하세요:"
        echo "  sudo apt update && sudo apt install -y ${packages[*]}"
        return 1
    fi
    
    # apt 저장소 업데이트
    print_info "패키지 저장소 업데이트 중..."
    if ! safe_execute "apt update"; then
        print_error "패키지 저장소 업데이트 실패"
        return 1
    fi
    
    # 패키지 설치
    print_info "패키지 설치 중..."
    if safe_execute "apt install -y ${packages[*]}"; then
        print_success "패키지 설치 완료"
        return 0
    else
        print_error "패키지 설치 실패"
        return 1
    fi
}

# sudo 권한 검사
check_sudo_privileges() {
    local operation="${1:-RAID 관리 작업}"
    local required="${2:-true}"
    
    if [[ $EUID -eq 0 ]]; then
        print_success "관리자 권한으로 실행 중"
        return 0
    fi
    
    if [[ "$required" == "true" ]]; then
        print_warning "이 작업($operation)에는 관리자 권한이 필요합니다"
        print_info "다음 방법 중 하나를 사용하세요:"
        echo "  1. sudo $0 $*"
        echo "  2. sudo -i 로 관리자로 전환 후 실행"
        echo ""
        print_warning "보안상 자동으로 권한 상승을 시도하지 않습니다"
        return 1
    else
        print_info "현재 일반 사용자로 실행 중 (일부 기능 제한)"
        return 0
    fi
}

# 시스템 호환성 검사
check_system_compatibility() {
    print_header "시스템 호환성 검사"
    
    local issues=0
    
    # 운영체제 확인
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        
        if [[ "$ID" == "ubuntu" ]] || [[ "$ID_LIKE" == *"ubuntu"* ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
            print_success "지원되는 운영체제: $PRETTY_NAME"
        else
            print_warning "공식 지원하지 않는 운영체제: $PRETTY_NAME"
            ((issues++))
        fi
    else
        print_error "운영체제 정보를 확인할 수 없습니다"
        ((issues++))
    fi
    
    # 커널 모듈 확인
    local required_modules=("md_mod" "raid0" "raid1" "raid456")
    
    for module in "${required_modules[@]}"; do
        if lsmod | grep -q "^$module" || modinfo "$module" &>/dev/null; then
            print_success "커널 모듈 사용 가능: $module"
        else
            print_warning "커널 모듈 확인 불가: $module"
            ((issues++))
        fi
    done
    
    # /proc/mdstat 확인
    if [[ -r /proc/mdstat ]]; then
        print_success "/proc/mdstat 접근 가능"
    else
        print_error "/proc/mdstat에 접근할 수 없습니다"
        ((issues++))
    fi
    
    # 디스크 장치 접근 권한 확인
    if [[ -r /dev && -w /dev ]] || [[ $EUID -eq 0 ]]; then
        print_success "디스크 장치 접근 권한 확인"
    else
        print_warning "디스크 장치 접근 권한이 제한됩니다"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        print_success "시스템 호환성 검사 통과"
        return 0
    else
        print_warning "시스템 호환성 검사에서 $issues개의 문제가 발견되었습니다"
        return 1
    fi
}

# ===================================================================================
# 시스템 정보 수집
# ===================================================================================

# 시스템 정보 요약
get_system_summary() {
    local format="${1:-table}"
    
    case "$format" in
        "table")
            table_start "시스템 정보 요약"
            table_row "운영체제" "$(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
            table_row "커널 버전" "$(uname -r)"
            table_row "아키텍처" "$(uname -m)"
            table_row "메모리" "$(free -h | awk '/^Mem:/ {print $2}')"
            table_row "디스크 개수" "$(lsblk -d -n | grep -c disk)"
            table_row "RAID 배열" "$(awk '/^md/ {count++} END {print count+0}' /proc/mdstat 2>/dev/null)"
            table_row "마운트 포인트" "$(findmnt -D | wc -l)"
            table_end
            ;;
        "json")
            cat << EOF
{
    "os": "$(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")",
    "kernel": "$(uname -r)",
    "architecture": "$(uname -m)",
    "memory": "$(free -h | awk '/^Mem:/ {print $2}')",
    "disk_count": $(lsblk -d -n | grep -c disk),
    "raid_count": $(awk '/^md/ {count++} END {print count+0}' /proc/mdstat 2>/dev/null),
    "mount_count": $(findmnt -D | wc -l)
}
EOF
            ;;
        *)
            print_error "지원하지 않는 포맷: $format"
            return 1
            ;;
    esac
}

# 하드웨어 정보 수집
get_hardware_info() {
    print_header "하드웨어 정보"
    
    # CPU 정보
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        local cpu_cores
        cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
        
        table_start "CPU 정보"
        table_row "모델" "$cpu_model"
        table_row "코어 수" "$cpu_cores"
        table_end
    fi
    
    # 메모리 정보
    if command -v free &> /dev/null; then
        table_start "메모리 정보"
        free -h | tail -n +2 | while read -r line; do
            local mem_type=$(echo "$line" | awk '{print $1}')
            local mem_total=$(echo "$line" | awk '{print $2}')
            local mem_used=$(echo "$line" | awk '{print $3}')
            local mem_free=$(echo "$line" | awk '{print $4}')
            
            table_row "$mem_type" "총: $mem_total, 사용: $mem_used, 여유: $mem_free"
        done
        table_end
    fi
    
    # 스토리지 컨트롤러 정보 (선택적)
    if command -v lspci &> /dev/null; then
        local storage_controllers
        storage_controllers=$(lspci | grep -i "storage\|raid\|sata\|nvme" | wc -l)
        
        if [[ $storage_controllers -gt 0 ]]; then
            table_start "스토리지 컨트롤러"
            lspci | grep -i "storage\|raid\|sata\|nvme" | while read -r line; do
                local controller=$(echo "$line" | cut -d: -f3 | xargs)
                table_row "컨트롤러" "$controller"
            done
            table_end
        fi
    fi
}

# ===================================================================================
# 종합 시스템 검사
# ===================================================================================

# 전체 시스템 검사 실행
run_system_check() {
    local auto_install="${1:-false}"
    local detailed="${2:-false}"
    
    print_header "Ubuntu RAID CLI 시스템 검사"
    
    local total_issues=0
    
    # 1. 기본 호환성 검사
    if ! check_system_compatibility; then
        ((total_issues++))
    fi
    
    echo ""
    
    # 2. 필수 도구 검사
    if ! check_and_install_requirements "$auto_install"; then
        ((total_issues++))
    fi
    
    echo ""
    
    # 3. 권한 검사 (정보성)
    check_sudo_privileges "시스템 관리" "false"
    
    echo ""
    
    # 4. 시스템 정보 요약
    get_system_summary
    
    # 5. 상세 하드웨어 정보 (선택적)
    if [[ "$detailed" == "true" ]]; then
        echo ""
        get_hardware_info
    fi
    
    # 결과 요약
    echo ""
    print_header "검사 결과 요약"
    
    if [[ $total_issues -eq 0 ]]; then
        print_success "✅ 시스템이 Ubuntu RAID CLI 사용에 적합합니다"
        print_info "모든 기능을 정상적으로 사용할 수 있습니다"
        return 0
    else
        print_warning "⚠️  $total_issues개의 문제가 발견되었습니다"
        print_info "일부 기능이 제한될 수 있습니다"
        
        if [[ $total_issues -eq 1 ]] && ! command -v mdadm &> /dev/null; then
            print_info "💡 대부분의 문제는 필수 패키지 설치로 해결됩니다"
            echo "   sudo apt update && sudo apt install -y mdadm smartmontools"
        fi
        
        return 1
    fi
}

# 시스템 정보만 간단히 출력
show_system_info() {
    local format="${1:-table}"
    
    case "$format" in
        "summary")
            get_system_summary "table"
            ;;
        "detailed") 
            get_system_summary "table"
            echo ""
            get_hardware_info
            ;;
        "json")
            get_system_summary "json"
            ;;
        *)
            print_error "지원하지 않는 형식: $format"
            echo "사용 가능한 형식: summary, detailed, json"
            return 1
            ;;
    esac
}

# ===================================================================================
# 자동 복구 기능
# ===================================================================================

# 시스템 자동 설정
auto_setup_system() {
    print_header "Ubuntu RAID CLI 자동 설정"
    
    if ! check_sudo_privileges "시스템 설정"; then
        return 1
    fi
    
    print_info "시스템을 Ubuntu RAID CLI 사용에 최적화합니다..."
    
    # 1. 필수 패키지 설치
    if ! check_and_install_requirements "true"; then
        print_error "필수 패키지 설치 실패"
        return 1
    fi
    
    # 2. 커널 모듈 로드
    local required_modules=("md_mod" "raid1" "raid456")
    
    for module in "${required_modules[@]}"; do
        if ! lsmod | grep -q "^$module"; then
            print_info "커널 모듈 로드 중: $module"
            if safe_execute "modprobe $module"; then
                print_success "모듈 로드됨: $module"
            else
                print_warning "모듈 로드 실패: $module"
            fi
        fi
    done
    
    # 3. 부팅 시 모듈 자동 로드 설정
    local modules_file="/etc/modules-load.d/raid.conf"
    if [[ ! -f "$modules_file" ]]; then
        print_info "부팅 시 RAID 모듈 자동 로드 설정 중..."
        cat > "$modules_file" << 'EOF'
# RAID modules for ubuntu-raid-cli
md_mod
raid0
raid1
raid456
EOF
        print_success "모듈 자동 로드 설정 완료: $modules_file"
    fi
    
    # 4. mdadm 설정 초기화
    local mdadm_conf="/etc/mdadm/mdadm.conf"
    if [[ ! -f "$mdadm_conf" ]]; then
        print_info "mdadm 설정 파일 초기화..."
        mkdir -p "$(dirname "$mdadm_conf")"
        cat > "$mdadm_conf" << 'EOF'
# mdadm.conf - managed by ubuntu-raid-cli
# This file is automatically updated when RAID arrays are created/modified

DEVICE partitions
EOF
        print_success "mdadm 설정 파일 생성: $mdadm_conf"
    fi
    
    print_success "시스템 자동 설정 완료!"
    print_info "이제 Ubuntu RAID CLI의 모든 기능을 사용할 수 있습니다"
    
    return 0
} 
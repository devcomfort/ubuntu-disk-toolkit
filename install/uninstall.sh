#!/bin/bash

# ===================================================================================
# uninstall.sh - Ubuntu Disk Toolkit 제거 스크립트
# ===================================================================================

set -euo pipefail

# 색상 출력 설정
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 기본 설정
INSTALL_PREFIX="/usr/local"
CONFIG_DIR="/etc/ubuntu-disk-toolkit"
LOG_DIR="/var/log"
SYSTEMD_DIR="/etc/systemd/system"

# 전역 변수
FORCE_YES=false

# ===================================================================================
# 로그 함수들
print_header() {
    echo -e "\n${BLUE}=======================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=======================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 사용법 표시
show_usage() {
    cat << 'EOF'

uninstall.sh - Ubuntu Disk Toolkit 제거

사용법:
  sudo ./uninstall.sh [옵션]

옵션:
  --keep-config    설정 파일 보존
  --keep-logs      로그 파일 보존
  --dry-run        실제 제거하지 않고 확인만
  --force          확인 없이 강제 제거
  -y, --yes        모든 확인 질문에 자동으로 yes 응답
  -h, --help       도움말 표시

주의:
  이 스크립트는 관리자 권한이 필요합니다.

EOF
}

# 사용자 확인
confirm_action() {
    local message="$1"
    
    # Force yes 모드인 경우 자동으로 yes 반환
    if [[ "$FORCE_YES" == "true" ]]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
        echo -e "계속하시겠습니까? [y/N]: ${GREEN}y (자동)${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}⚠️  $message${NC}"
    read -p "계속하시겠습니까? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "제거가 취소되었습니다"
        exit 0
    fi
}

# 권한 확인
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        print_error "이 스크립트는 관리자 권한이 필요합니다"
        print_info "다음 명령어로 실행하세요: sudo $0"
        exit 1
    fi
}

# 설치 상태 확인
check_installation() {
    print_header "설치 상태 확인"
    
    local found_items=()
    
    # 실행 파일 확인
    if [[ -f "${INSTALL_PREFIX}/bin/ubuntu-disk-toolkit" ]]; then
        found_items+=("메인 실행 파일")
    fi
    
    # 라이브러리 확인
    if [[ -d "${INSTALL_PREFIX}/lib/ubuntu-disk-toolkit" ]]; then
        found_items+=("라이브러리 파일들")
    fi
    
    # 설정 파일 확인
    if [[ -d "$CONFIG_DIR" ]]; then
        found_items+=("설정 파일들")
    fi
    
    # systemd 서비스 확인
    if [[ -f "${SYSTEMD_DIR}/ubuntu-disk-toolkit.service" ]] || \
       [[ -f "${SYSTEMD_DIR}/ubuntu-disk-toolkit-monitor.service" ]]; then
        found_items+=("systemd 서비스")
    fi
    
    # 로그 파일 확인
    if [[ -f "${LOG_DIR}/ubuntu-disk-toolkit.log" ]]; then
        found_items+=("로그 파일들")
    fi
    
    if [[ ${#found_items[@]} -eq 0 ]]; then
        print_warning "Ubuntu Disk Toolkit이 설치되지 않은 것 같습니다"
        return 1
    else
        print_success "다음 구성 요소가 발견되었습니다:"
        for item in "${found_items[@]}"; do
            echo "  - $item"
        done
        return 0
    fi
}

# systemd 서비스 정지 및 제거
remove_systemd_services() {
    print_header "systemd 서비스 제거"
    
    local services=(
        "ubuntu-disk-toolkit"
        "ubuntu-disk-toolkit-monitor"
        "ubuntu-disk-toolkit-health-check"
    )
    
    for service in "${services[@]}"; do
        local service_file="${SYSTEMD_DIR}/${service}.service"
        
        if [[ -f "$service_file" ]]; then
            print_info "서비스 정지: $service"
            systemctl stop "$service" 2>/dev/null || true
            
            print_info "서비스 비활성화: $service"
            systemctl disable "$service" 2>/dev/null || true
            
            if [[ "$DRY_RUN" != "true" ]]; then
                rm -f "$service_file"
                print_success "서비스 파일 제거: $service"
            else
                print_info "[DRY RUN] 제거될 파일: $service_file"
            fi
        fi
    done
    
    # systemd 데몬 재로드
    if [[ "$DRY_RUN" != "true" ]]; then
        systemctl daemon-reload
        print_success "systemd 데몬 재로드 완료"
    fi
}

# 실행 파일 제거
remove_binaries() {
    print_header "실행 파일 제거"
    
    local binaries=(
        "ubuntu-disk-toolkit"
        "check-system"
        "manage-disk"
        "manage-fstab"
        "check-disk-health"
    )
    
    for binary in "${binaries[@]}"; do
        local binary_path="${INSTALL_PREFIX}/bin/$binary"
        if [[ -f "$binary_path" ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                rm -f "$binary_path"
                print_success "실행 파일 제거: $binary"
            else
                print_info "[DRY RUN] 제거될 파일: $binary_path"
            fi
        fi
    done
}

# 라이브러리 파일 제거
remove_libraries() {
    print_header "라이브러리 파일 제거"
    
    local lib_dir="${INSTALL_PREFIX}/lib/ubuntu-disk-toolkit"
    
    if [[ -d "$lib_dir" ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
            rm -rf "$lib_dir"
            print_success "라이브러리 디렉토리 제거: $lib_dir"
        else
            print_info "[DRY RUN] 제거될 디렉토리: $lib_dir"
        fi
    fi
}

# 설정 파일 제거
remove_config() {
    print_header "설정 파일 제거"
    
    if [[ -d "$CONFIG_DIR" ]]; then
        if [[ "$KEEP_CONFIG" == "true" ]]; then
            print_info "설정 파일 보존: $CONFIG_DIR"
        else
            if [[ "$DRY_RUN" != "true" ]]; then
                # 백업 생성
                local backup_dir="${CONFIG_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
                mv "$CONFIG_DIR" "$backup_dir"
                print_success "설정 파일 백업 후 제거: $backup_dir"
            else
                print_info "[DRY RUN] 제거될 디렉토리: $CONFIG_DIR"
            fi
        fi
    fi
}

# 로그 파일 제거
remove_logs() {
    print_header "로그 파일 제거"
    
    local log_files=(
        "${LOG_DIR}/ubuntu-disk-toolkit.log"
        "${LOG_DIR}/ubuntu-disk-toolkit-error.log"
    )
    
    if [[ "$KEEP_LOGS" == "true" ]]; then
        print_info "로그 파일 보존"
        return 0
    fi
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                rm -f "$log_file"
                print_success "로그 파일 제거: $log_file"
            else
                print_info "[DRY RUN] 제거될 파일: $log_file"
            fi
        fi
    done
    
    # logrotate 설정 제거
    local logrotate_conf="/etc/logrotate.d/ubuntu-disk-toolkit"
    if [[ -f "$logrotate_conf" ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
            rm -f "$logrotate_conf"
            print_success "logrotate 설정 제거"
        else
            print_info "[DRY RUN] 제거될 파일: $logrotate_conf"
        fi
    fi
}

# 사용자 및 그룹 제거 (필요한 경우)
remove_user_group() {
    print_header "사용자 및 그룹 확인"
    
    # 전용 사용자가 있다면 제거 (현재는 없음)
    print_info "전용 사용자/그룹이 없으므로 건너뛰기"
}

# cron 작업 제거
remove_cron_jobs() {
    print_header "cron 작업 제거"
    
    local cron_files=(
        "/etc/cron.d/ubuntu-disk-toolkit"
        "/etc/cron.daily/ubuntu-disk-toolkit"
        "/etc/cron.hourly/ubuntu-disk-toolkit"
    )
    
    for cron_file in "${cron_files[@]}"; do
        if [[ -f "$cron_file" ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                rm -f "$cron_file"
                print_success "cron 작업 제거: $cron_file"
            else
                print_info "[DRY RUN] 제거될 파일: $cron_file"
            fi
        fi
    done
}

# 메인 함수
main() {
    local keep_config=false
    local keep_logs=false
    local dry_run=false
    local force=false
    
    # 옵션 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep-config)
                keep_config=true
                shift
                ;;
            --keep-logs)
                keep_logs=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            -y|--yes)
                FORCE_YES=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "알 수 없는 옵션: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 전역 변수 설정
    export KEEP_CONFIG="$keep_config"
    export KEEP_LOGS="$keep_logs"
    export DRY_RUN="$dry_run"
    
    print_header "Ubuntu Disk Toolkit 제거"
    
    # 권한 확인
    check_permissions
    
    # 설치 상태 확인
    if ! check_installation; then
        exit 1
    fi
    
    # 사용자 확인 (force 모드가 아닌 경우)
    if [[ "$force" != "true" ]] && [[ "$dry_run" != "true" ]]; then
        confirm_action "Ubuntu Disk Toolkit을 제거하시겠습니까?"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        print_info "DRY RUN 모드: 실제로는 제거하지 않습니다"
    fi
    
    # 제거 작업 수행
    remove_systemd_services
    remove_binaries
    remove_libraries
    remove_config
    remove_logs
    remove_cron_jobs
    remove_user_group
    
    # 완료 메시지
    print_header "제거 완료"
    
    if [[ "$dry_run" == "true" ]]; then
        print_success "DRY RUN 완료: 위 파일들이 제거될 예정입니다"
        print_info "실제 제거하려면 --dry-run 옵션을 제거하세요"
    else
        print_success "🎉 Ubuntu Disk Toolkit 제거가 완료되었습니다!"
        
        if [[ "$keep_config" == "true" ]]; then
            print_info "설정 파일이 보존되었습니다: $CONFIG_DIR"
        fi
        
        if [[ "$keep_logs" == "true" ]]; then
            print_info "로그 파일이 보존되었습니다"
        fi
        
        print_info "시스템 재부팅을 권장합니다"
    fi
}

# 스크립트 실행
main "$@" 
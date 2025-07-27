#!/bin/bash

# ===================================================================================
# Ubuntu RAID CLI 설치 스크립트
# ===================================================================================

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 설정
INSTALL_PREFIX="/usr/local"
BIN_DIR="$INSTALL_PREFIX/bin"
LIB_DIR="$INSTALL_PREFIX/lib/ubuntu-disk-toolkit"
CONFIG_DIR="/etc/ubuntu-disk-toolkit"
LOG_DIR="/var/log"
BACKUP_DIR="/var/backups/ubuntu-disk-toolkit"
SYSTEMD_DIR="/etc/systemd/system"

# 현재 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 전역 변수
FORCE_YES=false

# ===================================================================================
# 인자 파싱
# ===================================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                FORCE_YES=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "알 수 없는 옵션: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    echo "Ubuntu Disk Toolkit 설치 스크립트"
    echo
    echo "사용법: $0 [옵션]"
    echo
    echo "옵션:"
    echo "  -y, --yes     모든 확인 질문에 자동으로 yes 응답"
    echo "  -h, --help    이 도움말 표시"
    echo
    echo "예시:"
    echo "  $0                # 인터랙티브 설치"
    echo "  $0 -y             # 자동 설치 (CI/CD용)"
    echo "  sudo $0 --yes     # 자동 설치 (관리자 권한)"
}

# ===================================================================================
# 유틸리티 함수
# ===================================================================================

print_header() {
    echo -e "\n${BLUE}=======================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=======================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

confirm_action() {
    local prompt="$1"
    local default_yes="${2:-false}"
    local response
    
    # Force yes 모드인 경우 자동으로 yes 반환
    if [[ "$FORCE_YES" == "true" ]]; then
        echo -e "${prompt} [y/N]: ${GREEN}y (자동)${NC}"
        return 0
    fi
    
    # Default yes인 경우 (--yes 모드에서 한 번 동의한 후)
    if [[ "$default_yes" == "true" ]]; then
        echo -e "${prompt} [Y/n]: ${GREEN}y (이전 동의)${NC}"
        return 0
    fi
    
    while true; do
        read -r -p "${prompt} [y/N]: " response
        response=${response,,}
        
        case "$response" in
            y|yes) return 0 ;;
            n|no|"") return 1 ;;
            *) echo "y 또는 n을 입력해 주세요." ;;
        esac
    done
}

# ===================================================================================
# 설치 전 검사
# ===================================================================================

check_prerequisites() {
    print_header "시스템 요구사항 검사"
    
    # 관리자 권한 확인
    if [[ $EUID -ne 0 ]]; then
        print_error "이 스크립트는 관리자(root) 권한으로 실행해야 합니다."
        echo "sudo $0 를 사용해 주세요."
        exit 1
    fi
    
    # 운영체제 확인
    if [[ ! -f /etc/os-release ]]; then
        print_error "지원하지 않는 운영체제입니다."
        exit 1
    fi
    
    # shellcheck source=/dev/null
    source /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]] && [[ "$ID_LIKE" != *"ubuntu"* ]] && [[ "$ID_LIKE" != *"debian"* ]]; then
        print_warning "공식적으로 지원하지 않는 배포판입니다: $PRETTY_NAME"
        if ! confirm_action "계속 설치하시겠습니까?"; then
            exit 1
        fi
    else
        print_success "지원되는 운영체제: $PRETTY_NAME"
    fi
    
    # Bash 버전 확인
    local bash_version="${BASH_VERSION%%.*}"
    if [[ $bash_version -lt 4 ]]; then
        print_error "Bash 4.0 이상이 필요합니다. 현재 버전: $BASH_VERSION"
        exit 1
    fi
    print_success "Bash 버전: $BASH_VERSION"
}

check_dependencies() {
    print_header "필수 패키지 확인 및 설치"
    
    local required_packages=("mdadm" "smartmontools" "util-linux" "parted")
    local missing_packages=()
    
    # 각 패키지 확인
    for package in "${required_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        else
            print_success "$package 설치됨"
        fi
    done
    
    # 누락된 패키지 설치
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        print_info "누락된 패키지를 설치합니다: ${missing_packages[*]}"
        
        if confirm_action "패키지를 설치하시겠습니까?"; then
            apt update
            # shellcheck disable=SC2068
            apt install -y ${missing_packages[@]}
            print_success "필수 패키지 설치 완료"
        else
            print_error "필수 패키지가 설치되지 않았습니다."
            exit 1
        fi
    else
        print_success "모든 필수 패키지가 설치되어 있습니다"
    fi
}

# ===================================================================================
# 설치 함수
# ===================================================================================

create_directories() {
    print_header "디렉토리 생성"
    
    local directories=(
        "$BIN_DIR"
        "$LIB_DIR"
        "$CONFIG_DIR"
        "$BACKUP_DIR"
        "$LOG_DIR"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            print_success "디렉토리 생성: $dir"
        else
            print_info "디렉토리 존재: $dir"
        fi
    done
}

install_scripts() {
    print_header "스크립트 설치"
    
    # 실행 파일 설치
    local bin_files=(
        "ubuntu-disk-toolkit"
        "check-disk-health"
        "manage-raid"
        "auto-monitor"
    )
    
    for file in "${bin_files[@]}"; do
        local src="$PROJECT_DIR/bin/$file"
        local dst="$BIN_DIR/$file"
        
        if [[ -f "$src" ]]; then
            cp "$src" "$dst"
            chmod +x "$dst"
            print_success "설치됨: $file"
        else
            print_warning "파일 없음: $src"
        fi
    done
    
    # 라이브러리 파일 설치
    if [[ -d "$PROJECT_DIR/lib" ]]; then
        cp -r "$PROJECT_DIR/lib/"* "$LIB_DIR/"
        chmod +x "$LIB_DIR/"*.sh
        print_success "라이브러리 파일 설치 완료"
    fi
}

install_config() {
    print_header "설정 파일 설치"
    
    local config_src="$PROJECT_DIR/config/defaults.conf"
    local config_dst="$CONFIG_DIR/defaults.conf"
    
    if [[ -f "$config_src" ]]; then
        if [[ -f "$config_dst" ]]; then
            # 기존 설정 파일 백업
            local backup_file="$config_dst.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$config_dst" "$backup_file"
            print_info "기존 설정 파일 백업: $backup_file"
            
            if ! confirm_action "기존 설정 파일을 덮어쓰시겠습니까?"; then
                print_info "설정 파일 설치를 건너뜁니다."
                return 0
            fi
        fi
        
        cp "$config_src" "$config_dst"
        chmod 644 "$config_dst"
        print_success "설정 파일 설치: $config_dst"
    else
        print_warning "설정 파일을 찾을 수 없습니다: $config_src"
    fi
}

setup_logging() {
    print_header "로깅 설정"
    
    # 로그 파일 생성
    local log_file="/var/log/ubuntu-disk-toolkit.log"
    touch "$log_file"
    chmod 644 "$log_file"
    
    # logrotate 설정
    cat > /etc/logrotate.d/ubuntu-disk-toolkit << 'EOF'
/var/log/ubuntu-disk-toolkit.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF
    
    print_success "로깅 설정 완료"
}

create_systemd_service() {
    print_header "시스템 서비스 생성"
    
    # 모니터링 서비스 생성
    cat > "$SYSTEMD_DIR/ubuntu-raid-monitor.service" << EOF
[Unit]
Description=Ubuntu RAID Monitor
After=multi-user.target

[Service]
Type=simple
User=root
ExecStart=$BIN_DIR/auto-monitor
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # 타이머 서비스 생성 (주기적 검사)
    cat > "$SYSTEMD_DIR/ubuntu-raid-check.service" << EOF
[Unit]
Description=Ubuntu RAID Health Check
After=multi-user.target

[Service]
Type=oneshot
User=root
ExecStart=$BIN_DIR/check-disk-health
EOF

    cat > "$SYSTEMD_DIR/ubuntu-raid-check.timer" << EOF
[Unit]
Description=Run Ubuntu RAID Health Check daily
Requires=ubuntu-raid-check.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    print_success "시스템 서비스 생성 완료"
    
    # 서비스 활성화 여부 확인
    if confirm_action "모니터링 서비스를 활성화하시겠습니까?"; then
        systemctl daemon-reload
        systemctl enable ubuntu-raid-check.timer
        systemctl start ubuntu-raid-check.timer
        print_success "모니터링 서비스 활성화됨"
    fi
}

update_system_path() {
    print_header "시스템 PATH 업데이트"
    
    # /usr/local/bin은 보통 기본 PATH에 포함되어 있음
    if echo "$PATH" | grep -q "$BIN_DIR"; then
        print_success "PATH에 이미 포함되어 있습니다: $BIN_DIR"
    else
        print_info "PATH에 $BIN_DIR 추가가 필요할 수 있습니다"
        echo "다음 명령어를 실행하거나 ~/.bashrc에 추가하세요:"
        echo "export PATH=\"$BIN_DIR:\$PATH\""
    fi
}

# ===================================================================================
# 설치 후 검증
# ===================================================================================

verify_installation() {
    print_header "설치 검증"
    
    local errors=0
    
    # 실행 파일 확인
    for cmd in ubuntu-disk-toolkit check-disk-health; do
        if command -v "$cmd" &> /dev/null; then
            print_success "$cmd 명령어 사용 가능"
        else
            print_error "$cmd 명령어를 찾을 수 없습니다"
            ((errors++))
        fi
    done
    
    # 설정 파일 확인
    if [[ -f "$CONFIG_DIR/defaults.conf" ]]; then
        print_success "설정 파일 존재"
    else
        print_error "설정 파일이 없습니다"
        ((errors++))
    fi
    
    # 권한 확인
    if [[ -x "$BIN_DIR/ubuntu-disk-toolkit" ]]; then
        print_success "실행 권한 설정됨"
    else
        print_error "실행 권한이 없습니다"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_success "설치 검증 완료"
        return 0
    else
        print_error "설치 검증 실패: $errors개 오류"
        return 1
    fi
}

show_completion_message() {
    print_header "설치 완료"
    
    cat << EOF

${GREEN}Ubuntu RAID CLI가 성공적으로 설치되었습니다!${NC}

사용법:
  ubuntu-disk-toolkit --help          도움말 보기
  ubuntu-disk-toolkit list-disks      디스크 목록 확인
  check-disk-health               시스템 진단 실행

설치 위치:
  실행 파일: $BIN_DIR
  라이브러리: $LIB_DIR  
  설정 파일: $CONFIG_DIR
  로그 파일: /var/log/ubuntu-disk-toolkit.log

시스템 서비스:
  sudo systemctl status ubuntu-raid-check.timer

예시:
  ubuntu-disk-toolkit list-disks
  ubuntu-disk-toolkit setup-raid --level 1 --disks /dev/sda,/dev/sdb
  check-disk-health

EOF

    print_info "문제가 발생하면 로그 파일을 확인하세요: /var/log/ubuntu-disk-toolkit.log"
}

# ===================================================================================
# 메인 실행
# ===================================================================================

main() {
    # 인자 파싱
    parse_arguments "$@"
    
    print_header "Ubuntu RAID CLI 설치 시작"
    
    # 설치 전 검사
    check_prerequisites
    check_dependencies
    
    # 설치 확인
    if ! confirm_action "Ubuntu RAID CLI를 설치하시겠습니까?"; then
        print_info "설치가 취소되었습니다."
        exit 0
    fi
    
    # 한 번 동의했으므로 이후 단계는 자동 진행
    if [[ "$FORCE_YES" != "true" ]]; then
        FORCE_YES=true
        print_info "✅ 설치 진행 중... 나머지 단계는 자동으로 진행됩니다."
    fi
    
    # 설치 실행
    create_directories
    install_scripts
    install_config
    setup_logging
    create_systemd_service
    update_system_path
    
    # 검증 및 완료
    if verify_installation; then
        show_completion_message
    else
        print_error "설치 중 문제가 발생했습니다."
        exit 1
    fi
}

# 스크립트 실행
main "$@" 
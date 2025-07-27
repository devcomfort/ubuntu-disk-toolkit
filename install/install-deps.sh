#!/bin/bash

# ===================================================================================
# install-deps.sh - Ubuntu Disk Toolkit 의존성 설치 스크립트
# ===================================================================================

set -euo pipefail

# 색상 출력 설정
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

install-deps.sh - Ubuntu Disk Toolkit 의존성 설치

사용법:
  ./install-deps.sh [옵션]

옵션:
  --check-only    설치하지 않고 확인만
  --minimal       최소 의존성만 설치
  --dev           개발용 의존성 포함
  --quiet         최소 출력
  -h, --help      도움말 표시

예시:
  ./install-deps.sh              # 기본 의존성 설치
  ./install-deps.sh --dev        # 개발 의존성 포함
  ./install-deps.sh --check-only # 확인만 수행

EOF
}

# 시스템 호환성 확인
check_system_compatibility() {
    print_header "시스템 호환성 확인"
    
    # OS 확인
    if [[ ! -f /etc/os-release ]]; then
        print_error "지원하지 않는 운영체제입니다"
        exit 1
    fi
    
    source /etc/os-release
    
    case "${ID,,}" in
        ubuntu|debian)
            print_success "지원되는 운영체제: $PRETTY_NAME"
            ;;
        *)
            print_warning "테스트되지 않은 운영체제: $PRETTY_NAME"
            print_info "Debian 계열이므로 작동할 수 있습니다"
            ;;
    esac
    
    # Kernel 버전 확인
    local kernel_version=$(uname -r)
    print_success "커널 버전: $kernel_version"
    
    # 아키텍처 확인
    local arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            print_success "지원되는 아키텍처: $arch"
            ;;
        *)
            print_warning "테스트되지 않은 아키텍처: $arch"
            ;;
    esac
}

# 패키지 관리자 확인
check_package_manager() {
    if command -v apt &> /dev/null; then
        print_success "패키지 관리자: apt 발견"
        return 0
    elif command -v apt-get &> /dev/null; then
        print_success "패키지 관리자: apt-get 발견"
        return 0
    else
        print_error "apt 패키지 관리자를 찾을 수 없습니다"
        print_info "이 스크립트는 Debian/Ubuntu 계열 시스템용입니다"
        return 1
    fi
}

# 필수 도구 목록 정의
declare -A REQUIRED_PACKAGES=(
    ["mdadm"]="Software RAID 관리"
    ["smartmontools"]="디스크 SMART 정보"
    ["util-linux"]="디스크 유틸리티 (lsblk, findmnt 등)"
    ["parted"]="파티션 관리"
    ["e2fsprogs"]="ext 파일시스템 도구"
)

declare -A OPTIONAL_PACKAGES=(
    ["xfsprogs"]="XFS 파일시스템 지원"
    ["btrfs-progs"]="Btrfs 파일시스템 지원"
    ["dosfstools"]="FAT 파일시스템 지원"
    ["tree"]="디렉토리 구조 표시"
)

declare -A DEV_PACKAGES=(
    ["shellcheck"]="Bash 스크립트 정적 분석"
    ["bats"]="Bash 테스팅 프레임워크"
    ["jq"]="JSON 처리 도구"
    ["curl"]="HTTP 클라이언트"
)

# 패키지 설치 상태 확인
check_package() {
    local package="$1"
    if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
        return 0  # 설치됨
    else
        return 1  # 설치되지 않음
    fi
}

# 패키지 목록 확인
check_packages() {
    local -n packages=$1
    local category="$2"
    local missing_packages=()
    
    print_header "$category 패키지 확인"
    
    for package in "${!packages[@]}"; do
        local description="${packages[$package]}"
        if check_package "$package"; then
            print_success "$package - $description"
        else
            print_warning "$package - $description (누락)"
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        print_success "모든 $category 패키지가 설치되어 있습니다"
        return 0
    else
        print_info "누락된 패키지: ${missing_packages[*]}"
        printf '%s\n' "${missing_packages[@]}"
        return 1
    fi
}

# 패키지 설치
install_packages() {
    local -n packages=$1
    local category="$2"
    local missing_packages
    
    # 누락된 패키지 목록 가져오기
    if ! missing_packages=$(check_packages packages "$category" 2>/dev/null | tail -n +1 | grep -v "✅\|⚠️\|ℹ️" || true); then
        if [[ -n "$missing_packages" ]]; then
            print_header "$category 패키지 설치"
            
            # 권한 확인
            if [[ $EUID -ne 0 ]]; then
                print_error "패키지 설치에는 관리자 권한이 필요합니다"
                print_info "다음 명령어를 실행하세요:"
                echo "sudo $0 $*"
                exit 1
            fi
            
            # 패키지 목록 업데이트
            print_info "패키지 목록 업데이트 중..."
            if apt update > /dev/null 2>&1; then
                print_success "패키지 목록 업데이트 완료"
            else
                print_error "패키지 목록 업데이트 실패"
                return 1
            fi
            
            # 패키지 설치
            local install_list=()
            for package in "${!packages[@]}"; do
                if ! check_package "$package"; then
                    install_list+=("$package")
                fi
            done
            
            if [[ ${#install_list[@]} -gt 0 ]]; then
                print_info "설치할 패키지: ${install_list[*]}"
                if apt install -y "${install_list[@]}"; then
                    print_success "$category 패키지 설치 완료"
                else
                    print_error "$category 패키지 설치 실패"
                    return 1
                fi
            fi
        fi
    fi
    
    return 0
}

# Just 설치
install_just() {
    print_header "Just 빌드 도구 확인"
    
    if command -v just &> /dev/null; then
        print_success "Just 이미 설치됨: $(just --version)"
        return 0
    fi
    
    print_info "Just 설치 중..."
    
    # 여러 설치 방법 시도
    if command -v cargo &> /dev/null; then
        print_info "Cargo를 통해 Just 설치 중..."
        if cargo install just; then
            print_success "Cargo를 통해 Just 설치 완료"
            return 0
        fi
    fi
    
    # GitHub에서 직접 설치
    print_info "GitHub에서 Just 바이너리 다운로드 중..."
    local just_version="1.14.0"
    local arch=$(uname -m)
    local os="unknown-linux-musl"
    
    case "$arch" in
        x86_64) arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        *) 
            print_warning "지원하지 않는 아키텍처: $arch"
            print_info "수동으로 Just를 설치해주세요: https://github.com/casey/just"
            return 1
            ;;
    esac
    
    local download_url="https://github.com/casey/just/releases/download/${just_version}/just-${just_version}-${arch}-${os}.tar.gz"
    local temp_dir=$(mktemp -d)
    
    if curl -sL "$download_url" | tar -xz -C "$temp_dir"; then
        if [[ $EUID -eq 0 ]]; then
            mv "$temp_dir/just" /usr/local/bin/
            chmod +x /usr/local/bin/just
            print_success "Just 설치 완료: /usr/local/bin/just"
        else
            mkdir -p "$HOME/.local/bin"
            mv "$temp_dir/just" "$HOME/.local/bin/"
            chmod +x "$HOME/.local/bin/just"
            print_success "Just 설치 완료: $HOME/.local/bin/just"
            print_info "PATH에 $HOME/.local/bin을 추가해주세요"
        fi
        rm -rf "$temp_dir"
        return 0
    else
        print_error "Just 다운로드 실패"
        rm -rf "$temp_dir"
        return 1
    fi
}

# 메인 함수
main() {
    local check_only=false
    local minimal=false
    local dev_mode=false
    local quiet=false
    
    # 옵션 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check-only)
                check_only=true
                shift
                ;;
            --minimal)
                minimal=true
                shift
                ;;
            --dev)
                dev_mode=true
                shift
                ;;
            --quiet)
                quiet=true
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
    
    if [[ "$quiet" != "true" ]]; then
        print_header "Ubuntu Disk Toolkit 의존성 설치"
    fi
    
    # 시스템 호환성 확인
    check_system_compatibility
    
    # 패키지 관리자 확인
    if ! check_package_manager; then
        exit 1
    fi
    
    # 확인만 모드
    if [[ "$check_only" == "true" ]]; then
        print_header "의존성 확인 모드"
        
        check_packages REQUIRED_PACKAGES "필수"
        
        if [[ "$minimal" != "true" ]]; then
            check_packages OPTIONAL_PACKAGES "선택적"
        fi
        
        if [[ "$dev_mode" == "true" ]]; then
            check_packages DEV_PACKAGES "개발"
        fi
        
        print_info "확인 완료. 설치하려면 --check-only 옵션을 제거하세요"
        exit 0
    fi
    
    # 의존성 설치
    print_header "의존성 설치 시작"
    
    # 필수 패키지 설치
    if ! install_packages REQUIRED_PACKAGES "필수"; then
        print_error "필수 패키지 설치 실패"
        exit 1
    fi
    
    # 선택적 패키지 설치 (minimal 모드가 아닌 경우)
    if [[ "$minimal" != "true" ]]; then
        install_packages OPTIONAL_PACKAGES "선택적" || print_warning "일부 선택적 패키지 설치 실패"
    fi
    
    # 개발 패키지 설치
    if [[ "$dev_mode" == "true" ]]; then
        install_packages DEV_PACKAGES "개발" || print_warning "일부 개발 패키지 설치 실패"
        
        # Just 설치
        install_just || print_warning "Just 설치 실패"
    fi
    
    print_header "설치 완료"
    print_success "🎉 Ubuntu Disk Toolkit 의존성 설치가 완료되었습니다!"
    
    if [[ "$dev_mode" == "true" ]]; then
        print_info "개발 환경이 준비되었습니다. 다음 명령어로 시작하세요:"
        echo "  just setup"
        echo "  just test"
    else
        print_info "다음 명령어로 설치를 완료하세요:"
        echo "  sudo ./install/install.sh"
    fi
}

# 스크립트 실행
main "$@" 
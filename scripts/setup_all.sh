#!/bin/bash
# PURPOSE: 모든 필요한 패키지를 설치하고 프로젝트를 설정하는 스크립트
#          Standalone 바이너리 빌드 스크립트를 호출하여 바이너리를 빌드하고 설치합니다.

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# root 권한 확인
if [ "$EUID" -ne 0 ]; then
    log_error "이 스크립트는 root 권한으로 실행해야 합니다."
    log_info "다음 명령어로 다시 실행해주세요: sudo $0"
    exit 1
fi

# 현재 디렉토리가 프로젝트 루트인지 확인
if [ ! -f "pyproject.toml" ]; then
    log_error "pyproject.toml 파일을 찾을 수 없습니다."
    log_error "프로젝트 루트 디렉토리에서 이 스크립트를 실행해주세요."
    exit 1
fi

# 필요한 패키지 목록
PACKAGES=(
    "mdadm"           # RAID 관리
    "smartmontools"   # 디스크 건강 상태 확인
    "python3-pip"     # Python 패키지 관리
    "python3-venv"    # Python 가상환경
)

# 시스템 업데이트
log_info "시스템 패키지 정보를 업데이트합니다..."
apt-get update

# 각 패키지 설치 상태 확인 및 설치
for package in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        log_info "$package 패키지가 이미 설치되어 있습니다."
    else
        log_info "$package 패키지를 설치합니다..."
        if apt-get install -y "$package"; then
            log_info "$package 패키지가 성공적으로 설치되었습니다."
        else
            log_error "$package 패키지 설치에 실패했습니다."
            exit 1
        fi
    fi
done

# Rye 확인
if ! command -v rye &> /dev/null; then
    log_warn "Rye가 설치되어 있지 않습니다. 설치를 진행합니다..."
    
    # Rye 설치
    curl -sSf https://rye.astral.sh/get | bash
    
    # PATH에 Rye 추가
    source ~/.bashrc
    
    if ! command -v rye &> /dev/null; then
        log_error "Rye 설치 후에도 명령어를 찾을 수 없습니다."
        log_info "Rye를 수동으로 설치한 후 다시 시도해주세요:"
        log_info "curl -sSf https://rye.astral.sh/get | bash"
        exit 1
    fi
fi

# 의존성 동기화
log_info "의존성을 동기화하는 중..."
if ! rye sync; then
    log_error "의존성 동기화에 실패했습니다."
    exit 1
fi

# 빌드 수행
log_info "프로젝트 빌드를 시작합니다..."
if ! rye build; then
    log_error "빌드에 실패했습니다."
    exit 1
fi

# 설치
log_info "Ubuntu RAID CLI를 설치합니다..."
if ! pip3 install dist/*.whl; then
    log_error "설치에 실패했습니다."
    exit 1
fi

log_info "설치가 완료되었습니다!"
log_info "이제 'raid' 명령어를 사용할 수 있습니다."

# 권한 설정
log_info "sudo 없이도 'raid' 명령을 실행할 수 있도록 설정합니다..."
chmod +s $(which raid)

log_info "설정 완료! 'raid' 명령어를 사용하여 Ubuntu RAID CLI 도구를 시작하세요." 
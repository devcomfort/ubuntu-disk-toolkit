#!/bin/bash

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

# Python 의존성 설치
if command -v rye &> /dev/null; then
    log_info "Python 의존성을 설치합니다..."
    if rye sync; then
        log_info "Python 의존성이 성공적으로 설치되었습니다."
    else
        log_error "Python 의존성 설치에 실패했습니다."
        exit 1
    fi
else
    log_warn "Rye가 설치되어 있지 않습니다."
    log_info "Rye 설치 방법:"
    log_info "curl -sSf https://rye.astral.sh/get | bash"
    exit 1
fi

log_info "모든 필요한 패키지가 설치되었습니다."
log_info "이제 'raid' 명령어를 사용할 수 있습니다." 
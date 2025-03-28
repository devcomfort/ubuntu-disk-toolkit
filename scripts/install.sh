#!/bin/bash

# PURPOSE: 설치 스크립트 (wget/curl)

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# 설치 방법 파싱
INSTALL_METHOD=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --method)
            INSTALL_METHOD="$2"
            shift 2
            ;;
        --auto)
            INSTALL_METHOD="pip"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# 설치 방법 선택
log_info "Ubuntu RAID CLI 설치 프로그램"

if [ -n "$INSTALL_METHOD" ]; then
    case $INSTALL_METHOD in
        pip)
            log_info "명령형 설치: pip를 통한 설치를 진행합니다."
            install_method=1
            ;;
        binary)
            log_info "명령형 설치: 바이너리 설치를 진행합니다."
            install_method=2
            ;;
        *)
            log_error "지원하지 않는 설치 방법입니다: $INSTALL_METHOD"
            log_info "지원하는 설치 방법: pip, binary"
            exit 1
            ;;
    esac
else
    log_info "설치 방법을 선택하세요:"
    log_info "1) pip를 통한 설치 (권장)"
    log_info "2) 바이너리 직접 설치"
    log_info "3) 자동 설치 (pip 사용)"

    read -p "선택 (1-3, 기본값: 1): " install_method
    install_method=${install_method:-1}  # 기본값 설정
fi

case $install_method in
    1|3)
        log_info "pip를 통한 설치를 시작합니다..."
        
        # 필요한 시스템 패키지 설치
        if [ "$EUID" -ne 0 ]; then
            log_error "이 설치 방법은 root 권한이 필요합니다."
            log_info "다음 명령어로 다시 실행해주세요: sudo $0"
            exit 1
        fi

        # 필요한 패키지 설치
        log_info "필요한 시스템 패키지를 설치합니다..."
        apt-get update
        apt-get install -y python3-venv python3-full

        # 가상환경 생성
        VENV_DIR="/opt/ubuntu-raid-cli"
        log_info "가상환경을 생성합니다: $VENV_DIR"
        mkdir -p "$VENV_DIR"
        python3 -m venv "$VENV_DIR"

        # 가상환경 활성화 및 패키지 설치
        log_info "패키지를 설치합니다..."
        "$VENV_DIR/bin/pip" install ubuntu-raid-cli

        # 실행 스크립트 생성
        log_info "실행 스크립트를 생성합니다..."
        cat > /usr/local/bin/raid << EOF
#!/bin/bash
"$VENV_DIR/bin/raid" "\$@"
EOF
        chmod +x /usr/local/bin/raid

        log_info "설치가 완료되었습니다!"
        log_info "이제 'raid' 명령어를 사용할 수 있습니다."
        ;;
    2)
        log_info "바이너리 설치를 시작합니다..."
        # root 권한 확인
        if [ "$EUID" -ne 0 ]; then
            log_error "이 설치 방법은 root 권한이 필요합니다."
            log_info "다음 명령어로 다시 실행해주세요: sudo $0"
            exit 1
        fi

        # 필요한 패키지 설치
        log_info "필요한 시스템 패키지를 설치합니다..."
        apt-get update
        apt-get install -y mdadm smartmontools

        # 최신 릴리즈 다운로드
        RELEASE_URL="https://github.com/devcomfort/ubuntu-raid-cli/releases/latest/download/ubuntu-raid-cli-standalone.tar.gz"
        log_info "최신 릴리즈를 다운로드합니다..."
        
        if command -v wget &> /dev/null; then
            wget -O ubuntu-raid-cli.tar.gz "$RELEASE_URL"
        elif command -v curl &> /dev/null; then
            curl -L -o ubuntu-raid-cli.tar.gz "$RELEASE_URL"
        else
            log_error "wget 또는 curl이 설치되어 있지 않습니다."
            log_info "다음 명령어로 설치해주세요:"
            log_info "sudo apt-get install wget"
            exit 1
        fi

        # 압축 해제 및 설치
        tar -xzvf ubuntu-raid-cli.tar.gz
        cp raid-cli /usr/local/bin/
        chmod +x /usr/local/bin/raid-cli

        # 정리
        rm -f ubuntu-raid-cli.tar.gz raid-cli

        log_info "설치가 완료되었습니다!"
        log_info "이제 'raid-cli' 명령어를 사용할 수 있습니다."
        ;;
    *)
        log_error "잘못된 선택입니다."
        exit 1
        ;;
esac 
#!/bin/bash

# ===================================================================================
# common.sh - 공통 유틸리티 함수 라이브러리
# ===================================================================================

# 색상 코드 정의 (중복 정의 방지)
if [[ -z "${RED:-}" ]]; then
    if [[ "${NO_COLOR:-}" == "1" ]] || [[ -n "${NO_COLOR:-}" ]]; then
        # NO_COLOR가 설정된 경우 색상 코드를 빈 문자열로 설정
        declare -r RED=''
        declare -r GREEN=''
        declare -r YELLOW=''
        declare -r BLUE=''
        declare -r CYAN=''
        declare -r BOLD=''
        declare -r NC=''
    else
        declare -r RED='\033[0;31m'
        declare -r GREEN='\033[0;32m'
        declare -r YELLOW='\033[0;33m'
        declare -r BLUE='\033[0;34m'
        declare -r CYAN='\033[0;36m'
        declare -r BOLD='\033[1m'
        declare -r NC='\033[0m' # No Color
    fi
fi

# 전역 변수
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/defaults.conf"

# 로깅 설정
LOG_FILE="/var/log/ubuntu-disk-toolkit.log"
DEBUG_MODE=false

# ===================================================================================
# 출력 및 로깅 함수
# ===================================================================================

# 헤더 출력
print_header() {
    local title="$1"
    echo -e "\n${BLUE}=======================================================================${NC}"
    echo -e "${BLUE}  ${title}${NC}"
    echo -e "${BLUE}=======================================================================${NC}"
}

# 성공 메시지 출력
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    log_message "SUCCESS" "$1"
}

# 경고 메시지 출력
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log_message "WARNING" "$1"
}

# 오류 메시지 출력
print_error() {
    echo -e "${RED}✗ $1${NC}" >&2
    log_message "ERROR" "$1"
}

# 정보 메시지 출력
print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
    log_message "INFO" "$1"
}

# 디버그 메시지 출력
print_debug() {
    [[ "$DEBUG_MODE" == "true" ]] && echo -e "${BLUE}[DEBUG] $1${NC}"
    log_message "DEBUG" "$1"
}

# 로그 메시지 기록
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 로그 디렉토리가 없으면 생성 (테스트 모드가 아닐 때만 sudo 사용)
    if [[ ! -d "$(dirname "$LOG_FILE")" ]]; then
        if [[ "${TESTING_MODE:-}" == "true" ]]; then
            mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        else
            sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        fi
    fi
    
    # 로그 파일에 기록 (권한이 있을 때만)
    if [[ -w "$(dirname "$LOG_FILE")" ]] || [[ -w "$LOG_FILE" ]] 2>/dev/null; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# ===================================================================================
# 시스템 검증 함수
# ===================================================================================

# 관리자 권한 확인
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_error "이 작업은 관리자(root) 권한이 필요합니다. 'sudo'를 사용해 주세요."
        exit 1
    fi
}

# 필수 명령어 확인
check_required_commands() {
    local missing_commands=()
    
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        print_error "다음 필수 명령어들이 설치되지 않았습니다: ${missing_commands[*]}"
        print_info "다음 명령어로 설치하세요:"
        echo "  sudo apt update && sudo apt install -y mdadm smartmontools util-linux"
        exit 1
    fi
}

# 디스크 존재 여부 확인
check_disk_exists() {
    local disk="$1"
    
    if [[ ! -b "$disk" ]]; then
        print_error "디스크 '$disk'를 찾을 수 없습니다."
        return 1
    fi
    return 0
}

# ===================================================================================
# 유틸리티 함수
# ===================================================================================

# 안전한 명령어 실행
safe_execute() {
    local cmd="$*"
    
    print_debug "실행 중: $cmd"
    
    if eval "$cmd"; then
        print_debug "명령어 성공: $cmd"
        return 0
    else
        local exit_code=$?
        print_error "명령어 실패 (exit code: $exit_code): $cmd"
        return $exit_code
    fi
}

# 사용자 확인 (기본값: No)
confirm_action() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    if [[ "$default" == "y" ]]; then
        prompt="${prompt} [Y/n]: "
    else
        prompt="${prompt} [y/N]: "
    fi
    
    while true; do
        read -r -p "$prompt" response
        response=${response,,} # 소문자로 변환
        
        if [[ -z "$response" ]]; then
            response="$default"
        fi
        
        case "$response" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "y 또는 n을 입력해 주세요." ;;
        esac
    done
}

# 설정 파일 로드
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        print_debug "설정 파일 로드됨: $CONFIG_FILE"
    else
        print_warning "설정 파일을 찾을 수 없습니다: $CONFIG_FILE"
    fi
}

# 진행률 표시
show_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    
    printf "\r${CYAN}%s [" "$description"
    printf "%*s" $completed | tr ' ' '='
    printf "%*s" $((width - completed))
    printf "] %d%% (%d/%d)${NC}" "$percentage" "$current" "$total"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# 백업 생성
create_backup() {
    local file="$1"
    local backup_dir
    
    # 테스트 모드일 때는 테스트 임시 디렉토리 사용
    if [[ "${TESTING_MODE:-}" == "true" && -n "${TEST_TEMP_DIR:-}" ]]; then
        backup_dir="${TEST_TEMP_DIR}"
    else
        backup_dir="${PROJECT_ROOT}/backups"
    fi
    
    if [[ ! -f "$file" ]]; then
        print_error "백업할 파일이 존재하지 않습니다: $file"
        return 1
    fi
    
    mkdir -p "$backup_dir"
    local backup_file="${backup_dir}/$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
    
    if cp "$file" "$backup_file"; then
        print_success "백업 생성됨: $backup_file"
        echo "$backup_file"
        return 0
    else
        print_error "백업 생성 실패: $file"
        return 1
    fi
}

# 임시 파일 정리
cleanup_temp_files() {
    local temp_pattern="${1:-/tmp/ubuntu-disk-toolkit.*}"
    
    # TEMP_FILES 배열이 설정되어 있으면 해당 파일들 삭제 (테스트용)
    if [[ -n "${TEMP_FILES:-}" ]]; then
        for file in "${TEMP_FILES[@]}"; do
            [[ -f "$file" ]] && rm -f "$file" 2>/dev/null
        done
        print_debug "TEMP_FILES 배열의 임시 파일들 정리 완료"
    else
        # 기본 패턴으로 임시 파일 삭제
        # shellcheck disable=SC2086
        rm -f $temp_pattern 2>/dev/null || true
        print_debug "임시 파일 정리 완료"
    fi
}

# 스크립트 종료 시 정리 작업
cleanup_on_exit() {
    cleanup_temp_files
    print_debug "스크립트 종료 시 정리 작업 완료"
}

# 신호 처리 설정
setup_signal_handlers() {
    trap cleanup_on_exit EXIT
    trap 'print_error "중단됨 (Ctrl+C)"; exit 130' INT
    trap 'print_error "종료됨 (TERM)"; exit 143' TERM
}

# ===================================================================================
# 초기화
# ===================================================================================

# 공통 초기화
init_common() {
    # 설정 로드
    load_config
    
    # 신호 처리 설정
    setup_signal_handlers
    
    # 디버그 모드 설정
    if [[ "${DEBUG:-}" == "1" ]] || [[ "${VERBOSE:-}" == "1" ]]; then
        DEBUG_MODE=true
    fi
    
    print_debug "공통 라이브러리 초기화 완료"
} 
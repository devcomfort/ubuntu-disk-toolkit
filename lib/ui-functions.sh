#!/bin/bash

# ===================================================================================
# ui-functions.sh - UI 및 출력 관련 함수 라이브러리
# ===================================================================================

# 공통 라이브러리 로드 (색상 상수 충돌 방지)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${RED:-}" ]]; then
    # shellcheck source=lib/common.sh
    source "${SCRIPT_DIR}/common.sh"
fi

# ===================================================================================
# 테이블 출력 함수
# ===================================================================================

# 테이블 헤더 시작
table_start() {
    local title="$1"
    echo -e "\n${BOLD}${CYAN}$title${NC}"
    echo -e "${BLUE}$(printf '%.0s─' {1..80})${NC}"
}

# 테이블 행 출력
table_row() {
    local col1="$1"
    local col2="$2"
    local col3="${3:-}"
    local col4="${4:-}"
    
    if [[ -n "$col4" ]]; then
        printf "%-20s %-20s %-20s %-15s\n" "$col1" "$col2" "$col3" "$col4"
    elif [[ -n "$col3" ]]; then
        printf "%-25s %-30s %-20s\n" "$col1" "$col2" "$col3"
    else
        printf "%-30s %-45s\n" "$col1" "$col2"
    fi
}

# 테이블 구분선
table_separator() {
    echo -e "${BLUE}$(printf '%.0s─' {1..80})${NC}"
}

# 테이블 종료
table_end() {
    echo -e "${BLUE}$(printf '%.0s─' {1..80})${NC}\n"
}

# ===================================================================================
# 상태 표시 함수
# ===================================================================================

# 상태에 따른 색상 반환
get_status_color() {
    local status="$1"
    
    case "${status,,}" in
        "healthy"|"passed"|"ok"|"active"|"clean"|"optimal")
            echo "$GREEN"
            ;;
        "warning"|"degraded"|"rebuilding"|"syncing")
            echo "$YELLOW"
            ;;
        "error"|"failed"|"critical"|"offline"|"faulty")
            echo "$RED"
            ;;
        *)
            echo "$NC"
            ;;
    esac
}

# 상태 아이콘 반환
get_status_icon() {
    local status="$1"
    
    case "${status,,}" in
        "healthy"|"passed"|"ok"|"active"|"clean"|"optimal")
            echo "✓"
            ;;
        "warning"|"degraded"|"rebuilding"|"syncing")
            echo "⚠"
            ;;
        "error"|"failed"|"critical"|"offline"|"faulty")
            echo "✗"
            ;;
        *)
            echo "?"
            ;;
    esac
}

# 컬러 상태 출력
print_status() {
    local status="$1"
    local message="$2"
    local icon
    local color
    
    icon=$(get_status_icon "$status")
    color=$(get_status_color "$status")
    
    echo -e "${color}${icon} ${message}${NC}"
}

# 단계별 진행 상황 표시 함수
print_step() {
    local step="$1"
    local message="$2"
    local color="${BLUE}"
    
    echo -e "${color}📋 [${step}] ${message}${NC}"
}

# ===================================================================================
# 메뉴 및 선택 함수
# ===================================================================================

# 선택 메뉴 표시
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    
    echo -e "\n${BOLD}${CYAN}$title${NC}"
    table_separator
    
    for i in "${!options[@]}"; do
        printf "%2d) %s\n" $((i + 1)) "${options[i]}"
    done
    
    table_separator
}

# 사용자 선택 받기
get_user_choice() {
    local prompt="$1"
    local max_choice="$2"
    local choice
    
    while true; do
        read -r -p "${prompt} (1-${max_choice}): " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$max_choice" ]]; then
            echo "$choice"
            return 0
        else
            print_error "1부터 ${max_choice} 사이의 숫자를 입력해 주세요."
        fi
    done
}

# 다중 선택 메뉴
show_multi_select() {
    local title="$1"
    shift
    local options=("$@")
    local selected=()
    
    echo -e "\n${BOLD}${CYAN}$title${NC}"
    print_info "스페이스로 선택/해제, Enter로 완료, q로 취소"
    table_separator
    
    # TODO: 실제 다중 선택 UI 구현 (고급 기능)
    # 현재는 간단한 버전으로 구현
    for i in "${!options[@]}"; do
        printf "%2d) [ ] %s\n" $((i + 1)) "${options[i]}"
    done
    
    table_separator
    echo "다중 선택 UI는 추후 구현 예정입니다."
}

# ===================================================================================
# 디스크 정보 표시 함수
# ===================================================================================

# 디스크 목록 테이블 출력
show_disk_table() {
    local -a disks=("$@")
    
    table_start "디스크 목록"
    table_row "디바이스" "크기" "타입" "상태"
    table_separator
    
    for disk in "${disks[@]}"; do
        # 디스크 정보 파싱 (실제 구현 시 disk-functions.sh의 함수 사용)
        local device="${disk%%:*}"
        local size="${disk#*:}"
        local type="Unknown"
        local status="Unknown"
        
        table_row "$device" "$size" "$type" "$status"
    done
    
    table_end
}

# RAID 상태 테이블 출력
show_raid_table() {
    local raid_device="$1"
    local raid_info="$2"
    
    table_start "RAID $raid_device 상태"
    table_row "속성" "값"
    table_separator
    
    # raid_info는 "key:value" 형태의 문자열들이 줄바꿈으로 구분됨
    while IFS=':' read -r key value; do
        [[ -n "$key" && -n "$value" ]] && table_row "$key" "$value"
    done <<< "$raid_info"
    
    table_end
}

# ===================================================================================
# 진행률 및 애니메이션
# ===================================================================================

# 스피너 애니메이션
show_spinner() {
    local pid="$1"
    local message="$2"
    local spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}%s %s${NC}" "${spinner:i++%${#spinner}:1}" "$message"
        sleep 0.1
    done
    
    printf "\r${GREEN}✓ %s${NC}\n" "$message"
}

# 프로그레스 바 (개선된 버전)
show_progress_bar() {
    local current="$1"
    local total="$2"
    local message="$3"
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    # 프로그레스 바 생성
    local bar=""
    bar+="$(printf "%*s" $filled | tr ' ' '█')"
    bar+="$(printf "%*s" $empty | tr ' ' '░')"
    
    printf "\r${CYAN}%s [%s] %3d%% (%d/%d)${NC}" "$message" "$bar" "$percentage" "$current" "$total"
    
    if [[ $current -eq $total ]]; then
        echo -e " ${GREEN}완료${NC}"
    fi
}

# ===================================================================================
# 경고 및 확인 대화상자
# ===================================================================================

# 위험한 작업 경고
show_danger_warning() {
    local operation="$1"
    local details="$2"
    
    echo -e "\n${RED}${BOLD}⚠ 위험: 이 작업은 데이터 손실을 초래할 수 있습니다! ⚠${NC}"
    table_separator
    echo -e "${YELLOW}작업: $operation${NC}"
    echo -e "${YELLOW}상세: $details${NC}"
    table_separator
    echo -e "${RED}계속하기 전에 중요한 데이터를 백업했는지 확인하세요.${NC}"
    
    if ! confirm_action "정말로 계속하시겠습니까?"; then
        print_info "작업이 취소되었습니다."
        exit 0
    fi
}

# 정보 박스 출력
show_info_box() {
    local title="$1"
    local content="$2"
    local width=80
    
    echo -e "\n${BLUE}┌$(printf '%.0s─' $(seq 1 $((width-2))))┐${NC}"
    printf "${BLUE}│${BOLD}%-*s${NC}${BLUE}│${NC}\n" $((width-2)) " $title"
    echo -e "${BLUE}├$(printf '%.0s─' $(seq 1 $((width-2))))┤${NC}"
    
    # 내용을 줄바꿈으로 분할하여 출력
    while IFS= read -r line; do
        printf "${BLUE}│${NC} %-*s ${BLUE}│${NC}\n" $((width-4)) "$line"
    done <<< "$content"
    
    echo -e "${BLUE}└$(printf '%.0s─' $(seq 1 $((width-2))))┘${NC}\n"
}

# ===================================================================================
# 도움말 출력
# ===================================================================================

# 명령어 도움말 표시
show_command_help() {
    local command="$1"
    local description="$2"
    local usage="$3"
    local options="$4"
    
    echo -e "\n${BOLD}${command}${NC} - $description\n"
    
    if [[ -n "$usage" ]]; then
        echo -e "${BOLD}사용법:${NC}"
        echo -e "  $usage\n"
    fi
    
    if [[ -n "$options" ]]; then
        echo -e "${BOLD}옵션:${NC}"
        echo -e "$options\n"
    fi
}

# 전체 도움말 표시
show_main_help() {
    cat << 'EOF'

Ubuntu RAID CLI (Bash Edition)

사용법:
  ubuntu-disk-toolkit <command> [options]

주요 명령어:
  list-disks          사용 가능한 디스크 목록 표시
  list-raids          현재 RAID 배열 목록 표시
  setup-raid          새로운 RAID 배열 생성
  remove-raid         RAID 배열 제거
  check               디스크/RAID 건강 상태 확인
  mount               디바이스 마운트
  unmount             디바이스 언마운트

진단 도구:
  check-disk-health   종합 디스크 건강 진단
  auto-monitor        자동 모니터링 시작

도움말:
  ubuntu-disk-toolkit <command> --help    특정 명령어 도움말
  ubuntu-disk-toolkit --version           버전 정보 표시

예시:
  ubuntu-disk-toolkit list-disks
  ubuntu-disk-toolkit setup-raid --level 1 --disks /dev/sda,/dev/sdb
  check-disk-health

EOF
} 
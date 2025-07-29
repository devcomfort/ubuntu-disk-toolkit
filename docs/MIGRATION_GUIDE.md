# Ubuntu Disk Toolkit - Migration Guide

## 📖 개요

기존 Ubuntu Disk Toolkit을 새로운 5층 계층 아키텍처로 마이그레이션하는 상세 가이드입니다. 단계별 전환 계획과 호환성 유지 방법을 포함합니다.

## 🔄 마이그레이션 개요

### 현재 구조 (Before)
```
lib/
├── common.sh              (333라인) - 모든 기본 기능 포함
├── ui-functions.sh         (355라인) - UI 및 출력 함수
├── disk-functions.sh       (433라인) - 디스크 기본 조작
├── fstab-functions.sh      (733라인) - fstab 관리
├── raid-functions.sh       (568라인) - RAID 기본 조작
├── system-functions.sh     (497라인) - 시스템 정보
├── validator.sh            (525라인) - 검증 로직
├── id-resolver.sh          (379라인) - ID 해석
├── fail-safe.sh            (532라인) - 안전장치
├── disk-api.sh            (806라인) - 디스크 API
├── fstab-api.sh           (801라인) - fstab API
└── raid-api.sh            (1015라인) - RAID API
```

### 새로운 구조 (After)
```
lib/
├── foundation/            # Layer 0: 기반
│   ├── core.sh
│   ├── logging.sh
│   ├── config.sh
│   └── types.sh
├── utils/                 # Layer 1: 유틸리티
│   ├── shell.sh           # safe_execute 위치!
│   ├── ui.sh
│   ├── validation.sh
│   ├── filesystem.sh
│   └── string.sh
├── system/                # Layer 2: 시스템 추상화
│   ├── disk.sh
│   ├── mount.sh
│   ├── hardware.sh
│   ├── filesystem_ops.sh
│   └── process.sh
├── services/              # Layer 3: 도메인 서비스
│   ├── disk_service.sh
│   ├── raid_service.sh
│   ├── fstab_service.sh
│   ├── id_service.sh
│   └── safety_service.sh
└── api/                   # Layer 4: 애플리케이션 API
    ├── storage_api.sh
    ├── management_api.sh
    ├── analysis_api.sh
    └── automation_api.sh
```

## 📅 단계별 마이그레이션 계획

### Phase 0: 사전 준비 (2시간)

#### 🔍 현재 상태 백업
```bash
# 1. 전체 프로젝트 백업
cd /home/devcomfort/ubuntu-disk-toolkit
git add . && git commit -m "feat: 마이그레이션 전 백업"
tar -czf "backup_$(date +%Y%m%d_%H%M%S).tar.gz" .

# 2. 현재 의존성 매핑
./scripts/analyze_dependencies.sh > migration/current_dependencies.txt

# 3. 기존 테스트 실행하여 기준점 설정
just test > migration/baseline_test_results.txt
```

#### 📋 마이그레이션 준비
```bash
# 새 디렉토리 구조 생성
mkdir -p lib/{foundation,utils,system,services,api}
mkdir -p migration/{backups,scripts,logs}
mkdir -p docs/migration

# 마이그레이션 로그 초기화
echo "마이그레이션 시작: $(date)" > migration/logs/migration.log
```

### Phase 1: Foundation Layer 구축 (반나절)

#### 🏗️ 1.1: core.sh 분리
```bash
# migration/scripts/extract_core.sh
#!/bin/bash

echo "🏗️ Foundation/core.sh 생성 중..."

cat > lib/foundation/core.sh << 'EOF'
#!/bin/bash

# ===================================================================================
# foundation/core.sh - 핵심 기반 시스템
# ===================================================================================

# 프로젝트 기본 상수
declare -r PROJECT_NAME="ubuntu-disk-toolkit"
declare -r PROJECT_VERSION="4.0.0"
declare -r PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 경로 설정
declare -r LIB_DIR="$PROJECT_ROOT/lib"
declare -r CONFIG_DIR="$PROJECT_ROOT/config"
declare -r LOG_DIR="/var/log/$PROJECT_NAME"
declare -r TEMP_DIR="/tmp/$PROJECT_NAME"

# 색상 코드 (기존 common.sh에서 이동)
if ! declare -p RED &>/dev/null; then
    if [[ "${NO_COLOR:-}" == "1" ]] || [[ -n "${NO_COLOR:-}" ]]; then
        declare -r RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
    else
        declare -r RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m'
        declare -r BLUE='\033[0;34m' CYAN='\033[0;36m' BOLD='\033[1m' NC='\033[0m'
    fi
fi

# 환경 초기화
init_environment() {
    setup_directories
    setup_logging
    load_global_config
    register_cleanup_handlers
}

setup_directories() {
    local dirs=("$LOG_DIR" "$TEMP_DIR" "$CONFIG_DIR")
    for dir in "${dirs[@]}"; do
        [[ ! -d "$dir" ]] && mkdir -p "$dir"
    done
}

setup_logging() {
    # logging.sh에서 처리
    return 0
}

load_global_config() {
    # config.sh에서 처리
    return 0
}

register_cleanup_handlers() {
    trap 'cleanup_on_exit' EXIT
    trap 'cleanup_on_exit; exit 130' INT
    trap 'cleanup_on_exit; exit 143' TERM
}

cleanup_on_exit() {
    # 임시 파일 정리
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"/*
}
EOF

echo "✅ Foundation/core.sh 생성 완료"
```

#### 🏗️ 1.2: logging.sh 분리
```bash
# common.sh에서 로깅 관련 함수들을 분리
cat > lib/foundation/logging.sh << 'EOF'
#!/bin/bash

# ===================================================================================
# foundation/logging.sh - 통합 로깅 시스템
# ===================================================================================

# Dependencies: foundation/core.sh
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# 로그 설정
LOG_FILE="${LOG_DIR}/${PROJECT_NAME}.log"
DEBUG_MODE="${DEBUG_MODE:-false}"

# 로그 레벨
declare -r LOG_LEVEL_DEBUG=0
declare -r LOG_LEVEL_INFO=1
declare -r LOG_LEVEL_WARN=2
declare -r LOG_LEVEL_ERROR=3

# 현재 로그 레벨 (기본: INFO)
CURRENT_LOG_LEVEL="${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}"

# 기본 로깅 함수들 (기존 common.sh에서 이동)
log_message() {
    local level="$1" message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

log_debug() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && log_message "DEBUG" "$1"
}

log_info() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && log_message "INFO" "$1"
}

log_warning() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]] && log_message "WARN" "$1"
}

log_error() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && log_message "ERROR" "$1"
}

# 출력 함수들 (기존 common.sh에서 이동)
print_header() {
    local title="$1"
    echo -e "\n${BLUE}=======================================================================${NC}"
    echo -e "${BLUE}  ${title}${NC}"
    echo -e "${BLUE}=======================================================================${NC}"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; log_info "SUCCESS: $1"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; log_warning "$1"; }
print_error() { echo -e "${RED}❌ $1${NC}"; log_error "$1"; }
print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; log_info "$1"; }
print_debug() { [[ "$DEBUG_MODE" == "true" ]] && echo -e "${BLUE}🔧 $1${NC}"; log_debug "$1"; }
EOF
```

#### 🔄 1.3: 기존 코드 적응
```bash
# 기존 common.sh의 호환성 레이어 생성
cat > lib/compat/common_compat.sh << 'EOF'
#!/bin/bash

# ===================================================================================
# compat/common_compat.sh - 기존 common.sh 호환성 레이어
# ===================================================================================

# 새로운 foundation 모듈들 로드
source "$(dirname "${BASH_SOURCE[0]}")/../foundation/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../foundation/logging.sh"

# 기존 함수명으로 새 함수 매핑
print_header() { foundation_print_header "$@"; }
print_success() { foundation_print_success "$@"; }
print_warning() { foundation_print_warning "$@"; }
print_error() { foundation_print_error "$@"; }
print_info() { foundation_print_info "$@"; }

# 마이그레이션 중 기존 코드가 계속 작동하도록 함
EOF
```

### Phase 2: Utilities Layer 구축 (반나절)

#### 🛠️ 2.1: safe_execute 분리 (최우선!)
```bash
# 테스트 행 문제 해결을 위한 safe_execute 분리
cat > lib/utils/shell.sh << 'EOF'
#!/bin/bash

# ===================================================================================
# utils/shell.sh - 쉘 유틸리티 (safe_execute 포함)
# ===================================================================================

# Dependencies: foundation/core.sh foundation/logging.sh
source "$(dirname "${BASH_SOURCE[0]}")/../foundation/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../foundation/logging.sh"

# 🚨 테스트 행 문제 해결: 개선된 safe_execute
safe_execute() {
    local cmd="$1"
    local description="${2:-명령어 실행}"
    
    log_debug "safe_execute 호출: $cmd"
    
    # 🔥 테스트 모드 검사 (테스트 행 문제 해결!)
    if [[ "${TESTING_MODE:-false}" == "true" || "${DRY_RUN:-false}" == "true" ]]; then
        log_info "테스트 모드에서 명령어 검사: $cmd"
        
        # 위험한 명령어 패턴 목록
        local dangerous_patterns=(
            "parted.*mkpart"          # 파티션 생성
            "parted.*rm"              # 파티션 삭제  
            "mkfs\."                  # 파일시스템 생성
            "dd.*of=/dev/"            # 디스크 쓰기
            "shred.*"                 # 안전 삭제
            "mdadm.*--create"         # RAID 생성
            "mdadm.*--remove"         # RAID 제거
            "fdisk.*"                 # 파티션 편집
            "wipefs.*"                # 파일시스템 서명 제거
            "sgdisk.*"                # GPT 파티션 편집
            "sfdisk.*"                # 파티션 테이블 편집
        )
        
        # 위험한 패턴 검사
        for pattern in "${dangerous_patterns[@]}"; do
            if [[ "$cmd" =~ $pattern ]]; then
                log_info "[MOCK] 위험한 명령어 시뮬레이션: $cmd"
                print_info "[MOCK] $description 시뮬레이션 완료"
                
                # 일부 명령어에 대해 현실적인 출력 제공
                case "$cmd" in
                    *"parted"*"print"*)
                        echo "Model: Virtual Disk (mock)"
                        echo "Disk /dev/mock: 1000GB"
                        echo "Sector size: 512B"
                        ;;
                    *"lsblk"*)
                        echo "NAME SIZE TYPE MOUNTPOINT"
                        echo "mock1 100G disk"
                        echo "mock2 200G disk"
                        ;;
                    *"blkid"*)
                        echo "/dev/mock1: UUID=\"12345678-1234-1234-1234-123456789012\" TYPE=\"ext4\""
                        ;;
                esac
                
                return 0
            fi
        done
        
        log_debug "명령어가 안전함: $cmd"
    fi
    
    # 실제 명령어 실행
    log_info "명령어 실행: $cmd"
    
    # 대화형 입력 차단 (테스트 환경에서)
    if [[ "${TESTING_MODE:-false}" == "true" ]]; then
        export DEBIAN_FRONTEND=noninteractive
        export TERM=dumb
    fi
    
    # 명령어 실행
    local start_time=$(date +%s)
    eval "$cmd"
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 결과 로깅
    if [[ $exit_code -eq 0 ]]; then
        log_info "$description 성공 (${duration}초)"
        print_debug "$description 완료"
    else
        log_error "$description 실패 (exit code: $exit_code, ${duration}초)"
        print_error "$description 실패: exit code $exit_code"
    fi
    
    return $exit_code
}

# 사용자 확인 함수 (기존 common.sh에서 이동)
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    # 자동 확인 모드
    if [[ "${AUTO_CONFIRM:-false}" == "true" ]]; then
        log_info "자동 확인 모드: $message"
        return 0
    fi
    
    # 테스트 모드에서는 자동으로 승인 (행 방지)
    if [[ "${TESTING_MODE:-false}" == "true" ]]; then
        log_info "테스트 모드: 자동 승인 - $message"
        return 0
    fi
    
    echo -n "$message (y/N): "
    read -r response
    [[ "${response,,}" =~ ^y(es)?$ ]]
}

# 권한 검사 (기존 common.sh에서 이동)
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_error "이 작업은 root 권한이 필요합니다"
        print_info "다음 명령어로 다시 실행하세요: sudo $0 $*"
        return 1
    fi
    return 0
}

# 필수 명령어 검사 (기존 common.sh에서 이동)  
check_required_commands() {
    local commands=("$@")
    local missing_commands=()
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        print_error "다음 명령어들이 설치되지 않았습니다: ${missing_commands[*]}"
        print_info "다음 명령어로 설치하세요: sudo apt install ${missing_commands[*]}"
        return 1
    fi
    
    return 0
}
EOF

echo "🔥 중요: safe_execute가 utils/shell.sh로 이동됨 - 테스트 행 문제 해결!"
```

#### 🛠️ 2.2: UI 함수 분리
```bash
# ui-functions.sh에서 UI 관련 함수들을 분리
cat > lib/utils/ui.sh << 'EOF'
#!/bin/bash

# ===================================================================================
# utils/ui.sh - 사용자 인터페이스 컴포넌트
# ===================================================================================

# Dependencies: foundation/core.sh
source "$(dirname "${BASH_SOURCE[0]}")/../foundation/core.sh"

# 테이블 출력 함수들 (기존 ui-functions.sh에서 이동)
table_start() {
    printf "┌─────────────────────────────────────────────────────────────┐\n"
}

table_row() {
    local col1="$1" col2="$2" col3="$3"
    printf "│ %-20s │ %-20s │ %-15s │\n" "$col1" "$col2" "$col3"
}

table_separator() {
    printf "├─────────────────────────────────────────────────────────────┤\n"
}

table_end() {
    printf "└─────────────────────────────────────────────────────────────┘\n"
}

# 진행률 표시 (기존 ui-functions.sh에서 이동 및 개선)
show_progress() {
    local current="$1" total="$2" message="$3"
    local percentage=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percentage * bar_length / 100))
    
    printf "\r%s [" "$message"
    for ((i=0; i<filled_length; i++)); do printf "█"; done
    for ((i=filled_length; i<bar_length; i++)); do printf "░"; done
    printf "] %d%%" "$percentage"
    
    # 완료시 줄바꿈
    [[ $current -eq $total ]] && echo
}

# 스피너 (새로 추가)
show_spinner() {
    local pid="$1" message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%s %c" "$message" "${spin:i++%${#spin}:1}"
        sleep 0.1
    done
    printf "\r%s ✅\n" "$message"
}

# 메뉴 표시 (기존 ui-functions.sh에서 이동)
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    
    echo -e "\n${BOLD}$title${NC}"
    echo "───────────────────────────"
    
    for i in "${!options[@]}"; do
        printf "%2d) %s\n" $((i+1)) "${options[$i]}"
    done
    echo
}

# 사용자 선택 (기존 ui-functions.sh에서 이동)
get_user_choice() {
    local prompt="$1" max_choice="$2"
    local choice
    
    while true; do
        echo -n "$prompt (1-$max_choice): "
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le $max_choice ]]; then
            echo "$choice"
            return 0
        fi
        
        print_error "1부터 $max_choice 사이의 숫자를 입력하세요"
    done
}
EOF
```

### Phase 3: System Abstraction Layer 구축 (1일)

#### 🖥️ 3.1: disk.sh 분리
```bash
cat > lib/system/disk.sh << 'EOF'
#!/bin/bash

# ===================================================================================
# system/disk.sh - 디스크 시스템 추상화
# ===================================================================================

# Dependencies: foundation/core.sh foundation/logging.sh utils/shell.sh
source "$(dirname "${BASH_SOURCE[0]}")/../foundation/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../foundation/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/shell.sh"

# 모든 디스크 목록 (기존 disk-functions.sh에서 이동)
get_all_disks() {
    log_debug "시스템 디스크 목록 조회"
    
    if command -v lsblk >/dev/null 2>&1; then
        lsblk -ndo NAME,SIZE,TYPE,MODEL | grep -E "(disk|part)"
    else
        log_error "lsblk 명령어를 찾을 수 없습니다"
        return 1
    fi
}

# 디스크 정보 조회 (기존 disk-functions.sh에서 이동 및 개선)
get_disk_info() {
    local device="$1"
    
    [[ -z "$device" ]] && { log_error "디바이스가 지정되지 않았습니다"; return 1; }
    
    log_debug "디스크 정보 조회: $device"
    
    {
        echo "=== 디스크 기본 정보 ==="
        echo "Device: $device"
        
        if [[ -b "$device" ]]; then
            echo "Size: $(lsblk -ndo SIZE "$device" 2>/dev/null || echo "Unknown")"
            echo "Model: $(lsblk -ndo MODEL "$device" 2>/dev/null || echo "Unknown")"
            echo "Serial: $(lsblk -ndo SERIAL "$device" 2>/dev/null || echo "Unknown")"
            echo "Type: $(lsblk -ndo TYPE "$device" 2>/dev/null || echo "Unknown")"
            echo "Rotational: $(lsblk -ndo ROTA "$device" 2>/dev/null | sed 's/0/No (SSD)/;s/1/Yes (HDD)/' || echo "Unknown")"
        else
            echo "Status: Device not found or not a block device"
        fi
        
        echo ""
        echo "=== 파티션 정보 ==="
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$device" 2>/dev/null || echo "No partition information available"
        
        echo ""
        echo "=== 파일시스템 정보 ==="
        if command -v blkid >/dev/null 2>&1; then
            blkid "$device"* 2>/dev/null || echo "No filesystem information available"
        fi
    }
}

# 디스크 마운트 상태 확인 (기존 disk-functions.sh에서 이동)
is_disk_mounted() {
    local device="$1"
    
    [[ -z "$device" ]] && { log_error "디바이스가 지정되지 않았습니다"; return 1; }
    
    if command -v findmnt >/dev/null 2>&1; then
        findmnt -rn -S "$device" >/dev/null 2>&1
    else
        # findmnt가 없을 경우 /proc/mounts 확인
        grep -q "^$device " /proc/mounts 2>/dev/null
    fi
}

# RAID 멤버 여부 확인 (기존 disk-functions.sh에서 이동)
is_raid_member() {
    local device="$1"
    
    [[ -z "$device" ]] && { log_error "디바이스가 지정되지 않았습니다"; return 1; }
    
    if command -v mdadm >/dev/null 2>&1; then
        mdadm --examine "$device" >/dev/null 2>&1
    else
        # mdadm이 없을 경우 /proc/mdstat 확인
        grep -q "${device##*/}" /proc/mdstat 2>/dev/null
    fi
}

# 디스크 사용 여부 확인 (기존 disk-functions.sh에서 이동 및 개선)
is_disk_in_use() {
    local device="$1"
    
    [[ -z "$device" ]] && { log_error "디바이스가 지정되지 않았습니다"; return 1; }
    
    log_debug "디스크 사용 여부 확인: $device"
    
    # 마운트 여부 확인
    if is_disk_mounted "$device"; then
        log_debug "$device는 마운트되어 있습니다"
        return 0
    fi
    
    # RAID 멤버 여부 확인
    if is_raid_member "$device"; then
        log_debug "$device는 RAID 멤버입니다"
        return 0
    fi
    
    # LVM 사용 여부 확인
    if command -v pvs >/dev/null 2>&1; then
        if pvs --noheadings "$device" 2>/dev/null | grep -q .; then
            log_debug "$device는 LVM에서 사용 중입니다"
            return 0
        fi
    fi
    
    log_debug "$device는 사용되지 않고 있습니다"
    return 1
}

# 디스크 크기 조회 (기존 disk-functions.sh에서 이동)
get_disk_size() {
    local device="$1"
    
    [[ -z "$device" ]] && { log_error "디바이스가 지정되지 않았습니다"; return 1; }
    
    if [[ -b "$device" ]]; then
        lsblk -ndo SIZE "$device" 2>/dev/null || echo "Unknown"
    else
        echo "N/A"
    fi
}

# 디스크 크기 포맷팅 (기존 disk-functions.sh에서 이동 및 개선)
format_disk_size() {
    local size_bytes="$1"
    
    [[ -z "$size_bytes" ]] && { echo "Unknown"; return 1; }
    
    # 숫자가 아닌 경우 그대로 반환
    [[ ! "$size_bytes" =~ ^[0-9]+$ ]] && { echo "$size_bytes"; return 0; }
    
    local units=("B" "KB" "MB" "GB" "TB" "PB")
    local size=$size_bytes
    local unit_index=0
    
    while [[ $size -gt 1024 ]] && [[ $unit_index -lt 5 ]]; do
        size=$((size / 1024))
        ((unit_index++))
    done
    
    echo "${size}${units[$unit_index]}"
}
EOF
```

#### 🖥️ 3.2: mount.sh 분리
```bash
cat > lib/system/mount.sh << 'EOF'
#!/bin/bash

# ===================================================================================
# system/mount.sh - 마운트 시스템 추상화
# ===================================================================================

# Dependencies: foundation/core.sh foundation/logging.sh utils/shell.sh utils/validation.sh
source "$(dirname "${BASH_SOURCE[0]}")/../foundation/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../foundation/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/shell.sh"

# 디바이스 마운트
mount_device() {
    local device="$1" mountpoint="$2" options="${3:-defaults}"
    
    [[ -z "$device" || -z "$mountpoint" ]] && {
        log_error "디바이스와 마운트포인트를 모두 지정해야 합니다"
        return 1
    }
    
    log_info "디바이스 마운트: $device -> $mountpoint (옵션: $options)"
    
    # 사전 검증
    [[ ! -b "$device" ]] && {
        log_error "디바이스가 존재하지 않습니다: $device"
        return 1
    }
    
    # 마운트포인트 생성
    if [[ ! -d "$mountpoint" ]]; then
        log_info "마운트포인트 생성: $mountpoint"
        safe_execute "mkdir -p '$mountpoint'" "마운트포인트 생성" || return 1
    fi
    
    # 이미 마운트된 경우 확인
    if findmnt -rn -S "$device" >/dev/null 2>&1; then
        local current_mount
        current_mount=$(findmnt -rn -S "$device" -o TARGET)
        if [[ "$current_mount" == "$mountpoint" ]]; then
            log_info "디바이스가 이미 올바른 위치에 마운트되어 있습니다"
            return 0
        else
            log_warning "디바이스가 다른 위치에 마운트되어 있습니다: $current_mount"
            return 1
        fi
    fi
    
    # 마운트 실행
    safe_execute "mount -o '$options' '$device' '$mountpoint'" "디바이스 마운트"
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        log_info "마운트 성공: $device -> $mountpoint"
        print_success "디바이스가 성공적으로 마운트되었습니다"
    else
        log_error "마운트 실패: $device -> $mountpoint"
        print_error "디바이스 마운트에 실패했습니다"
    fi
    
    return $result
}

# 디바이스 언마운트
unmount_device() {
    local target="$1"
    local force="${2:-false}"
    
    [[ -z "$target" ]] && {
        log_error "언마운트할 대상을 지정해야 합니다"
        return 1
    }
    
    log_info "디바이스 언마운트: $target (강제: $force)"
    
    # 마운트 여부 확인
    if ! findmnt -rn "$target" >/dev/null 2>&1; then
        log_info "대상이 마운트되어 있지 않습니다: $target"
        return 0
    fi
    
    # 언마운트 실행
    local umount_cmd="umount"
    [[ "$force" == "true" ]] && umount_cmd="umount -f"
    
    safe_execute "$umount_cmd '$target'" "디바이스 언마운트"
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        log_info "언마운트 성공: $target"
        print_success "디바이스가 성공적으로 언마운트되었습니다"
    else
        log_error "언마운트 실패: $target"
        print_error "디바이스 언마운트에 실패했습니다"
        
        # 강제 언마운트 제안
        if [[ "$force" != "true" ]]; then
            print_info "강제 언마운트를 시도해보세요: unmount_device '$target' true"
        fi
    fi
    
    return $result
}

# 마운트 정보 조회
get_mount_info() {
    local target="$1"
    
    if [[ -n "$target" ]]; then
        # 특정 대상의 마운트 정보
        findmnt -rn "$target" 2>/dev/null || {
            log_warning "마운트 정보를 찾을 수 없습니다: $target"
            return 1
        }
    else
        # 전체 마운트 정보
        findmnt -rn 2>/dev/null || {
            log_error "마운트 정보를 조회할 수 없습니다"
            return 1
        }
    fi
}

# 테스트 마운트 (임시 마운트로 검증)
test_mount() {
    local device="$1" filesystem="${2:-auto}"
    local temp_mount="/tmp/test_mount_$$"
    
    [[ -z "$device" ]] && {
        log_error "테스트할 디바이스를 지정해야 합니다"
        return 1
    }
    
    log_info "테스트 마운트 실행: $device (파일시스템: $filesystem)"
    
    # 임시 마운트포인트 생성
    mkdir -p "$temp_mount" || {
        log_error "임시 마운트포인트 생성 실패"
        return 1
    }
    
    # 테스트 마운트
    local mount_cmd="mount -t '$filesystem' '$device' '$temp_mount'"
    if safe_execute "$mount_cmd" "테스트 마운트"; then
        # 즉시 언마운트
        safe_execute "umount '$temp_mount'" "테스트 언마운트"
        rm -rf "$temp_mount"
        
        print_success "테스트 마운트 성공: $device"
        return 0
    else
        rm -rf "$temp_mount"
        print_error "테스트 마운트 실패: $device"
        return 1
    fi
}
EOF
```

### Phase 4: Services Layer 구축 (2일)

#### ⚙️ 4.1: disk_service.sh 통합
```bash
cat > lib/services/disk_service.sh << 'EOF'
#!/bin/bash

# ===================================================================================
# services/disk_service.sh - 디스크 관리 서비스
# ===================================================================================

# Dependencies: system/disk.sh system/mount.sh utils/ui.sh
source "$(dirname "${BASH_SOURCE[0]}")/../system/disk.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../system/mount.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/ui.sh"

# 사용 가능한 디스크 목록 (기존 API들을 통합)
disk_service_list_available() {
    local format="${1:-table}"
    
    log_info "사용 가능한 디스크 목록 조회 (형식: $format)"
    
    local available_disks=()
    
    # 모든 디스크 검사
    while IFS= read -r line; do
        local disk_name=$(echo "$line" | awk '{print $1}')
        local full_path="/dev/$disk_name"
        
        # 블록 디바이스만 처리
        [[ -b "$full_path" ]] || continue
        
        # 사용 중이지 않은 디스크만 선택
        if ! is_disk_in_use "$full_path"; then
            available_disks+=("$line")
        fi
    done < <(get_all_disks | grep "disk")
    
    # 형식에 따른 출력
    case "$format" in
        "table")
            table_start
            table_row "디바이스" "크기" "모델"
            table_separator
            for disk in "${available_disks[@]}"; do
                local name size type model
                read -r name size type model <<< "$disk"
                table_row "/dev/$name" "$size" "${model:-Unknown}"
            done
            table_end
            ;;
        "json")
            echo -n '{"available_disks":['
            local first=true
            for disk in "${available_disks[@]}"; do
                local name size type model
                read -r name size type model <<< "$disk"
                [[ "$first" == "true" ]] && first=false || echo -n ","
                echo -n "{\"name\":\"/dev/$name\",\"size\":\"$size\",\"type\":\"$type\",\"model\":\"${model:-Unknown}\"}"
            done
            echo ']}'
            ;;
        "simple")
            for disk in "${available_disks[@]}"; do
                local name
                read -r name _ <<< "$disk"
                echo "/dev/$name"
            done
            ;;
        *)
            log_error "지원하지 않는 형식: $format"
            return 1
            ;;
    esac
    
    log_info "사용 가능한 디스크 ${#available_disks[@]}개 발견"
}

# 디스크 건강 상태 분석 (기존 기능들을 통합 및 개선)
disk_service_analyze_health() {
    local device="$1"
    local report_file="${2:-/tmp/disk_health_$(date +%s).report}"
    
    [[ -z "$device" ]] && {
        log_error "분석할 디바이스를 지정해야 합니다"
        return 1
    }
    
    log_info "디스크 건강 상태 분석 시작: $device"
    
    {
        echo "=========================================="
        echo "디스크 건강 분석 보고서"
        echo "=========================================="
        echo "분석 시간: $(date)"
        echo "대상 디바이스: $device"
        echo ""
        
        echo "========== 기본 정보 =========="
        get_disk_info "$device"
        
        echo ""
        echo "========== 마운트 상태 =========="
        if is_disk_mounted "$device"; then
            echo "✅ 마운트됨"
            local mount_info
            mount_info=$(get_mount_info "$device")
            echo "마운트 정보: $mount_info"
        else
            echo "⭕ 마운트되지 않음"
        fi
        
        echo ""
        echo "========== 사용 상태 =========="
        if is_disk_in_use "$device"; then
            echo "⚠️  사용 중"
            is_raid_member "$device" && echo "- RAID 멤버"
            is_disk_mounted "$device" && echo "- 마운트됨"
        else
            echo "✅ 사용 가능"
        fi
        
        echo ""
        echo "========== SMART 정보 =========="
        if command -v smartctl >/dev/null 2>&1; then
            smartctl -H "$device" 2>/dev/null | grep -E "(SMART overall-health|PASSED|FAILED)" || echo "SMART 정보 없음"
        else
            echo "smartctl이 설치되지 않음 (sudo apt install smartmontools)"
        fi
        
        echo ""
        echo "========== 분석 완료 =========="
        echo "보고서 파일: $report_file"
        
    } > "$report_file"
    
    print_success "디스크 건강 분석 완료"
    print_info "보고서 파일: $report_file"
    
    echo "$report_file"
}

# 디스크 준비 (포맷 및 파티션 생성)
disk_service_prepare() {
    local device="$1" filesystem="${2:-ext4}"
    
    [[ -z "$device" ]] && {
        log_error "준비할 디바이스를 지정해야 합니다"
        return 1
    }
    
    log_info "디스크 준비 시작: $device (파일시스템: $filesystem)"
    
    # 안전성 검사
    if is_disk_in_use "$device"; then
        log_error "디바이스가 사용 중입니다: $device"
        print_error "사용 중인 디바이스는 준비할 수 없습니다"
        return 1
    fi
    
    # 사용자 확인
    if ! confirm_action "디바이스 $device의 모든 데이터가 삭제됩니다. 계속하시겠습니까?"; then
        log_info "사용자가 작업을 취소했습니다"
        return 1
    fi
    
    # 파일시스템 생성
    print_info "파일시스템 생성 중: $filesystem"
    safe_execute "mkfs.$filesystem '$device'" "파일시스템 생성" || {
        log_error "파일시스템 생성 실패"
        return 1
    }
    
    # 테스트 마운트
    print_info "테스트 마운트 실행 중..."
    if test_mount "$device" "$filesystem"; then
        print_success "디스크 준비 완료: $device"
        return 0
    else
        print_error "테스트 마운트 실패"
        return 1
    fi
}
EOF
```

### Phase 5: API Layer 구축 (1일)

#### 🚀 5.1: storage_api.sh 통합
```bash
cat > lib/api/storage_api.sh << 'EOF'
#!/bin/bash

# ===================================================================================
# api/storage_api.sh - 통합 스토리지 API
# ===================================================================================

# Dependencies: services/disk_service.sh services/fstab_service.sh services/raid_service.sh
source "$(dirname "${BASH_SOURCE[0]}")/../services/disk_service.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/fstab_service.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/raid_service.sh"

# 완전한 디스크 설정 워크플로우 (신규)
storage_api_complete_disk_setup() {
    local device="$1" mountpoint="$2" filesystem="${3:-ext4}" options="${4:-defaults,nofail}"
    
    [[ -z "$device" || -z "$mountpoint" ]] && {
        log_error "디바이스와 마운트포인트를 모두 지정해야 합니다"
        return 1
    }
    
    print_header "완전한 디스크 설정: $device -> $mountpoint"
    
    # Step 1: 디스크 상태 검사
    print_step "1/5" "디스크 상태 검사"
    if is_disk_in_use "$device"; then
        print_error "디바이스가 이미 사용 중입니다: $device"
        return 1
    fi
    
    # Step 2: 파일시스템 생성
    print_step "2/5" "파일시스템 생성 ($filesystem)"
    if ! disk_service_prepare "$device" "$filesystem"; then
        print_error "파일시스템 생성 실패"
        return 1
    fi
    
    # Step 3: 마운트포인트 생성
    print_step "3/5" "마운트포인트 생성"
    safe_execute "mkdir -p '$mountpoint'" "마운트포인트 생성" || return 1
    
    # Step 4: fstab 등록
    print_step "4/5" "fstab 자동 등록"
    if ! fstab_service_add_entry "$device" "$mountpoint" "$filesystem" "$options"; then
        print_error "fstab 등록 실패"
        return 1
    fi
    
    # Step 5: 테스트 마운트
    print_step "5/5" "설정 검증"
    if mount_device "$device" "$mountpoint" "$options"; then
        print_success "디스크 설정이 완료되었습니다!"
        print_info "디바이스: $device"
        print_info "마운트포인트: $mountpoint" 
        print_info "파일시스템: $filesystem"
        print_info "옵션: $options"
        
        # 사용 가능 공간 표시
        local available_space
        available_space=$(df -h "$mountpoint" | awk 'NR==2 {print $4}')
        print_info "사용 가능 공간: $available_space"
        
        return 0
    else
        print_error "최종 마운트 검증 실패"
        return 1
    fi
}

# RAID + fstab 통합 설정 (기존 기능 개선)
storage_api_setup_raid_with_fstab() {
    local raid_level="$1" mountpoint="$2" filesystem="${3:-ext4}"
    shift 3
    local devices=("$@")
    
    [[ -z "$raid_level" || -z "$mountpoint" || ${#devices[@]} -lt 2 ]] && {
        log_error "RAID 레벨, 마운트포인트, 최소 2개 디바이스가 필요합니다"
        return 1
    }
    
    print_header "RAID $raid_level 설정 및 fstab 통합 구성"
    print_info "디바이스: ${devices[*]}"
    print_info "마운트포인트: $mountpoint"
    print_info "파일시스템: $filesystem"
    
    # Step 1: 디바이스 검증
    print_step "1/6" "디바이스 검증"
    for device in "${devices[@]}"; do
        if ! validate_device "$device"; then
            print_error "유효하지 않은 디바이스: $device"
            return 1
        fi
        
        if is_disk_in_use "$device"; then
            print_error "디바이스가 이미 사용 중입니다: $device"
            return 1
        fi
    done
    
    # Step 2: RAID 생성
    print_step "2/6" "RAID $raid_level 배열 생성"
    local raid_device
    raid_device=$(raid_service_create "$raid_level" "${devices[@]}") || {
        print_error "RAID 생성 실패"
        return 1
    }
    
    print_success "RAID 배열 생성됨: $raid_device"
    
    # Step 3: 파일시스템 생성
    print_step "3/6" "파일시스템 생성 ($filesystem)"
    safe_execute "mkfs.$filesystem '$raid_device'" "파일시스템 생성" || {
        print_error "파일시스템 생성 실패"
        return 1
    }
    
    # Step 4: 마운트포인트 생성
    print_step "4/6" "마운트포인트 생성"
    safe_execute "mkdir -p '$mountpoint'" "마운트포인트 생성" || return 1
    
    # Step 5: fstab 등록 (RAID 전용 옵션 적용)
    print_step "5/6" "fstab 자동 등록"
    local raid_options="defaults,nofail,noatime"  # RAID에 최적화된 옵션
    if ! fstab_service_add_entry "$raid_device" "$mountpoint" "$filesystem" "$raid_options"; then
        print_error "fstab 등록 실패"
        return 1
    fi
    
    # Step 6: 테스트 마운트 및 검증
    print_step "6/6" "설정 검증"
    if mount_device "$raid_device" "$mountpoint" "$raid_options"; then
        print_success "RAID 설정이 완료되었습니다!"
        
        # 상세 정보 출력
        echo ""
        print_info "=== RAID 설정 요약 ==="
        print_info "RAID 레벨: $raid_level"
        print_info "RAID 디바이스: $raid_device"
        print_info "구성 디바이스: ${devices[*]}"
        print_info "마운트포인트: $mountpoint"
        print_info "파일시스템: $filesystem"
        print_info "마운트 옵션: $raid_options"
        
        # RAID 상태 확인
        if command -v mdadm >/dev/null 2>&1; then
            print_info "RAID 상태:"
            mdadm --detail "$raid_device" | grep -E "(State|Active Devices|Working Devices)"
        fi
        
        # 사용 가능 공간 표시
        local available_space
        available_space=$(df -h "$mountpoint" | awk 'NR==2 {print $4}')
        print_info "사용 가능 공간: $available_space"
        
        return 0
    else
        print_error "최종 마운트 검증 실패"
        return 1
    fi
}

# 스토리지 시스템 자동 설정 (신규)
storage_api_auto_setup() {
    local config_file="${1:-/etc/ubuntu-disk-toolkit/auto-setup.conf}"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "설정 파일이 존재하지 않습니다: $config_file"
        return 1
    fi
    
    print_header "자동 스토리지 설정"
    print_info "설정 파일: $config_file"
    
    # 설정 로드
    source "$config_file"
    
    # 필수 변수 확인
    local required_vars=("SETUP_TYPE")
    for var in "${required_vars[@]}"; do
        [[ -z "${!var}" ]] && {
            print_error "필수 설정이 누락되었습니다: $var"
            return 1
        }
    done
    
    case "${SETUP_TYPE^^}" in
        "SINGLE")
            [[ -z "$DEVICE" || -z "$MOUNTPOINT" ]] && {
                print_error "SINGLE 모드에는 DEVICE와 MOUNTPOINT가 필요합니다"
                return 1
            }
            storage_api_complete_disk_setup "$DEVICE" "$MOUNTPOINT" "${FILESYSTEM:-ext4}" "${OPTIONS:-defaults,nofail}"
            ;;
        "RAID")
            [[ -z "$RAID_LEVEL" || -z "$RAID_DEVICES" || -z "$MOUNTPOINT" ]] && {
                print_error "RAID 모드에는 RAID_LEVEL, RAID_DEVICES, MOUNTPOINT가 필요합니다"
                return 1
            }
            local devices_array
            IFS=' ' read -ra devices_array <<< "$RAID_DEVICES"
            storage_api_setup_raid_with_fstab "$RAID_LEVEL" "$MOUNTPOINT" "${FILESYSTEM:-ext4}" "${devices_array[@]}"
            ;;
        *)
            print_error "지원하지 않는 설정 타입: $SETUP_TYPE"
            return 1
            ;;
    esac
}
EOF
```

### Phase 6: CLI 개선 (1일)

#### 📱 6.1: 새로운 통합 CLI
```bash
cat > bin/ubuntu-disk-toolkit << 'EOF'
#!/bin/bash

# ===================================================================================
# ubuntu-disk-toolkit v4.0.0 - 새로운 5층 아키텍처
# ===================================================================================

set -euo pipefail

# 버전 및 기본 정보
VERSION="4.0.0"
DESCRIPTION="Ubuntu Disk Toolkit - 5-Layer Architecture Edition"

# 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# Foundation 로드 (필수)
source "$LIB_DIR/foundation/core.sh"
source "$LIB_DIR/foundation/logging.sh"

# 모듈 로더 초기화
declare -A LOADED_MODULES
declare -A MODULE_DEPENDENCIES

# 모듈 로드 함수
load_layer() {
    local layer="$1"
    
    case "$layer" in
        "utils")
            source "$LIB_DIR/utils/shell.sh"
            source "$LIB_DIR/utils/ui.sh"
            source "$LIB_DIR/utils/validation.sh"
            ;;
        "system")
            load_layer "utils"
            source "$LIB_DIR/system/disk.sh"
            source "$LIB_DIR/system/mount.sh"
            ;;
        "services")
            load_layer "system"
            source "$LIB_DIR/services/disk_service.sh"
            # 필요에 따라 다른 서비스들도 로드
            ;;
        "api")
            load_layer "services"
            source "$LIB_DIR/api/storage_api.sh"
            # 필요에 따라 다른 API들도 로드
            ;;
    esac
}

# 메인 메뉴 표시
show_main_menu() {
    print_header "Ubuntu Disk Toolkit v$VERSION"
    echo ""
    echo "새로운 5층 계층 아키텍처로 완전히 재설계되었습니다"
    echo ""
    echo "사용법: ubuntu-disk-toolkit <카테고리> <명령어> [옵션]"
    echo ""
    echo "📀 주요 카테고리:"
    echo "  disk     - 디스크 관리 (목록, 정보, 마운트)"
    echo "  raid     - RAID 관리 (생성, 제거, 상태)"
    echo "  fstab    - fstab 관리 (추가, 제거, 검증)"
    echo "  storage  - 통합 스토리지 워크플로우"
    echo "  system   - 시스템 분석 및 관리"
    echo ""
    echo "🔧 유틸리티:"
    echo "  analyze  - 종합 분석 보고서"
    echo "  migrate  - 기존 버전에서 마이그레이션"
    echo "  test     - 테스트 모드 실행"
    echo ""
    echo "📖 도움말:"
    echo "  help <카테고리>  - 카테고리별 상세 도움말"
    echo "  version          - 버전 정보"
    echo ""
    echo "예제:"
    echo "  ubuntu-disk-toolkit disk list"
    echo "  ubuntu-disk-toolkit storage setup-single /dev/sdb /mnt/data"
    echo "  ubuntu-disk-toolkit raid create 1 /dev/sdb /dev/sdc"
}

# 카테고리별 라우팅
route_command() {
    local category="$1"
    shift
    
    case "$category" in
        "disk")
            load_layer "services"
            handle_disk_commands "$@"
            ;;
        "raid")
            load_layer "services"
            handle_raid_commands "$@"
            ;;
        "fstab")
            load_layer "services"
            handle_fstab_commands "$@"
            ;;
        "storage")
            load_layer "api"
            handle_storage_commands "$@"
            ;;
        "system")
            load_layer "services"
            handle_system_commands "$@"
            ;;
        "analyze")
            load_layer "api"
            handle_analyze_commands "$@"
            ;;
        "migrate")
            handle_migration_commands "$@"
            ;;
        "test")
            export TESTING_MODE=true
            export DRY_RUN=true
            print_success "테스트 모드가 활성화되었습니다"
            route_command "$@"
            ;;
        "help")
            show_category_help "$1"
            ;;
        "version")
            echo "Ubuntu Disk Toolkit v$VERSION"
            echo "$DESCRIPTION"
            ;;
        *)
            print_error "알 수 없는 카테고리: $category"
            echo ""
            show_main_menu
            return 1
            ;;
    esac
}

# 디스크 명령어 처리
handle_disk_commands() {
    local command="$1"
    shift
    
    case "$command" in
        "list")
            disk_service_list_available "${1:-table}"
            ;;
        "info")
            [[ -z "$1" ]] && { print_error "디바이스를 지정하세요"; return 1; }
            disk_service_analyze_health "$1"
            ;;
        "mount")
            [[ $# -lt 2 ]] && { print_error "디바이스와 마운트포인트를 지정하세요"; return 1; }
            mount_device "$1" "$2" "${3:-defaults}"
            ;;
        "unmount")
            [[ -z "$1" ]] && { print_error "언마운트할 대상을 지정하세요"; return 1; }
            unmount_device "$1" "${2:-false}"
            ;;
        *)
            print_error "알 수 없는 디스크 명령어: $command"
            return 1
            ;;
    esac
}

# 스토리지 명령어 처리
handle_storage_commands() {
    local command="$1"
    shift
    
    case "$command" in
        "setup-single")
            [[ $# -lt 2 ]] && { print_error "디바이스와 마운트포인트를 지정하세요"; return 1; }
            storage_api_complete_disk_setup "$1" "$2" "${3:-ext4}" "${4:-defaults,nofail}"
            ;;
        "setup-raid")
            [[ $# -lt 4 ]] && { print_error "RAID 레벨, 마운트포인트, 최소 2개 디바이스가 필요합니다"; return 1; }
            local raid_level="$1" mountpoint="$2" filesystem="${3:-ext4}"
            shift 3
            storage_api_setup_raid_with_fstab "$raid_level" "$mountpoint" "$filesystem" "$@"
            ;;
        "auto-setup")
            storage_api_auto_setup "${1:-/etc/ubuntu-disk-toolkit/auto-setup.conf}"
            ;;
        *)
            print_error "알 수 없는 스토리지 명령어: $command"
            return 1
            ;;
    esac
}

# 메인 함수
main() {
    # 환경 초기화
    init_environment
    
    # 인수가 없는 경우 메인 메뉴 표시
    if [[ $# -eq 0 ]]; then
        show_main_menu
        return 0
    fi
    
    # 명령어 라우팅
    route_command "$@"
}

# 스크립트 실행
main "$@"
EOF

chmod +x bin/ubuntu-disk-toolkit
```

## 🔄 호환성 레이어

### 기존 코드 호환성 유지
```bash
# lib/compat/v3_compat.sh - 기존 v3.0 API 호환성
cat > lib/compat/v3_compat.sh << 'EOF'
#!/bin/bash

# ===================================================================================
# compat/v3_compat.sh - v3.0 API 호환성 레이어
# ===================================================================================

# 새로운 모듈들 로드
source "$(dirname "${BASH_SOURCE[0]}")/../foundation/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/disk_service.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/fstab_service.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../api/storage_api.sh"

# 기존 함수명을 새로운 API로 매핑
get_all_disks() { system_get_all_disks "$@"; }
get_disk_info() { system_get_disk_info "$@"; }
is_disk_mounted() { system_is_disk_mounted "$@"; }
mount_device() { system_mount_device "$@"; }
unmount_device() { system_unmount_device "$@"; }

# 기존 API 함수들을 새로운 서비스로 매핑
add_fstab_entry_safe() { fstab_service_add_entry "$@"; }
remove_fstab_entry() { fstab_service_remove_entry "$@"; }
validate_fstab() { fstab_service_validate "$@"; }

# 기존 safe_execute 호환성 (가장 중요!)
safe_execute() { utils_safe_execute "$@"; }

print_success() { foundation_print_success "$@"; }
print_error() { foundation_print_error "$@"; }
print_warning() { foundation_print_warning "$@"; }
print_info() { foundation_print_info "$@"; }

# 마이그레이션 경고 메시지
_show_migration_warning() {
    if [[ "${MIGRATION_WARNING_SHOWN:-}" != "true" ]]; then
        echo "⚠️  호환성 모드로 실행 중입니다. 새로운 v4.0 API 사용을 권장합니다."
        export MIGRATION_WARNING_SHOWN=true
    fi
}

# 모든 호환성 함수에 경고 추가
for func in get_all_disks get_disk_info add_fstab_entry_safe; do
    eval "original_$func() { $(declare -f $func | sed '1d'); }"
    eval "$func() { _show_migration_warning; original_$func \"\$@\"; }"
done
EOF
```

## 📊 테스트 및 검증

### 마이그레이션 테스트 스크립트
```bash
cat > migration/test_migration.sh << 'EOF'
#!/bin/bash

# ===================================================================================
# migration/test_migration.sh - 마이그레이션 검증 스크립트
# ===================================================================================

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 로그 함수
log_test() { echo -e "${GREEN}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 테스트 카운터
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# 테스트 실행 함수
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    log_test "테스트 실행: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        ((TESTS_PASSED++))
        log_pass "$test_name"
        return 0
    else
        ((TESTS_FAILED++))
        log_fail "$test_name"
        return 1
    fi
}

# Foundation 계층 테스트
test_foundation_layer() {
    log_test "Foundation 계층 테스트 시작"
    
    run_test "core.sh 로드" "source lib/foundation/core.sh"
    run_test "logging.sh 로드" "source lib/foundation/logging.sh"
    run_test "init_environment 함수" "declare -f init_environment >/dev/null"
    run_test "로그 함수들" "declare -f log_info log_error log_warning >/dev/null"
}

# Utils 계층 테스트
test_utils_layer() {
    log_test "Utils 계층 테스트 시작"
    
    run_test "shell.sh 로드" "source lib/utils/shell.sh"
    run_test "ui.sh 로드" "source lib/utils/ui.sh"
    run_test "safe_execute 함수" "declare -f safe_execute >/dev/null"
    run_test "table 함수들" "declare -f table_start table_row table_end >/dev/null"
}

# System 계층 테스트
test_system_layer() {
    log_test "System 계층 테스트 시작"
    
    run_test "disk.sh 로드" "source lib/system/disk.sh"
    run_test "mount.sh 로드" "source lib/system/mount.sh"
    run_test "디스크 함수들" "declare -f get_all_disks get_disk_info >/dev/null"
    run_test "마운트 함수들" "declare -f mount_device unmount_device >/dev/null"
}

# Services 계층 테스트
test_services_layer() {
    log_test "Services 계층 테스트 시작"
    
    run_test "disk_service.sh 로드" "source lib/services/disk_service.sh"
    run_test "디스크 서비스 함수들" "declare -f disk_service_list_available disk_service_analyze_health >/dev/null"
}

# API 계층 테스트
test_api_layer() {
    log_test "API 계층 테스트 시작"
    
    run_test "storage_api.sh 로드" "source lib/api/storage_api.sh"
    run_test "스토리지 API 함수들" "declare -f storage_api_complete_disk_setup storage_api_setup_raid_with_fstab >/dev/null"
}

# CLI 테스트
test_cli() {
    log_test "CLI 테스트 시작"
    
    run_test "메인 CLI 실행" "bin/ubuntu-disk-toolkit help >/dev/null"
    run_test "버전 확인" "bin/ubuntu-disk-toolkit version | grep -q '4.0.0'"
}

# 호환성 테스트
test_compatibility() {
    log_test "호환성 테스트 시작"
    
    run_test "v3 호환성 레이어" "source lib/compat/v3_compat.sh"
    run_test "기존 함수 매핑" "declare -f get_all_disks add_fstab_entry_safe >/dev/null"
}

# 테스트 모드 검증 (테스트 행 문제 해결 확인)
test_safe_mode() {
    log_test "안전 모드 테스트 시작"
    
    export TESTING_MODE=true
    export DRY_RUN=true
    
    run_test "테스트 모드 환경변수" "[[ \$TESTING_MODE == 'true' && \$DRY_RUN == 'true' ]]"
    run_test "safe_execute 모킹" "source lib/utils/shell.sh && safe_execute 'parted -s /dev/test mkpart primary 0% 100%' | grep -q 'MOCK'"
    
    unset TESTING_MODE DRY_RUN
}

# 메인 테스트 실행
main() {
    log_test "Ubuntu Disk Toolkit v4.0 마이그레이션 검증 시작"
    echo ""
    
    test_foundation_layer
    test_utils_layer
    test_system_layer
    test_services_layer
    test_api_layer
    test_cli
    test_compatibility
    test_safe_mode
    
    echo ""
    echo "=========================================="
    echo "테스트 결과 요약"
    echo "=========================================="
    echo "전체 테스트: $TESTS_TOTAL"
    echo "통과: $TESTS_PASSED"
    echo "실패: $TESTS_FAILED"
    echo "성공률: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_pass "모든 테스트가 통과했습니다! 마이그레이션이 성공적으로 완료되었습니다."
        return 0
    else
        log_fail "$TESTS_FAILED개의 테스트가 실패했습니다. 문제를 해결한 후 다시 실행하세요."
        return 1
    fi
}

main "$@"
EOF

chmod +x migration/test_migration.sh
```

## 📋 마이그레이션 체크리스트

### ✅ 완료해야 할 작업들

#### Phase 0: 사전 준비
- [ ] 전체 프로젝트 백업
- [ ] 현재 테스트 결과 기록
- [ ] 의존성 매핑 문서화
- [ ] 마이그레이션 디렉토리 구조 생성

#### Phase 1: Foundation Layer
- [ ] `core.sh` 생성 및 기본 상수 이동
- [ ] `logging.sh` 생성 및 로깅 함수 이동
- [ ] `config.sh` 생성 및 설정 함수 이동
- [ ] 호환성 레이어 생성

#### Phase 2: Utils Layer
- [ ] `shell.sh` 생성 및 **safe_execute 이동** (최우선!)
- [ ] `ui.sh` 생성 및 UI 함수 이동
- [ ] `validation.sh` 생성 및 검증 함수 이동
- [ ] 기존 코드 호환성 확인

#### Phase 3: System Layer  
- [ ] `disk.sh` 생성 및 디스크 함수 이동
- [ ] `mount.sh` 생성 및 마운트 함수 이동
- [ ] `hardware.sh` 생성 및 하드웨어 함수 이동
- [ ] 의존성 순환 문제 해결

#### Phase 4: Services Layer
- [ ] `disk_service.sh` 생성 및 디스크 API 통합
- [ ] `fstab_service.sh` 생성 및 fstab API 통합  
- [ ] `raid_service.sh` 생성 및 RAID API 통합
- [ ] 서비스 인터페이스 표준화

#### Phase 5: API Layer
- [ ] `storage_api.sh` 생성 및 통합 워크플로우 구현
- [ ] `analysis_api.sh` 생성 및 분석 기능 통합
- [ ] `automation_api.sh` 생성 및 자동화 기능 구현
- [ ] 기존 API와 호환성 유지

#### Phase 6: CLI 개선
- [ ] 새로운 통합 CLI 구현
- [ ] 카테고리별 명령어 라우팅
- [ ] 기존 명령어와 호환성 유지
- [ ] 도움말 시스템 개선

### ⚠️ 주의사항

1. **테스트 행 문제 해결이 최우선**
   - `safe_execute` 함수를 `utils/shell.sh`로 이동하는 것이 가장 중요
   - 테스트 모드에서 위험한 명령어를 모킹하도록 개선

2. **단계별 검증 필수**
   - 각 Phase 완료 후 반드시 테스트 실행
   - 호환성 깨짐 없이 기존 기능 유지

3. **백업 및 롤백 계획**
   - 각 단계마다 중간 백업 생성
   - 문제 발생시 즉시 롤백 가능하도록 준비

4. **문서화 업데이트**
   - 새로운 아키텍처에 맞춰 README.md 업데이트
   - API 문서 및 사용 가이드 갱신

이 마이그레이션 가이드를 따라 진행하면 기존 기능을 유지하면서도 새로운 5층 계층 아키텍처의 이점을 모두 얻을 수 있습니다. 특히 **테스트 행 문제**는 Phase 2에서 완전히 해결될 것입니다!
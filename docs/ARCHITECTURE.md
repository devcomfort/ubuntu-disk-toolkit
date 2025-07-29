# Ubuntu Disk Toolkit - Architecture Documentation

## 📖 개요

Ubuntu Disk Toolkit은 5층 계층 아키텍처를 기반으로 한 모듈형 스토리지 관리 시스템입니다. 각 계층은 명확한 책임을 가지며, 단방향 의존성을 통해 안정성과 확장성을 보장합니다.

## 🏗️ 아키텍처 개요

### 설계 원칙

1. **계층 분리 (Layered Architecture)**
   - 5개 계층으로 기능 분리
   - 상위 계층에서 하위 계층으로만 의존
   - 계층 내 순환 의존성 금지

2. **단일 책임 원칙 (Single Responsibility)**
   - 각 모듈은 하나의 명확한 책임
   - 기능별 명확한 경계 설정

3. **의존성 역전 (Dependency Inversion)**
   - 인터페이스 기반 통신
   - 구체적 구현에 의존하지 않음

4. **확장성 (Extensibility)**
   - 새로운 모듈 추가 용이
   - 기존 코드 수정 최소화

## 📊 계층 구조

```
┌─────────────────────────────────────────────────────────────┐
│                    Layer 5: CLI Interfaces                 │
│  ubuntu-disk-toolkit  udt-disk  udt-raid  udt-fstab       │
└─────────────────────────────────────────────────────────────┘
                                ↑
┌─────────────────────────────────────────────────────────────┐
│                  Layer 4: Application APIs                 │
│  storage_api  management_api  analysis_api  automation_api │
└─────────────────────────────────────────────────────────────┘
                                ↑
┌─────────────────────────────────────────────────────────────┐
│                  Layer 3: Domain Services                  │
│  disk_service  raid_service  fstab_service  id_service     │
└─────────────────────────────────────────────────────────────┘
                                ↑
┌─────────────────────────────────────────────────────────────┐
│                Layer 2: System Abstraction                 │
│  hardware  disk  filesystem_ops  mount  process            │
└─────────────────────────────────────────────────────────────┘
                                ↑
┌─────────────────────────────────────────────────────────────┐
│                    Layer 1: Utilities                      │
│  filesystem  string  validation  shell  ui                 │
└─────────────────────────────────────────────────────────────┘
                                ↑
┌─────────────────────────────────────────────────────────────┐
│                    Layer 0: Foundation                     │
│      core  logging  config  types                          │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 계층별 상세 설명

### Layer 0: Foundation (기반층)

**목적**: 시스템의 기본 토대 제공

#### 모듈 구성
- **core.sh**: 기본 상수, 환경변수, 초기화
- **logging.sh**: 통합 로깅 시스템
- **config.sh**: 설정 관리 시스템
- **types.sh**: 데이터 구조 정의

#### 주요 기능
```bash
# core.sh
declare -r PROJECT_ROOT="/usr/local/lib/ubuntu-disk-toolkit"
declare -r CONFIG_DIR="${PROJECT_ROOT}/config"
declare -r LOG_DIR="/var/log/ubuntu-disk-toolkit"

init_environment() {
    setup_directories
    load_global_config
    initialize_logging
}

# logging.sh
log_info() { local msg="$1"; echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $msg" >> "$LOG_FILE"; }
log_error() { local msg="$1"; echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $msg" >> "$LOG_FILE"; }
log_debug() { local msg="$1"; [[ "$DEBUG_MODE" == "true" ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $msg" >> "$LOG_FILE"; }

# config.sh
load_config() {
    local config_file="$1"
    [[ -f "$config_file" ]] && source "$config_file"
}

save_config() {
    local key="$1" value="$2" config_file="$3"
    echo "${key}=${value}" >> "$config_file"
}
```

### Layer 1: Utilities (유틸리티층)

**목적**: 재사용 가능한 공통 유틸리티 제공

#### 모듈 구성
- **filesystem.sh**: 파일시스템 조작
- **string.sh**: 문자열 처리
- **validation.sh**: 기본 검증 함수
- **shell.sh**: 쉘 유틸리티 (safe_execute 등)
- **ui.sh**: UI 컴포넌트

#### 핵심 기능: safe_execute
```bash
# utils/shell.sh
safe_execute() {
    local cmd="$1"
    local description="${2:-"명령어 실행"}"
    
    # 테스트 모드 검사 (테스트 행 문제 해결!)
    if [[ "${TESTING_MODE:-false}" == "true" || "${DRY_RUN:-false}" == "true" ]]; then
        local dangerous_patterns=(
            "parted.*mkpart"
            "mkfs\."
            "dd.*of=/dev/"
            "shred.*"
            "mdadm.*--create"
            "fdisk.*"
            "wipefs.*"
        )
        
        for pattern in "${dangerous_patterns[@]}"; do
            if [[ "$cmd" =~ $pattern ]]; then
                log_info "[MOCK] 위험한 명령어 시뮬레이션: $cmd"
                echo "[MOCK] $description 시뮬레이션 완료"
                return 0
            fi
        done
    fi
    
    log_info "명령어 실행: $cmd"
    eval "$cmd"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "$description 성공"
    else
        log_error "$description 실패 (exit code: $exit_code)"
    fi
    
    return $exit_code
}

confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "${AUTO_CONFIRM:-false}" == "true" ]]; then
        return 0
    fi
    
    echo -n "$message (y/N): "
    read -r response
    [[ "${response,,}" =~ ^y(es)?$ ]]
}
```

#### UI 컴포넌트
```bash
# utils/ui.sh
table_start() {
    printf "┌─────────────────────────────────────────────────────────────┐\n"
}

table_row() {
    local col1="$1" col2="$2" col3="$3"
    printf "│ %-20s │ %-20s │ %-15s │\n" "$col1" "$col2" "$col3"
}

table_end() {
    printf "└─────────────────────────────────────────────────────────────┘\n"
}

show_progress() {
    local current="$1" total="$2" message="$3"
    local percentage=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percentage * bar_length / 100))
    
    printf "\r%s [" "$message"
    for ((i=0; i<filled_length; i++)); do printf "█"; done
    for ((i=filled_length; i<bar_length; i++)); do printf "░"; done
    printf "] %d%%" "$percentage"
}
```

### Layer 2: System Abstraction (시스템 추상화층)

**목적**: 운영체제 및 하드웨어와의 상호작용 추상화

#### 모듈 구성
- **hardware.sh**: 하드웨어 정보 수집
- **disk.sh**: 디스크 기본 조작
- **filesystem_ops.sh**: 파일시스템 조작
- **mount.sh**: 마운트/언마운트
- **process.sh**: 프로세스 관리

#### 주요 기능
```bash
# system/disk.sh
get_all_disks() {
    lsblk -ndo NAME,SIZE,TYPE | grep disk
}

get_disk_info() {
    local device="$1"
    {
        echo "Device: $device"
        echo "Size: $(lsblk -ndo SIZE "$device" 2>/dev/null)"
        echo "Model: $(lsblk -ndo MODEL "$device" 2>/dev/null)"
        echo "Serial: $(lsblk -ndo SERIAL "$device" 2>/dev/null)"
    }
}

is_disk_mounted() {
    local device="$1"
    findmnt -rn -S "$device" >/dev/null 2>&1
}

# system/mount.sh
mount_device() {
    local device="$1" mountpoint="$2" options="${3:-defaults}"
    
    validate_device "$device" || return 1
    validate_mountpoint "$mountpoint" || return 1
    
    if is_disk_mounted "$device"; then
        log_warning "디바이스 $device는 이미 마운트되어 있습니다"
        return 1
    fi
    
    safe_execute "mount -o $options $device $mountpoint" "디바이스 마운트"
}

unmount_device() {
    local target="$1"
    local force="${2:-false}"
    
    if [[ "$force" == "true" ]]; then
        safe_execute "umount -f $target" "강제 언마운트"
    else
        safe_execute "umount $target" "언마운트"
    fi
}
```

### Layer 3: Domain Services (도메인 서비스층)

**목적**: 비즈니스 로직과 도메인 규칙 구현

#### 모듈 구성
- **disk_service.sh**: 디스크 관리 서비스
- **raid_service.sh**: RAID 관리 서비스
- **fstab_service.sh**: fstab 관리 서비스
- **id_service.sh**: ID 해석 서비스
- **safety_service.sh**: 안전장치 서비스

#### 서비스 인터페이스
```bash
# services/disk_service.sh
disk_service_list_available() {
    local format="${1:-table}"
    local available_disks=()
    
    while IFS= read -r disk; do
        if ! is_disk_mounted "$disk" && ! is_raid_member "$disk"; then
            available_disks+=("$disk")
        fi
    done < <(get_all_disks | awk '{print $1}')
    
    case "$format" in
        "table") format_disk_table "${available_disks[@]}" ;;
        "json") format_disk_json "${available_disks[@]}" ;;
        "simple") printf '%s\n' "${available_disks[@]}" ;;
    esac
}

disk_service_analyze_health() {
    local device="$1"
    local report_file="${2:-/tmp/disk_health_$(date +%s).report}"
    
    {
        echo "=== 디스크 건강 분석 보고서 ==="
        echo "분석 시간: $(date)"
        echo "대상 디바이스: $device"
        echo ""
        
        echo "=== 기본 정보 ==="
        get_disk_info "$device"
        
        echo ""
        echo "=== SMART 정보 ==="
        check_disk_smart "$device"
        
        echo ""
        echo "=== 마운트 상태 ==="
        if is_disk_mounted "$device"; then
            echo "마운트됨: $(findmnt -rn -S "$device" -o TARGET)"
        else
            echo "마운트되지 않음"
        fi
        
    } > "$report_file"
    
    echo "$report_file"
}

# services/raid_service.sh
raid_service_create() {
    local raid_level="$1"
    local devices=("${@:2}")
    local array_name="md$(get_next_md_number)"
    
    # 사전 검증
    for device in "${devices[@]}"; do
        validate_disk_available_for_raid "$device" || {
            log_error "RAID에 사용할 수 없는 디스크: $device"
            return 1
        }
    done
    
    # RAID 호환성 검사
    validate_disks_raid_compatible "$raid_level" "${devices[@]}" || return 1
    
    # RAID 생성
    local mdadm_cmd="mdadm --create /dev/$array_name --level=$raid_level --raid-devices=${#devices[@]} ${devices[*]}"
    safe_execute "$mdadm_cmd" "RAID $raid_level 배열 생성"
    
    # 설정 저장
    safe_execute "mdadm --detail --scan >> /etc/mdadm/mdadm.conf" "RAID 설정 저장"
    safe_execute "update-initramfs -u" "initramfs 업데이트"
    
    echo "/dev/$array_name"
}

# services/fstab_service.sh
fstab_service_add_entry() {
    local device="$1" mountpoint="$2" filesystem="$3" options="${4:-defaults}"
    
    # 안전성 검사
    validate_fstab_entry "$device" "$mountpoint" "$filesystem" "$options" || return 1
    
    # fail-safe 옵션 자동 적용
    local safe_options
    safe_options=$(apply_fail_safe_options "$options" "$filesystem")
    
    # 백업 생성
    create_backup "/etc/fstab"
    
    # ID 기반 식별자 사용
    local identifier
    identifier=$(get_fstab_identifier "$device")
    
    # fstab 항목 추가
    echo "$identifier $mountpoint $filesystem $safe_options 0 2" >> /etc/fstab
    
    # 검증
    validate_fstab_file || {
        log_error "fstab 파일 검증 실패, 백업에서 복원합니다"
        restore_backup "/etc/fstab"
        return 1
    }
    
    log_info "fstab 항목이 성공적으로 추가되었습니다: $mountpoint"
}
```

### Layer 4: Application APIs (애플리케이션 API층)

**목적**: 고수준 워크플로우와 복합 작업 제공

#### 모듈 구성
- **storage_api.sh**: 통합 스토리지 API
- **management_api.sh**: 관리 작업 API
- **analysis_api.sh**: 분석 및 진단 API
- **automation_api.sh**: 자동화 워크플로우 API

#### 통합 워크플로우
```bash
# api/storage_api.sh
storage_api_setup_raid_with_fstab() {
    local raid_level="$1" mountpoint="$2" filesystem="${3:-ext4}"
    local devices=("${@:4}")
    
    print_header "RAID 설정 및 fstab 통합 구성"
    
    # Step 1: RAID 생성
    print_step "1/4" "RAID $raid_level 배열 생성"
    local raid_device
    raid_device=$(raid_service_create "$raid_level" "${devices[@]}") || return 1
    
    # Step 2: 파일시스템 생성
    print_step "2/4" "파일시스템 생성 ($filesystem)"
    safe_execute "mkfs.$filesystem $raid_device" "파일시스템 생성"
    
    # Step 3: 마운트포인트 생성
    print_step "3/4" "마운트포인트 생성"
    safe_execute "mkdir -p $mountpoint" "디렉토리 생성"
    
    # Step 4: fstab 등록
    print_step "4/4" "fstab 자동 등록"
    fstab_service_add_entry "$raid_device" "$mountpoint" "$filesystem" "defaults,nofail"
    
    # 테스트 마운트
    print_info "설정 검증을 위한 테스트 마운트..."
    mount "$mountpoint" && {
        print_success "RAID 설정이 완료되었습니다!"
        print_info "RAID 디바이스: $raid_device"
        print_info "마운트포인트: $mountpoint"
        print_info "파일시스템: $filesystem"
    }
}

# api/analysis_api.sh
analysis_api_comprehensive_report() {
    local output_file="${1:-/tmp/system_analysis_$(date +%s).html}"
    
    {
        cat << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Ubuntu Disk Toolkit - 종합 분석 보고서</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #333; color: white; padding: 20px; text-align: center; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; }
        .success { color: green; } .warning { color: orange; } .error { color: red; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Ubuntu Disk Toolkit</h1>
        <h2>종합 시스템 분석 보고서</h2>
        <p>생성 시간: $(date)</p>
    </div>
EOF

        echo '<div class="section">'
        echo '<h2>🖥️ 시스템 정보</h2>'
        echo '<table>'
        echo '<tr><th>항목</th><th>값</th></tr>'
        echo "<tr><td>호스트명</td><td>$(hostname)</td></tr>"
        echo "<tr><td>운영체제</td><td>$(lsb_release -d | cut -f2)</td></tr>"
        echo "<tr><td>커널</td><td>$(uname -r)</td></tr>"
        echo "<tr><td>메모리</td><td>$(free -h | awk '/^Mem:/ {print $2}')</td></tr>"
        echo '</table>'
        echo '</div>'

        echo '<div class="section">'
        echo '<h2>💽 디스크 상태</h2>'
        disk_service_list_available "html"
        echo '</div>'

        echo '<div class="section">'
        echo '<h2>🔗 RAID 배열</h2>'
        raid_service_list_arrays "html"
        echo '</div>'

        echo '<div class="section">'
        echo '<h2>📁 fstab 구성</h2>'
        fstab_service_list_entries "html"
        echo '</div>'

        echo '</body></html>'
        
    } > "$output_file"
    
    echo "$output_file"
}
```

### Layer 5: CLI Interfaces (CLI 인터페이스층)

**목적**: 사용자 인터페이스와 명령어 라우팅

#### 통합 라우터 (ubuntu-disk-toolkit)
```bash
#!/bin/bash
# bin/ubuntu-disk-toolkit

# 의존성 로드
source "$(dirname "$0")/../lib/foundation/core.sh"
load_layer "foundation"
load_layer "utils" 
load_layer "system"
load_layer "services"
load_layer "api"

show_main_menu() {
    echo "Ubuntu Disk Toolkit v3.0.0"
    echo ""
    echo "사용법: ubuntu-disk-toolkit <명령어> [옵션]"
    echo ""
    echo "주요 명령어:"
    echo "  📀 disk <subcommand>     디스크 관리"
    echo "  🔗 raid <subcommand>     RAID 관리"  
    echo "  📁 fstab <subcommand>    fstab 관리"
    echo "  🔧 system <subcommand>   시스템 관리"
    echo "  📊 analyze               종합 분석"
    echo ""
    echo "도움말: ubuntu-disk-toolkit help <명령어>"
}

route_command() {
    local category="$1"
    shift
    
    case "$category" in
        "disk")
            exec "$(dirname "$0")/udt-disk" "$@"
            ;;
        "raid")
            exec "$(dirname "$0")/udt-raid" "$@"
            ;;
        "fstab")
            exec "$(dirname "$0")/udt-fstab" "$@"
            ;;
        "system")
            exec "$(dirname "$0")/udt-system" "$@"
            ;;
        "analyze")
            analysis_api_comprehensive_report "$@"
            ;;
        "help"|"--help"|"-h")
            show_main_menu
            ;;
        *)
            echo "알 수 없는 명령어: $category"
            show_main_menu
            return 1
            ;;
    esac
}

main() {
    if [[ $# -eq 0 ]]; then
        show_main_menu
        return 0
    fi
    
    route_command "$@"
}

main "$@"
```

#### 전용 CLI (udt-disk)
```bash
#!/bin/bash
# bin/udt-disk

source "$(dirname "$0")/../lib/foundation/core.sh"
load_required_layers "disk_service"

show_disk_menu() {
    echo "Ubuntu Disk Toolkit - 디스크 관리"
    echo ""
    echo "사용법: udt-disk <명령어> [옵션]"
    echo ""
    echo "명령어:"
    echo "  list [format]           사용 가능한 디스크 목록"
    echo "  info <device>           디스크 상세 정보"
    echo "  health <device>         디스크 건강 상태 분석"
    echo "  mount <device> <point>  디스크 마운트"
    echo "  unmount <target>        디스크 언마운트"
    echo ""
    echo "형식:"
    echo "  table, json, simple     출력 형식 선택"
}

main() {
    local command="${1:-list}"
    shift
    
    case "$command" in
        "list")
            disk_service_list_available "${1:-table}"
            ;;
        "info")
            [[ -z "$1" ]] && { echo "디바이스를 지정하세요"; return 1; }
            disk_service_analyze_health "$1"
            ;;
        "health")
            [[ -z "$1" ]] && { echo "디바이스를 지정하세요"; return 1; }
            disk_service_analyze_health "$1"
            ;;
        "mount")
            [[ $# -lt 2 ]] && { echo "디바이스와 마운트포인트를 지정하세요"; return 1; }
            mount_device "$1" "$2" "${3:-defaults}"
            ;;
        "unmount")
            [[ -z "$1" ]] && { echo "언마운트할 대상을 지정하세요"; return 1; }
            unmount_device "$1"
            ;;
        "help"|"--help"|"-h")
            show_disk_menu
            ;;
        *)
            echo "알 수 없는 명령어: $command"
            show_disk_menu
            return 1
            ;;
    esac
}

main "$@"
```

## 🔄 의존성 관리

### 모듈 로더 시스템

```bash
# foundation/loader.sh
declare -A LOADED_MODULES
declare -A MODULE_DEPENDENCIES

register_module() {
    local module="$1"
    local dependencies=("${@:2}")
    MODULE_DEPENDENCIES["$module"]="${dependencies[*]}"
}

load_module() {
    local module="$1"
    
    # 이미 로드된 경우 스킵
    [[ "${LOADED_MODULES[$module]}" == "true" ]] && return 0
    
    # 의존성 먼저 로드
    if [[ -n "${MODULE_DEPENDENCIES[$module]}" ]]; then
        for dep in ${MODULE_DEPENDENCIES[$module]}; do
            load_module "$dep"
        done
    fi
    
    # 모듈 로드
    local module_path="$LIB_DIR/$module.sh"
    if [[ -f "$module_path" ]]; then
        source "$module_path"
        LOADED_MODULES["$module"]="true"
        log_debug "모듈 로드됨: $module"
    else
        log_error "모듈을 찾을 수 없음: $module_path"
        return 1
    fi
}

load_layer() {
    local layer="$1"
    case "$layer" in
        "foundation")
            load_module "foundation/core"
            load_module "foundation/logging"
            load_module "foundation/config"
            ;;
        "utils")
            load_layer "foundation"
            load_module "utils/shell"
            load_module "utils/ui"
            load_module "utils/validation"
            ;;
        "system")
            load_layer "utils"
            load_module "system/disk"
            load_module "system/mount"
            load_module "system/hardware"
            ;;
        "services")
            load_layer "system"
            load_module "services/disk_service"
            load_module "services/raid_service"
            load_module "services/fstab_service"
            ;;
        "api")
            load_layer "services"
            load_module "api/storage_api"
            load_module "api/analysis_api"
            ;;
    esac
}
```

### 의존성 검증

```bash
# utils/validation.sh
validate_dependencies() {
    local module="$1"
    local required_commands=("${@:2}")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "필수 명령어가 없습니다: $cmd (모듈: $module)"
            return 1
        fi
    done
    
    return 0
}

validate_module_interface() {
    local module="$1"
    local required_functions=("${@:2}")
    
    for func in "${required_functions[@]}"; do
        if ! declare -f "$func" >/dev/null 2>&1; then
            log_error "필수 함수가 없습니다: $func (모듈: $module)"
            return 1
        fi
    done
    
    return 0
}
```

## 🧪 테스트 전략

### 계층별 테스트

```bash
# tests/unit/foundation/test_core.bats
@test "core.sh: init_environment 함수 테스트" {
    source lib/foundation/core.sh
    
    run init_environment
    [ "$status" -eq 0 ]
    [ -d "$LOG_DIR" ]
    [ -f "$CONFIG_FILE" ]
}

# tests/unit/utils/test_shell.bats  
@test "shell.sh: safe_execute 테스트 모드" {
    source lib/utils/shell.sh
    
    export TESTING_MODE=true
    run safe_execute "parted -s /dev/test mkpart primary 0% 100%"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "MOCK" ]]
}

# tests/integration/test_storage_workflow.bats
@test "통합 워크플로우: RAID + fstab 설정" {
    # Mock 디스크 준비
    setup_mock_disks "/dev/mock1" "/dev/mock2"
    
    # API 호출
    run storage_api_setup_raid_with_fstab "1" "/mnt/test" "ext4" "/dev/mock1" "/dev/mock2"
    
    [ "$status" -eq 0 ]
    [ -f "/etc/fstab.backup" ]
    grep -q "/mnt/test" /etc/fstab
}
```

## 📊 성능 최적화

### Lazy Loading

```bash
# 필요할 때만 모듈 로드
disk_service_list_available() {
    ensure_loaded "system/disk" "system/mount"
    # 실제 구현
}

ensure_loaded() {
    local modules=("$@")
    for module in "${modules[@]}"; do
        load_module "$module"
    done
}
```

### 캐싱 시스템

```bash
# 시스템 정보 캐싱
declare -A DISK_CACHE
declare -A CACHE_TIMESTAMPS

get_disk_info_cached() {
    local device="$1"
    local cache_ttl=300  # 5분
    local current_time=$(date +%s)
    
    if [[ -n "${DISK_CACHE[$device]}" ]]; then
        local cache_time="${CACHE_TIMESTAMPS[$device]}"
        if (( current_time - cache_time < cache_ttl )); then
            echo "${DISK_CACHE[$device]}"
            return 0
        fi
    fi
    
    # 새로운 정보 수집
    local info=$(get_disk_info "$device")
    DISK_CACHE["$device"]="$info"
    CACHE_TIMESTAMPS["$device"]="$current_time"
    
    echo "$info"
}
```

## 🚀 마이그레이션 가이드

### 기존 코드에서 새 아키텍처로

1. **함수 매핑**
   ```bash
   # 기존 → 새 구조
   common.sh:safe_execute() → utils/shell.sh:safe_execute()
   disk-functions.sh:get_all_disks() → system/disk.sh:get_all_disks()
   fstab-api.sh:fstab_add_entry_safe() → services/fstab_service.sh:fstab_service_add_entry()
   ```

2. **단계별 전환**
   - Phase 1: Foundation 구축
   - Phase 2: 기존 함수를 새 모듈로 이동
   - Phase 3: 의존성 정리
   - Phase 4: API 통합
   - Phase 5: CLI 개선

3. **호환성 레이어**
   ```bash
   # lib/compat.sh - 기존 코드 호환성
   add_fstab_entry_safe() {
       # 기존 함수 이름으로 새 API 호출
       fstab_service_add_entry "$@"
   }
   ```

## 📋 결론

이 5층 계층 아키텍처는 다음과 같은 이점을 제공합니다:

1. **명확한 관심사 분리**: 각 계층이 명확한 책임을 가짐
2. **테스트 용이성**: 계층별 독립적 테스트 가능
3. **확장성**: 새로운 기능 추가가 용이
4. **유지보수성**: 순환 의존성 제거로 안정적 코드
5. **성능**: Lazy loading과 캐싱으로 최적화

특히 **테스트 행 문제**는 `utils/shell.sh`의 `safe_execute()` 함수에서 테스트 모드 검사를 통해 해결되며, 모든 위험한 시스템 명령어를 안전하게 모킹할 수 있습니다.
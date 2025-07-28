#!/bin/bash

# ===================================================================================
# run-tests.sh - bats 테스트 실행 스크립트
# ===================================================================================

set -euo pipefail

# 색상 출력 설정
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 프로젝트 루트 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TESTS_DIR="${SCRIPT_DIR}"

# 기본 설정
VERBOSE=false
PARALLEL=false
COVERAGE=false
SPECIFIC_TEST=""
OUTPUT_FORMAT="pretty"

# 사용법 표시
show_usage() {
    cat << 'EOF'

run-tests.sh - Ubuntu Disk Toolkit bats 테스트 실행기

사용법:
  ./run-tests.sh [옵션] [테스트파일]

옵션:
  -v, --verbose     상세 출력 모드
  -p, --parallel    병렬 테스트 실행
  -c, --coverage    커버리지 수집 (experimental)
  -f, --format      출력 형식 (pretty, tap, junit)
  -h, --help        도움말 표시

예시:
  ./run-tests.sh                        # 모든 테스트 실행
  ./run-tests.sh test_common.bats       # 특정 테스트 파일 실행
  ./run-tests.sh -v -p                  # 상세 모드로 병렬 실행
  ./run-tests.sh --format tap           # TAP 형식으로 출력

테스트 파일:
  test_common.bats      공통 함수 테스트
  test_system.bats      시스템 검사 테스트
  test_fstab.bats       fstab 관리 테스트
  test_disk.bats        디스크 관리 테스트
  test_integration.bats 통합 테스트

EOF
}

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

# bats 설치 확인
check_bats_installation() {
    if ! command -v bats &> /dev/null; then
        print_error "bats가 설치되지 않았습니다"
        print_info "다음 명령어로 설치하세요:"
        echo ""
        echo "# Ubuntu/Debian:"
        echo "sudo apt update && sudo apt install bats"
        echo ""
        echo "# 또는 npm을 통해:"
        echo "npm install -g bats"
        echo ""
        echo "# 또는 수동 설치:"
        echo "git clone https://github.com/bats-core/bats-core.git"
        echo "cd bats-core && sudo ./install.sh /usr/local"
        echo ""
        return 1
    fi
    
    print_success "bats 설치 확인됨: $(bats --version)"
    return 0
}

# 프로젝트 검증
validate_project() {
    print_header "프로젝트 구조 검증"
    
    # 필수 디렉토리 확인
    local required_dirs=("bin" "lib" "config")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "${PROJECT_ROOT}/${dir}" ]]; then
            print_success "디렉토리 확인: ${dir}"
        else
            print_error "필수 디렉토리 누락: ${dir}"
            return 1
        fi
    done
    
    # 필수 스크립트 확인
    local required_scripts=("ubuntu-disk-toolkit" "check-system" "manage-disk" "manage-fstab")
    for script in "${required_scripts[@]}"; do
        if [[ -x "${PROJECT_ROOT}/bin/${script}" ]]; then
            print_success "스크립트 확인: ${script}"
        else
            print_error "실행 가능한 스크립트 누락: ${script}"
            return 1
        fi
    done
    
    # 라이브러리 파일 확인
    local required_libs=("common.sh" "ui-functions.sh" "system-functions.sh" "disk-functions.sh" "fstab-functions.sh")
    for lib in "${required_libs[@]}"; do
        if [[ -f "${PROJECT_ROOT}/lib/${lib}" ]]; then
            print_success "라이브러리 확인: ${lib}"
        else
            print_error "라이브러리 파일 누락: ${lib}"
            return 1
        fi
    done
    
    print_success "프로젝트 구조 검증 완료"
}

# 테스트 환경 설정
setup_test_environment() {
    print_header "테스트 환경 설정"
    
    # PATH에 프로젝트 bin 디렉토리 추가
    export PATH="${PROJECT_ROOT}/bin:${PATH}"
    
    # 테스트용 환경 변수 설정
    export BATS_PROJECT_ROOT="${PROJECT_ROOT}"
    export TESTING_MODE=true
    export NO_COLOR=1
    
    print_success "테스트 환경 설정 완료"
}

# 개별 테스트 파일 실행
run_single_test() {
    local test_file="$1"
    local bats_opts=()
    
    # 형식 옵션 추가
    case "$OUTPUT_FORMAT" in
        "tap")
            bats_opts+=("--formatter" "tap")
            ;;
        "junit")
            bats_opts+=("--formatter" "junit")
            ;;
        "pretty"|*)
            bats_opts+=("--formatter" "pretty")
            ;;
    esac
    
    # 상세 모드
    if [[ "$VERBOSE" == "true" ]]; then
        # bats 1.2.1에서는 --verbose-run 옵션이 없으므로 --tap 사용
        bats_opts+=("--formatter" "tap")
    fi
    
    # 병렬 실행
    if [[ "$PARALLEL" == "true" ]]; then
        bats_opts+=("--jobs" "4")
    fi
    
    print_info "실행 중: $test_file"
    
    if bats "${bats_opts[@]}" "${TESTS_DIR}/${test_file}"; then
        print_success "테스트 통과: $test_file"
        return 0
    else
        print_error "테스트 실패: $test_file"
        return 1
    fi
}

# 모든 테스트 실행
run_all_tests() {
    local test_files=(
            "test_common.bats"
    "test_system.bats" 
    "test_fstab.bats"
    "test_disk.bats"
    "test_integration.bats"
    "test_api_integration.bats"
    )
    
    local total_tests=${#test_files[@]}
    local passed_tests=0
    local failed_tests=0
    
    print_header "전체 테스트 실행 (${total_tests}개 파일)"
    
    for test_file in "${test_files[@]}"; do
        if [[ -f "${TESTS_DIR}/${test_file}" ]]; then
            if run_single_test "$test_file"; then
                passed_tests=$((passed_tests + 1))
            else
                failed_tests=$((failed_tests + 1))
            fi
        else
            print_warning "테스트 파일을 찾을 수 없습니다: $test_file"
            failed_tests=$((failed_tests + 1))
        fi
    done
    
    # 결과 요약
    print_header "테스트 결과 요약"
    echo -e "총 테스트 파일: $total_tests"
    echo -e "통과: ${GREEN}$passed_tests${NC}"
    echo -e "실패: ${RED}$failed_tests${NC}"
    
    if [[ $failed_tests -eq 0 ]]; then
        print_success "🎉 모든 테스트가 통과했습니다!"
        return 0
    else
        print_error "💥 $failed_tests개의 테스트가 실패했습니다"
        return 1
    fi
}

# 테스트 정리
cleanup_tests() {
    print_info "테스트 환경 정리 중..."
    
    # 임시 파일 정리
    find /tmp -name "bash-raid-cli-test-*" -type d -exec rm -rf {} + 2>/dev/null || true
    
    print_success "정리 완료"
}

# 옵션 파싱
parse_options() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -p|--parallel)
                PARALLEL=true
                shift
                ;;
            -c|--coverage)
                COVERAGE=true
                print_warning "커버리지 수집은 실험적 기능입니다"
                shift
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *.bats)
                SPECIFIC_TEST="$1"
                shift
                ;;
            *)
                print_error "알 수 없는 옵션: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# 메인 함수
main() {
    print_header "Ubuntu Disk Toolkit 테스트 실행기"
    
    # 옵션 파싱
    parse_options "$@"
    
    # 사전 검사
    if ! check_bats_installation; then
        exit 1
    fi
    
    if ! validate_project; then
        exit 1
    fi
    
    # 테스트 환경 설정
    setup_test_environment
    
    # 시그널 핸들러 설정 (정리 함수)
    trap cleanup_tests EXIT
    
    # 테스트 실행
    if [[ -n "$SPECIFIC_TEST" ]]; then
        print_header "특정 테스트 실행: $SPECIFIC_TEST"
        run_single_test "$SPECIFIC_TEST"
    else
        run_all_tests
    fi
}

# 스크립트 실행
main "$@" 
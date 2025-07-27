# ubuntu-disk-toolkit Justfile
# Ubuntu Storage & Disk Management Toolkit

# 기본 변수 설정
project_name := "ubuntu-disk-toolkit"
bin_dir := "bin"
lib_dir := "lib"
tests_dir := "tests"
install_dir := "install"

# 기본 명령어 (help 표시)
default:
    @just --list

# =============================================================================
# 🚀 개발 환경 설정
# =============================================================================

# 개발 환경 초기 설정
setup *args='':
    #!/bin/bash
    echo "🚀 Ubuntu Disk Toolkit 개발 환경 설정 중..."
    if [[ "{{args}}" == *"-y"* ]] || [[ "{{args}}" == *"--yes"* ]]; then
        echo "📦 자동 설정 모드로 진행합니다..."
        just install-deps -y
    else
        just install-deps
    fi
    just permissions
    echo "✅ 개발 환경 설정 완료!"

# 시스템 의존성 설치
install-deps *args='':
    @echo "📦 시스템 의존성 설치 중..."
    @./{{install_dir}}/install-deps.sh {{args}}

# 스크립트 실행 권한 설정
permissions:
    @echo "🔧 스크립트 실행 권한 설정 중..."
    @find {{bin_dir}} -type f -exec chmod +x {} \;
    @find {{tests_dir}} -name "*.sh" -exec chmod +x {} \;
    @find {{install_dir}} -name "*.sh" -exec chmod +x {} \;
    @echo "✅ 권한 설정 완료"

# =============================================================================
# 🧪 테스트 관련
# =============================================================================

# 모든 테스트 실행
test:
    @echo "🧪 전체 테스트 실행 중..."
    @cd {{tests_dir}} && ./run-tests.sh

# =============================================================================
# 🔍 코드 품질 검사
# =============================================================================

# shellcheck로 모든 스크립트 검사
lint *args='':
    #!/bin/bash
    echo "🔍 코드 품질 검사 중..."
    
    # shellcheck 설치 확인
    if which shellcheck > /dev/null 2>&1; then
        echo "📝 shellcheck로 전체 검사 중..."
    else
        echo "⚠️ shellcheck가 설치되지 않았습니다"
        
        # 자동 설치 모드 확인
        if [[ "{{args}}" == *"-y"* ]] || [[ "{{args}}" == *"--yes"* ]]; then
            echo "🔧 shellcheck 자동 설치 중..."
            sudo apt update -qq && sudo apt install -y shellcheck
            if which shellcheck > /dev/null 2>&1; then
                echo "✅ shellcheck 설치 완료"
            else
                echo "❌ shellcheck 설치 실패. 기본 구문 검사로 대체합니다."
            fi
        else
            echo "💡 shellcheck 설치를 권장합니다 (더 정확한 검사 가능)"
            echo -n "지금 설치하시겠습니까? [y/N]: "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                echo "🔧 shellcheck 설치 중..."
                sudo apt update -qq && sudo apt install -y shellcheck
                if which shellcheck > /dev/null 2>&1; then
                    echo "✅ shellcheck 설치 완료"
                else
                    echo "❌ shellcheck 설치 실패. 기본 구문 검사로 대체합니다."
                fi
            else
                echo "ℹ️ shellcheck 설치를 건너뜁니다"
            fi
        fi
    fi
    
    # 실제 검사 수행
    if which shellcheck > /dev/null 2>&1; then
        echo "📝 bin/ 디렉토리 검사..."
        find {{bin_dir}} -name "*.sh" -o -name "*" -type f -executable | xargs shellcheck || true
        echo "📝 lib/ 디렉토리 검사..."
        find {{lib_dir}} -name "*.sh" | xargs shellcheck || true
        echo "📝 tests/ 디렉토리 검사..."
        find {{tests_dir}} -name "*.sh" -o -name "*.bash" | xargs shellcheck || true
        echo "✅ shellcheck 코드 검사 완료"
    else
        echo "ℹ️ 기본적인 구문 검사로 대체합니다..."
        find {{bin_dir}} {{lib_dir}} {{tests_dir}} -name "*.sh" -exec bash -n {} \; && echo "✅ 구문 검사 완료"
    fi

# shellcheck 설치 확인 및 설치
lint-install *args='':
    #!/bin/bash
    echo "🔧 shellcheck 설치 확인..."
    
    if which shellcheck > /dev/null 2>&1; then
        echo "✅ shellcheck가 이미 설치되어 있습니다"
        shellcheck --version | head -1
    else
        echo "⚠️ shellcheck가 설치되지 않았습니다"
        echo "💡 shellcheck는 shell 스크립트의 품질을 크게 향상시킵니다"
        
        # 자동 설치 모드 확인
        if [[ "{{args}}" == *"-y"* ]] || [[ "{{args}}" == *"--yes"* ]]; then
            echo "🔧 shellcheck 자동 설치 중..."
            sudo apt update -qq && sudo apt install -y shellcheck
            if which shellcheck > /dev/null 2>&1; then
                echo "✅ shellcheck 설치 완료"
                shellcheck --version | head -1
            else
                echo "❌ shellcheck 설치 실패"
                exit 1
            fi
        else
            echo -n "지금 설치하시겠습니까? [y/N]: "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                echo "🔧 shellcheck 설치 중..."
                sudo apt update -qq && sudo apt install -y shellcheck
                if which shellcheck > /dev/null 2>&1; then
                    echo "✅ shellcheck 설치 완료"
                    shellcheck --version | head -1
                else
                    echo "❌ shellcheck 설치 실패"
                    exit 1
                fi
            else
                echo "ℹ️ 설치를 건너뜁니다"
                echo "💡 나중에 수동으로 설치하려면: sudo apt install shellcheck"
            fi
        fi
    fi

# =============================================================================
# 🚀 실행 및 데모
# =============================================================================

# 메인 CLI 도움말 표시
help:
    @./{{bin_dir}}/ubuntu-disk-toolkit --help

# 시스템 정보 확인
info:
    @echo "💻 시스템 정보 확인 중..."
    @./{{bin_dir}}/ubuntu-disk-toolkit check-system info

# 디스크 목록 확인
disks:
    @echo "💾 디스크 목록 확인 중..."
    @./{{bin_dir}}/ubuntu-disk-toolkit list-disks

# RAID 상태 확인
raids:
    @echo "⚡ RAID 상태 확인 중..."
    @./{{bin_dir}}/ubuntu-disk-toolkit list-raids

# 종합 시스템 검사 (데모용)
demo:
    @echo "🎮 Ubuntu Disk Toolkit 데모"
    @echo "================================"
    @just help
    @echo ""
    @just info
    @echo ""
    @just disks

# =============================================================================
# 🏗️ 설치
# =============================================================================

# 프로덕션 설치
install *args='':
    @echo "🏗️ 시스템 설치 중..."
    @sudo ./{{install_dir}}/install.sh {{args}}
    @echo "✅ 설치 완료"

# 프로덕션 제거
uninstall *args='':
    @echo "🗑️ 시스템 제거 중..."
    @sudo ./{{install_dir}}/uninstall.sh {{args}}
    @echo "✅ 제거 완료"

# =============================================================================
# 🧹 정리
# =============================================================================

# 임시 파일 정리
clean:
    @echo "🧹 임시 파일 정리 중..."
    @find . -name "*~" -delete 2>/dev/null || true
    @find . -name "*.backup.*" -delete 2>/dev/null || true
    @find /tmp -name "ubuntu-disk-toolkit-test-*" -type d -exec rm -rf {} + 2>/dev/null || true
    @rm -f *.tar.gz 2>/dev/null || true
    @echo "✅ 정리 완료"

# =============================================================================
# 📚 정보
# =============================================================================

# 프로젝트 정보 표시
status:
    @echo "📊 Ubuntu Disk Toolkit 프로젝트 상태"
    @echo "======================================"
    @echo "📁 프로젝트: {{project_name}}"
    @echo "📂 경로: $(pwd)"
    @echo "🔧 스크립트: $(find {{bin_dir}} -type f | wc -l)개"
    @echo "📚 라이브러리: $(find {{lib_dir}} -name "*.sh" | wc -l)개"
    @echo "🧪 테스트: $(find {{tests_dir}} -name "*.bats" | wc -l)개"
    @echo "💾 크기: $(du -sh . | cut -f1)"
    @echo ""
    @echo "🚀 개발 가이드:"
    @echo "  just setup          # 개발 환경 설정"
    @echo "  just setup -y       # 자동 설정 (CI/CD용)"
    @echo "  just test           # 테스트 실행"  
    @echo "  just lint           # 코드 검사 (shellcheck 자동 설치 제안)"
    @echo "  just lint -y        # 코드 검사 (shellcheck 자동 설치)"
    @echo "  just lint-install   # shellcheck 설치 확인/설치"
    @echo "  just install -y     # 자동 설치"
    @echo "  just demo           # 기능 데모"

# =============================================================================
# 🚨 트러블슈팅
# =============================================================================

# 시스템 호환성 검사
check-system:
    @echo "🔍 시스템 호환성 검사 중..."
    @./{{bin_dir}}/ubuntu-disk-toolkit check-system requirements 
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
            echo "🔧 자동으로 shellcheck를 설치합니다..."
            sudo apt update && sudo apt install -y shellcheck
        else
            echo ""
            echo "다음 명령어로 설치하세요:"
            echo "  sudo apt install shellcheck"
            echo ""
            read -p "지금 설치하시겠습니까? [y/N]: " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo apt update && sudo apt install -y shellcheck
            else
                echo "⚠️ shellcheck 없이 기본 문법 검사만 수행합니다"
                echo ""
                # bash 기본 문법 검사로 폴백
                find bin lib -name "*.sh" -o -name "ubuntu-disk-toolkit" -o -name "check-system" -o -name "manage-*" | while read -r file; do
                    echo "📝 $file"
                    bash -n "$file" || echo "❌ 문법 오류: $file"
                done
                return 0
            fi
        fi
    fi
    
    # shellcheck 실행
    if which shellcheck > /dev/null 2>&1; then
        find bin lib -name "*.sh" -o -name "ubuntu-disk-toolkit" -o -name "check-system" -o -name "manage-*" | while read -r file; do
            echo "📝 $file"
            shellcheck "$file"
        done
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

# =============================================================================
# 🆘 도움말 및 정보
# =============================================================================

# 메인 CLI 도움말 표시
help:
    @./{{bin_dir}}/ubuntu-disk-toolkit help

# 명령어 목록
commands:
    @echo "📋 사용 가능한 명령어"
    @./{{bin_dir}}/ubuntu-disk-toolkit commands

# 시스템 정보 확인
info:
    @echo "💻 시스템 정보 확인 중..."
    @./{{bin_dir}}/ubuntu-disk-toolkit check-system info

# =============================================================================
# 💾 디스크 관리 (확장됨)
# =============================================================================

# 디스크 목록 확인
disks TYPE="table":
    @echo "💾 디스크 목록 확인 중..."
    @./{{bin_dir}}/ubuntu-disk-toolkit list-disks {{TYPE}}

# 디스크 상세 정보
disk-info ID:
    @echo "💾 디스크 정보 조회: {{ID}}"
    @./{{bin_dir}}/ubuntu-disk-toolkit disk-info {{ID}}

# 임시 마운트
mount-temp ID MOUNTPOINT FSTYPE="auto":
    @echo "💾 임시 마운트: {{ID}} → {{MOUNTPOINT}}"
    @./{{bin_dir}}/ubuntu-disk-toolkit mount-temp {{ID}} {{MOUNTPOINT}} {{FSTYPE}}

# 임시 언마운트
unmount-temp TARGET FORCE="":
    @echo "💾 임시 언마운트: {{TARGET}}"
    @./{{bin_dir}}/ubuntu-disk-toolkit unmount-temp {{TARGET}} {{FORCE}}

# =============================================================================
# ⚡ RAID 관리 (대폭 확장됨)
# =============================================================================

# RAID 상태 확인
raids FORMAT="detailed":
    @echo "⚡ RAID 상태 확인 중..."
    @./{{bin_dir}}/ubuntu-disk-toolkit list-raids {{FORMAT}}

# 새로운 RAID 생성
create-raid LEVEL MOUNTPOINT FSTYPE="ext4" *DISKS:
    @echo "⚡ RAID {{LEVEL}} 생성: {{MOUNTPOINT}}"
    @./{{bin_dir}}/ubuntu-disk-toolkit create-raid {{LEVEL}} {{MOUNTPOINT}} {{FSTYPE}} {{DISKS}}

# RAID 제거
remove-raid DEVICE WIPE="":
    @echo "⚡ RAID 제거: {{DEVICE}}"
    @./{{bin_dir}}/ubuntu-disk-toolkit remove-raid {{DEVICE}} {{WIPE}}

# RAID 상세 분석
analyze-raid DEVICE PERF="":
    @echo "⚡ RAID 분석: {{DEVICE}}"
    @./{{bin_dir}}/ubuntu-disk-toolkit analyze-raid {{DEVICE}} {{PERF}}

# 대화형 RAID 설정
setup-raid:
    @echo "⚡ 대화형 RAID 설정"
    @./{{bin_dir}}/ubuntu-disk-toolkit setup-raid

# RAID용 사용 가능한 디스크 확인
raid-disks:
    @echo "⚡ RAID용 사용 가능한 디스크"
    @./{{bin_dir}}/ubuntu-disk-toolkit list-disks raid-ready

# =============================================================================
# 📋 fstab 관리 (신규)
# =============================================================================

# fstab 항목 목록
fstab FORMAT="detailed":
    @echo "📋 fstab 항목 확인 중..."
    @./{{bin_dir}}/ubuntu-disk-toolkit list-fstab {{FORMAT}}

# fstab 항목 추가
add-fstab ID MOUNTPOINT FSTYPE="ext4" OPTIONS="defaults":
    @echo "📋 fstab 추가: {{ID}} → {{MOUNTPOINT}}"
    @./{{bin_dir}}/ubuntu-disk-toolkit add-fstab {{ID}} {{MOUNTPOINT}} {{FSTYPE}} {{OPTIONS}}

# fstab 항목 제거
remove-fstab IDENTIFIER:
    @echo "📋 fstab 제거: {{IDENTIFIER}}"
    @./{{bin_dir}}/ubuntu-disk-toolkit remove-fstab {{IDENTIFIER}}

# =============================================================================
# 🔍 시스템 관리 (신규)
# =============================================================================

# 전체 시스템 검사
check-system:
    @echo "🔍 전체 시스템 검사 중..."
    @./{{bin_dir}}/ubuntu-disk-toolkit check-system

# 시스템 자동 수정
fix-system:
    @echo "🔧 시스템 자동 수정 중..."
    @./{{bin_dir}}/ubuntu-disk-toolkit fix-system

# 종합 시스템 검사 (데모용)
demo:
    @echo "🎮 Ubuntu Disk Toolkit 데모"
    @echo "================================"
    @just help
    @echo ""
    @just info
    @echo ""
    @just disks

# 개발 가이드
dev-guide:
    @echo "🛠️ 개발 가이드"
    @echo ""
    @echo "=== 기본 명령어 ==="
    @echo "just setup          # 개발 환경 설정"
    @echo "just test            # 테스트 실행"
    @echo "just lint            # 코드 검사"
    @echo "just install         # 시스템 설치"
    @echo ""
    @echo "=== 디스크 관리 ==="
    @echo "just disks           # 디스크 목록"
    @echo "just disk-info <ID>  # 디스크 정보"
    @echo "just mount-temp <ID> <MOUNT>  # 임시 마운트"
    @echo ""
    @echo "=== RAID 관리 ==="
    @echo "just raids           # RAID 상태"
    @echo "just create-raid <LEVEL> <MOUNT> <DISK1> <DISK2>..."
    @echo "just setup-raid      # 대화형 RAID 설정"
    @echo "just raid-disks      # RAID용 디스크 확인"
    @echo ""
    @echo "=== fstab 관리 ==="
    @echo "just fstab           # fstab 목록"
    @echo "just add-fstab <ID> <MOUNT>  # fstab 추가"
    @echo ""
    @echo "=== 시스템 관리 ==="
    @echo "just check-system    # 전체 검사"
    @echo "just fix-system      # 자동 수정"

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

# 시스템 호환성 검사는 이미 위에 정의되어 있으므로 여기서는 제거 
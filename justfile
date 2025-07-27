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
setup:
    @echo "🚀 Ubuntu Disk Toolkit 개발 환경 설정 중..."
    @just install-deps
    @just permissions
    @echo "✅ 개발 환경 설정 완료!"

# 시스템 의존성 설치
install-deps:
    @echo "📦 시스템 의존성 설치 중..."
    @./{{install_dir}}/install-deps.sh

# 스크립트 실행 권한 설정
permissions:
    @echo "🔧 스크립트 실행 권한 설정 중..."
    @chmod +x {{bin_dir}}/*
    @chmod +x {{tests_dir}}/run-tests.sh
    @chmod +x {{install_dir}}/*.sh
    @echo "✅ 권한 설정 완료"

# =============================================================================
# 🧪 테스트 관련
# =============================================================================

# 모든 테스트 실행
test:
    @echo "🧪 전체 테스트 실행 중..."
    @cd {{tests_dir}} && ./run-tests.sh

# 상세 모드로 테스트 실행
test-verbose:
    @echo "🧪 상세 테스트 실행 중..."
    @cd {{tests_dir}} && ./run-tests.sh -v

# 병렬 테스트 실행
test-parallel:
    @echo "🧪 병렬 테스트 실행 중..."
    @cd {{tests_dir}} && ./run-tests.sh -p

# 특정 테스트 파일 실행
test-file TEST_FILE:
    @echo "🧪 테스트 파일 실행: {{TEST_FILE}}"
    @cd {{tests_dir}} && ./run-tests.sh {{TEST_FILE}}

# TAP 형식으로 테스트 결과 출력
test-tap:
    @echo "🧪 TAP 형식 테스트 실행..."
    @cd {{tests_dir}} && ./run-tests.sh --format tap

# 테스트 커버리지 (실험적)
test-coverage:
    @echo "🧪 테스트 커버리지 수집 중..."
    @cd {{tests_dir}} && ./run-tests.sh -c

# =============================================================================
# 🔍 코드 품질 검사
# =============================================================================

# shellcheck로 모든 스크립트 검사
lint:
    @echo "🔍 코드 품질 검사 중..."
    @echo "📝 bin/ 디렉토리 검사..."
    @find {{bin_dir}} -name "*.sh" -o -name "*" -type f -executable | xargs shellcheck || true
    @echo "📝 lib/ 디렉토리 검사..."
    @find {{lib_dir}} -name "*.sh" | xargs shellcheck || true
    @echo "📝 tests/ 디렉토리 검사..."
    @find {{tests_dir}} -name "*.sh" -o -name "*.bash" | xargs shellcheck || true
    @echo "✅ 코드 검사 완료"

# shellcheck 설치 확인
lint-install:
    @echo "🔧 shellcheck 설치 확인..."
    @which shellcheck > /dev/null || (echo "❌ shellcheck가 설치되지 않았습니다" && echo "설치: sudo apt install shellcheck" && exit 1)
    @echo "✅ shellcheck 설치됨"

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
# 🏗️ 빌드 및 설치
# =============================================================================

# 전체 설치 (개발 모드)
install-dev:
    @echo "🏗️ 개발 모드 설치 중..."
    @sudo ./{{install_dir}}/install.sh --dev
    @echo "✅ 개발 모드 설치 완료"

# 프로덕션 설치
install:
    @echo "🏗️ 프로덕션 설치 중..."
    @sudo ./{{install_dir}}/install.sh
    @echo "✅ 설치 완료"

# 설치 제거
uninstall:
    @echo "🗑️ Ubuntu Disk Toolkit 제거 중..."
    @sudo ./{{install_dir}}/uninstall.sh || echo "⚠️ 제거 스크립트가 없습니다"

# =============================================================================
# 📦 패키징 및 배포
# =============================================================================

# 배포용 아카이브 생성
package:
    @echo "📦 배포 패키지 생성 중..."
    @tar -czf {{project_name}}-$(date +%Y%m%d).tar.gz \
        --exclude='.git*' \
        --exclude='*.tar.gz' \
        --exclude='tmp' \
        .
    @echo "✅ 패키지 생성 완료: {{project_name}}-$(date +%Y%m%d).tar.gz"

# 릴리스 검증
verify-release:
    @echo "🔍 릴리스 검증 중..."
    @just lint
    @just test
    @just demo
    @echo "✅ 릴리스 검증 완료"

# =============================================================================
# 🧹 정리 및 유지보수
# =============================================================================

# 임시 파일 정리
clean:
    @echo "🧹 임시 파일 정리 중..."
    @find . -name "*~" -delete
    @find . -name "*.backup.*" -delete
    @find /tmp -name "ubuntu-disk-toolkit-test-*" -type d -exec rm -rf {} + 2>/dev/null || true
    @echo "✅ 정리 완료"

# 전체 정리 (캐시 포함)
clean-all: clean
    @echo "🧹 전체 정리 중..."
    @rm -f *.tar.gz
    @echo "✅ 전체 정리 완료"

# =============================================================================
# 📚 문서 및 정보
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

# 개발 가이드 표시
dev-guide:
    @echo "👨‍💻 개발 가이드"
    @echo "=============="
    @echo "1. just setup          # 개발 환경 설정"
    @echo "2. just test           # 테스트 실행"
    @echo "3. just lint           # 코드 검사"
    @echo "4. just demo           # 기능 테스트"
    @echo ""
    @echo "🔄 일반적인 개발 워크플로우:"
    @echo "   just test && just lint && just demo"

# =============================================================================
# 🚨 트러블슈팅
# =============================================================================

# 시스템 호환성 검사
check-system:
    @echo "🔍 시스템 호환성 검사 중..."
    @./{{bin_dir}}/ubuntu-disk-toolkit check-system requirements

# 권한 문제 해결
fix-permissions:
    @echo "🔧 권한 문제 해결 중..."
    @sudo chown -R $(whoami):$(whoami) .
    @just permissions
    @echo "✅ 권한 문제 해결 완료"

# 의존성 재설치
reinstall-deps:
    @echo "🔄 의존성 재설치 중..."
    @just install-deps
    @echo "✅ 의존성 재설치 완료" 
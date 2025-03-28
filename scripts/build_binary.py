# PURPOSE: Standalone 바이너리 빌드 스크립트
"""
Standalone 바이너리 빌드 스크립트
"""

import sys
import tempfile
import subprocess
from os import makedirs, pathsep, chdir, getcwd, chmod
from os.path import abspath, dirname, join, normpath, exists


def print_info(message):
    """정보 메시지 출력"""
    print(f"\033[92m[INFO]\033[0m {message}")


def print_error(message):
    """오류 메시지 출력"""
    print(f"\033[91m[ERROR]\033[0m {message}")


def run_command(cmd, cwd=None):
    """명령 실행"""
    print_info(f"실행 중: {' '.join(cmd)}")
    try:
        subprocess.run(cmd, check=True, cwd=cwd)
        return True
    except subprocess.CalledProcessError:
        print_error("명령 실행 실패")
        return False


def create_main_script(temp_dir):
    """임시 메인 스크립트 생성"""
    script_path = join(temp_dir, "main.py")
    with open(script_path, "w") as f:
        f.write("""#!/usr/bin/env python3
from ubuntu_raid_cli.main import cli

if __name__ == '__main__':
    cli()
""")
    return script_path


def create_install_script(dist_dir):
    """설치 스크립트 생성"""
    script_path = join(dist_dir, "install.sh")
    with open(script_path, "w") as f:
        f.write("""#!/bin/bash

# 색상 정의
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m' # No Color

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

# 필요한 패키지 설치
log_info "필요한 시스템 패키지를 설치합니다..."
apt-get update
apt-get install -y mdadm smartmontools

# 실행 파일 설치
log_info "Ubuntu RAID CLI를 설치합니다..."
cp raid-cli /usr/local/bin/
chmod +x /usr/local/bin/raid-cli

log_info "설치가 완료되었습니다!"
log_info "이제 'raid-cli' 명령어를 사용할 수 있습니다."
""")
    chmod(script_path, 0o755)  # 실행 권한 부여
    return script_path


def main():
    """메인 함수"""
    # 스크립트 위치 기반으로 프로젝트 루트 디렉토리 계산
    script_dir = dirname(abspath(__file__))
    project_root = normpath(join(script_dir, ".."))
    
    print_info(f"스크립트 디렉토리: {script_dir}")
    print_info(f"프로젝트 루트: {project_root}")
    
    if not exists(join(project_root, "pyproject.toml")):
        print_error("pyproject.toml 파일을 찾을 수 없습니다.")
        print_error("프로젝트 루트 디렉토리에서 실행해주세요.")
        sys.exit(1)

    # 빌드 디렉토리 생성
    build_dir = join(project_root, "build")
    dist_dir = join(project_root, "dist")
    release_dir = join(project_root, "release")

    for directory in [build_dir, dist_dir, release_dir]:
        makedirs(directory, exist_ok=True)

    # 소스 디렉토리 확인
    src_dir = join(project_root, "src", "ubuntu_raid_cli")
    if not exists(src_dir):
        print_error(f"소스 디렉토리를 찾을 수 없습니다: {src_dir}")
        sys.exit(1)

    # PyInstaller에 전달할 경로 설정
    package_name = "ubuntu_raid_cli"
    data_path = f"{src_dir}{pathsep}{package_name}"

    print_info(f"소스 경로: {src_dir}")
    print_info(f"데이터 경로: {data_path}")

    # 임시 디렉토리 생성
    with tempfile.TemporaryDirectory() as temp_dir:
        # 메인 스크립트 생성
        main_script = create_main_script(temp_dir)

        # PyInstaller로 바이너리 빌드
        print_info("PyInstaller로 바이너리를 빌드합니다...")
        pyinstaller_cmd = [
            "pyinstaller",
            "--onefile",
            "--name", "raid-cli",
            "--add-data", data_path,
            "--clean",
            "--workpath", build_dir,
            "--distpath", dist_dir,
            "--specpath", build_dir,
            main_script
        ]

        if not run_command(pyinstaller_cmd):
            print_error("바이너리 빌드에 실패했습니다.")
            sys.exit(1)

    # 설치 스크립트 생성
    install_script = create_install_script(dist_dir)

    # 아카이브 생성
    print_info("배포 패키지를 생성합니다...")
    archive_name = "ubuntu-raid-cli-standalone.tar.gz"
    archive_path = join(release_dir, archive_name)
    
    # 현재 디렉토리 저장
    current_dir = getcwd()
    
    try:
        # dist 디렉토리로 이동
        chdir(dist_dir)
        # 아카이브 생성
        subprocess.run(
            ["tar", "-czvf", archive_path, "raid-cli", "install.sh"],
            check=True
        )
    finally:
        # 원래 디렉토리로 복귀
        chdir(current_dir)

    print_info(f"배포 패키지가 생성되었습니다: {archive_path}")
    print_info("이 패키지를 대상 시스템으로 복사한 후 다음 명령으로 설치할 수 있습니다:")
    print_info("  tar -xzvf ubuntu-raid-cli-standalone.tar.gz && sudo ./install.sh")


if __name__ == "__main__":
    main() 
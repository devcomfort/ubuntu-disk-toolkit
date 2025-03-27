# PURPOSE: RAID 관련 유틸리티 함수들을 포함하는 모듈
"""
RAID 설정 및 관리에 필요한 유틸리티 함수들
"""

import subprocess
from typing import List, Dict
from rich.console import Console
from rich.table import Table

console = Console()

def run_command(command: List[str], check: bool = True) -> subprocess.CompletedProcess:
    """명령어를 실행하고 결과를 반환합니다."""
    try:
        result = subprocess.run(
            command,
            check=check,
            capture_output=True,
            text=True
        )
        return result
    except subprocess.CalledProcessError as e:
        console.print(f"[red]오류 발생: {e.stderr}[/red]")
        raise

def get_disk_list() -> List[Dict[str, str]]:
    """시스템에서 인식 가능한 디스크 목록을 반환합니다."""
    result = run_command(["lsblk", "-d", "-o", "NAME,SIZE,TYPE", "--json"])
    import json
    data = json.loads(result.stdout)
    return [disk for disk in data["blockdevices"] if disk["type"] == "disk"]

def get_raid_list() -> List[Dict[str, str]]:
    """현재 설정된 RAID 배열 목록을 반환합니다."""
    try:
        with open("/proc/mdstat", "r") as f:
            content = f.read()
        return parse_mdstat(content)
    except FileNotFoundError:
        return []

def parse_mdstat(content: str) -> List[Dict[str, str]]:
    """mdstat 파일 내용을 파싱하여 RAID 정보를 반환합니다."""
    raids = []
    current_raid = None
    
    for line in content.split("\n"):
        if line.startswith("md"):
            if current_raid:
                raids.append(current_raid)
            current_raid = {
                "name": line.split(":")[0].strip(),
                "level": "",
                "devices": [],
                "status": ""
            }
        elif current_raid and "raid" in line:
            parts = line.strip().split()
            current_raid["level"] = parts[0]
            current_raid["devices"] = [d.split("[")[0] for d in parts[1:]]
            current_raid["status"] = " ".join(parts)
    
    if current_raid:
        raids.append(current_raid)
    
    return raids

def format_disk_size(size_str: str) -> str:
    """디스크 크기를 보기 좋게 포맷팅합니다."""
    try:
        size = float(size_str)
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if size < 1024:
                return f"{size:.2f} {unit}"
            size /= 1024
        return f"{size:.2f} PB"
    except ValueError:
        return size_str

def display_disk_table(disks: List[Dict[str, str]]) -> None:
    """디스크 목록을 테이블 형태로 표시합니다."""
    table = Table(title="사용 가능한 디스크 목록")
    table.add_column("디스크", style="cyan")
    table.add_column("크기", style="green")
    table.add_column("타입", style="yellow")
    
    for disk in disks:
        table.add_row(
            f"/dev/{disk['name']}",
            format_disk_size(disk['size']),
            disk['type']
        )
    
    console.print(table)

def display_raid_table(raids: List[Dict[str, str]]) -> None:
    """RAID 목록을 테이블 형태로 표시합니다."""
    if not raids:
        console.print("[yellow]현재 설정된 RAID 배열이 없습니다.[/yellow]")
        return
    
    table = Table(title="RAID 배열 목록")
    table.add_column("RAID", style="cyan")
    table.add_column("레벨", style="green")
    table.add_column("디스크", style="yellow")
    table.add_column("상태", style="magenta")
    
    for raid in raids:
        table.add_row(
            f"/dev/{raid['name']}",
            raid['level'],
            ", ".join(raid['devices']),
            raid['status']
        )
    
    console.print(table) 
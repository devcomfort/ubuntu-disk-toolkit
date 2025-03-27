# PURPOSE: CLI 인터페이스를 구현하는 모듈
"""
Click을 사용하여 CLI 인터페이스를 구현하는 모듈
"""

import click
from rich.console import Console
from rich.prompt import Prompt
from .utils import get_disk_list, display_disk_table, get_raid_list, display_raid_table
from .raid_manager import RAIDManager
import subprocess

console = Console()

@click.group()
def cli():
    """Ubuntu RAID 설정을 위한 CLI 도구"""
    pass

@cli.command()
def list_disks():
    """사용 가능한 디스크 목록을 표시합니다."""
    disks = get_disk_list()
    display_disk_table(disks)

@cli.command()
def list_raids():
    """현재 설정된 RAID 배열 목록을 표시합니다."""
    raids = get_raid_list()
    display_raid_table(raids)

@cli.command()
@click.option('--level', type=click.Choice(['0', '1', '5', '6']), prompt='RAID 레벨 선택 (0,1,5,6)')
@click.option('--device', prompt='RAID 디바이스 이름 (예: /dev/md0)')
@click.option('--mount', prompt='마운트 포인트 (예: /mnt/raid)')
def setup_raid(level: str, device: str, mount: str):
    """새로운 RAID 배열을 설정합니다."""
    # 디스크 목록 표시
    disks = get_disk_list()
    display_disk_table(disks)
    
    # 디스크 선택
    console.print("\n[bold]RAID에 사용할 디스크를 선택하세요.[/bold]")
    console.print("디스크 이름을 공백으로 구분하여 입력하세요 (예: /dev/sda /dev/sdb)")
    selected_disks = Prompt.ask("선택한 디스크").split()
    
    # RAID 레벨에 따른 최소 디스크 수 확인
    min_disks = {
        '0': 2,
        '1': 2,
        '5': 3,
        '6': 4
    }
    
    if len(selected_disks) < min_disks[level]:
        console.print(f"[red]오류: RAID {level}은 최소 {min_disks[level]}개의 디스크가 필요합니다.[/red]")
        return
    
    # RAID 설정
    raid_manager = RAIDManager()
    if raid_manager.setup_raid(selected_disks, int(level), device, mount):
        console.print("[green]RAID 설정이 완료되었습니다![/green]")
    else:
        console.print("[red]RAID 설정에 실패했습니다.[/red]")

@cli.command()
@click.argument('device')
def remove_raid(device: str):
    """RAID 배열을 제거합니다."""
    if not click.confirm(f'정말로 {device} RAID 배열을 제거하시겠습니까?'):
        return
    
    raid_manager = RAIDManager()
    if raid_manager.remove_raid(device):
        console.print("[green]RAID 배열이 제거되었4니다![/green]")
    else:
        console.print("[red]RAID 배열 제거에 실패했습니다.[/red]")

@cli.command()
@click.argument('device')
@click.argument('new_mount_point')
def change_mount(device: str, new_mount_point: str):
    """RAID의 마운트 포인트를 변경합니다."""
    raid_manager = RAIDManager()
    if raid_manager.change_mount_point(device, new_mount_point):
        console.print("[green]마운트 포인트가 변경되었습니다![/green]")
    else:
        console.print("[red]마운트 포인트 변경에 실패했습니다.[/red]")

@cli.command()
def list_raid_groups():
    """RAID로 구성된 모든 그룹을 확인하는 함수"""
    try:
        # mdadm --detail --scan 명령을 실행하여 RAID 정보 가져오기
        result = subprocess.run(['mdadm', '--detail', '--scan'], 
                              capture_output=True, 
                              text=True)
        
        if result.returncode == 0:
            print("현재 구성된 RAID 그룹 목록:")
            print(result.stdout)
        else:
            print("RAID 그룹 정보를 가져오는데 실패했습니다.")
            
    except Exception as e:
        print(f"오류 발생: {str(e)}")

if __name__ == '__main__':
    cli() 
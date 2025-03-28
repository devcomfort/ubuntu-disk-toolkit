# PURPOSE: CLI 인터페이스를 구현하는 모듈
"""
Click을 사용하여 CLI 인터페이스를 구현하는 모듈
"""

import click
from rich.console import Console
from rich.prompt import Prompt, Confirm
from rich.table import Table
from .utils import get_disk_list, display_disk_table, get_raid_list, display_raid_table
from .raid_manager import RAIDManager
import subprocess
import json
from pathlib import Path
import psutil
import typer
import os
import tomli

console = Console()

# 무시할 경로 패턴과 그에 대한 사유
IGNORE_PATTERNS = {
    '/snap/': '스냅 패키지 관리 시스템에 의해 생성된 디스크',
    '/dev/loop': '가상 파일 시스템을 위한 루프 장치',
    '/dev/ram': '임시 저장을 위한 RAM 디스크',
    '/dev/dm-': '디바이스 매퍼에 의해 관리되는 가상 장치'
}

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
    
    # RAID 매니저 초기화
    raid_manager = RAIDManager()
    
    # 디스크 용량 확인
    try:
        disk_sizes = []
        ignored_disks = []  # 무시된 디스크 목록
        for disk in selected_disks:
            # 무시할 경로인지 확인
            for pattern, reason in IGNORE_PATTERNS.items():
                if pattern in disk:
                    ignored_disks.append((disk, reason))  # 무시된 디스크와 사유 추가
                    break
            else:
                result = subprocess.run(['blockdev', '--getsize64', disk], 
                                     capture_output=True, 
                                     text=True)
                disk_sizes.append(int(result.stdout.strip()))
        
        # 무시된 디스크 출력
        if ignored_disks:
            ignored_list = ', '.join([f"{disk} ({reason})" for disk, reason in ignored_disks])
            console.print(f"[yellow]무시된 디스크: {ignored_list}[/yellow]")
        
    except Exception as e:
        console.print(f"[red]디스크 용량 확인 중 오류 발생: {str(e)}[/red]")
        return
    
    # RAID 레벨 추천
    recommended_level = raid_manager.recommend_raid_level(len(selected_disks), disk_sizes)
    if int(level) != recommended_level:
        console.print(f"\n[yellow]권장 RAID 레벨: {recommended_level}[/yellow]")
        console.print(f"설명: {raid_manager.get_raid_level_description(recommended_level)}")
        if not Confirm.ask("권장 RAID 레벨을 사용하시겠습니까?"):
            console.print("[yellow]현재 선택한 RAID 레벨을 유지합니다.[/yellow]")
        else:
            level = str(recommended_level)
    
    # RAID 설정
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
        console.print("[green]RAID 배열이 제거되었습니다![/green]")
    else:
        console.print("[red]RAID 배열 제거에 실패했습니다.[/red]")

@cli.command()
def change_mount():
    """디스크 또는 RAID 디바이스의 마운트 위치를 변경합니다."""
    devices = get_all_disks()
    
    # 디바이스 선택 테이블 표시
    table = Table(title="사용 가능한 디바이스")
    table.add_column("번호", style="cyan")
    table.add_column("디바이스", style="green")
    table.add_column("유형", style="yellow")
    table.add_column("현재 마운트 위치", style="blue")
    
    for idx, dev in enumerate(devices, 1):
        table.add_row(
            str(idx),
            dev['device'],
            dev['type'],
            dev['mountpoint'] or "마운트되지 않음"
        )
    
    console.print(table)
    
    # 디바이스 선택
    choice = Prompt.ask(
        "변경할 디바이스 번호를 선택하세요",
        choices=[str(i) for i in range(1, len(devices) + 1)]
    )
    selected_device = devices[int(choice) - 1]
    
    # 현재 마운트 정보 표시
    if selected_device['mountpoint']:
        console.print(f"\n현재 마운트 위치: {selected_device['mountpoint']}")
        if not Confirm.ask("마운트 위치를 변경하시겠습니까?"):
            return
    
    # 새로운 마운트 위치 입력
    new_mount = Prompt.ask("새로운 마운트 위치를 입력하세요")
    
    try:
        # 마운트 위치 생성
        Path(new_mount).mkdir(parents=True, exist_ok=True)
        
        # 현재 마운트 해제 (if mounted)
        if selected_device['mountpoint']:
            subprocess.run(['sudo', 'umount', selected_device['device']], 
                         check=True)
        
        # 새 위치에 마운트
        subprocess.run(['sudo', 'mount', selected_device['device'], new_mount], 
                     check=True)
        
        # fstab 업데이트 여부 확인
        if Confirm.ask("변경된 마운트 위치를 영구적으로 저장하시겠습니까? (fstab에 추가)"):
            uuid = subprocess.run(
                ['sudo', 'blkid', '-s', 'UUID', '-o', 'value', selected_device['device']],
                capture_output=True,
                text=True
            ).stdout.strip()
            
            fstab_entry = f"UUID={uuid} {new_mount} auto defaults 0 0\n"
            
            with open('/etc/fstab', 'a') as f:
                f.write(fstab_entry)
            
            console.print("[green]fstab에 성공적으로 추가되었습니다.[/green]")
        
        console.print(f"[green]디바이스가 성공적으로 {new_mount}에 마운트되었습니다.[/green]")
        
    except subprocess.CalledProcessError as e:
        console.print(f"[red]마운트 변경 중 오류 발생: {str(e)}[/red]")
    except Exception as e:
        console.print(f"[red]오류 발생: {str(e)}[/red]")

def get_all_disks():
    """시스템의 모든 디스크와 RAID 디바이스 목록을 반환"""
    disks = []
    
    # 물리 디스크 확인
    for partition in psutil.disk_partitions():
        if '/dev/' in partition.device:
            # 무시할 경로인지 확인
            for pattern, reason in IGNORE_PATTERNS.items():
                if pattern in partition.device:
                    console.print(f"[yellow]무시된 디스크: {partition.device} ({reason})[/yellow]")  # 무시된 디스크 출력
                    break
            else:
                device = partition.device.split('p')[0] if 'p' in partition.device else partition.device
                if device not in disks:
                    disks.append({
                        'device': device,
                        'mountpoint': partition.mountpoint,
                        'type': 'disk'
                    })
    
    # RAID 디바이스 확인
    try:
        result = subprocess.run(['sudo', 'mdadm', '--detail', '--scan'], 
                              capture_output=True, 
                              text=True)
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if 'ARRAY' in line:
                    device = line.split()[1]
                    # 마운트 포인트 찾기
                    mountpoint = next(
                        (disk['mountpoint'] for disk in disks 
                         if disk['device'] == device),
                        None
                    )
                    disks.append({
                        'device': device,
                        'mountpoint': mountpoint,
                        'type': 'raid'
                    })
    except Exception as e:
        console.print(f"[red]RAID 정보 조회 중 오류 발생: {str(e)}[/red]")
    
    return disks

def check_smart_status(device_path):
    """디스크의 SMART 상태를 확인하는 함수"""
    try:
        # smartctl을 사용하여 SMART 정보 가져오기
        result = subprocess.run(
            ['sudo', 'smartctl', '-a', '-j', device_path],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            return {
                "status": "error",
                "message": f"SMART 데이터를 가져오는데 실패했습니다: {result.stderr}"
            }
            
        smart_data = json.loads(result.stdout)
        
        # 주요 상태 정보 추출
        health_status = smart_data.get('smart_status', {}).get('passed', False)
        temperature = smart_data.get('temperature', {}).get('current', 0)
        power_on_hours = next(
            (attr['raw']['value'] for attr in smart_data.get('ata_smart_attributes', {}).get('table', [])
            if attr['id'] == 9),
            0
        )
        
        # 불량 섹터 수 확인
        reallocated_sectors = next(
            (attr['raw']['value'] for attr in smart_data.get('ata_smart_attributes', {}).get('table', [])
            if attr['id'] == 5),
            0
        )
        
        return {
            "status": "healthy" if health_status else "unhealthy",
            "temperature": temperature,
            "power_on_hours": power_on_hours,
            "reallocated_sectors": reallocated_sectors,
            "details": smart_data
        }
        
    except Exception as e:
        return {
            "status": "error",
            "message": f"오류 발생: {str(e)}"
        }

@cli.command()
@click.option('--device', help='확인할 특정 디바이스 (기본: 모든 디바이스)')
def check(device):
    """디스크 또는 RAID 디바이스의 건강 상태를 확인합니다."""
    if device:
        # 특정 디바이스만 확인
        check_device_status(device)
    else:
        # 모든 디바이스 확인
        devices = get_all_disks()
        for dev in devices:
            console.print(f"\n[bold cyan]===== {dev['device']} 상태 확인 =====[/bold cyan]")
            if dev['mountpoint']:
                console.print(f"마운트 위치: {dev['mountpoint']}")
            check_device_status(dev['device'])

def check_device_status(device):
    """개별 디바이스 상태 확인"""
    device_path = Path(device)
    
    # snap 경로 무시
    if device.startswith('/snap/'):
        return
    
    if device_path.name.startswith('md'):
        check_raid_device(device)
    else:
        smart_status = check_smart_status(device)
        display_smart_status(device, smart_status)

def check_raid_device(device):
    """RAID 디바이스의 상태를 확인합니다."""
    try:
        # mdadm 상세 정보 가져오기
        result = subprocess.run(
            ['sudo', 'mdadm', '--detail', device],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            console.print(f"[red]RAID 정보를 가져오는데 실패했습니다: {result.stderr}[/red]")
            return
            
        # RAID 상태 정보 파싱
        raid_info = {}
        for line in result.stdout.splitlines():
            if ':' in line:
                key, value = line.split(':', 1)
                raid_info[key.strip()] = value.strip()
        
        # RAID 상태 테이블 표시
        table = Table(title=f"RAID {device} 상태 정보")
        table.add_column("항목", style="cyan")
        table.add_column("값", style="green")
        
        # 주요 정보 표시
        table.add_row("RAID 레벨", raid_info.get("Raid Level", "알 수 없음"))
        table.add_row("배열 크기", raid_info.get("Array Size", "알 수 없음"))
        table.add_row("사용된 디스크", raid_info.get("Used Dev Size", "알 수 없음"))
        table.add_row("상태", raid_info.get("State", "알 수 없음"))
        
        # 디스크 상태 정보 추출
        active_disks = int(raid_info.get("Active Devices", 0))
        failed_disks = int(raid_info.get("Failed Devices", 0))
        spare_disks = int(raid_info.get("Spare Devices", 0))
        
        table.add_row("활성 디스크", str(active_disks))
        table.add_row("실패 디스크", str(failed_disks))
        table.add_row("스페어 디스크", str(spare_disks))
        
        console.print(table)
        
        # RAID 레벨별 최소 디스크 수
        min_disks = {
            "raid0": 2,
            "raid1": 2,
            "raid5": 3,
            "raid6": 4
        }
        
        # RAID 레벨 확인
        raid_level = raid_info.get("Raid Level", "").lower()
        min_required = min_disks.get(raid_level, 2)  # 기본값 2
        
        # 경고 메시지 표시
        if failed_disks > 0:
            console.print("[red]경고: RAID 배열에 실패한 디스크가 있습니다![/red]")
        if active_disks < min_required:
            console.print(f"[red]경고: {raid_level.upper()} RAID 배열은 최소 {min_required}개의 활성 디스크가 필요합니다![/red]")
            
    except Exception as e:
        console.print(f"[red]RAID 상태 확인 중 오류 발생: {str(e)}[/red]")

def display_smart_status(device, status):
    """SMART 상태 정보를 표시하는 함수"""
    if status["status"] == "error":
        console.print(f"[red]{status['message']}[/red]")
        return
        
    table = Table(title=f"디스크 {device} 상태 정보")
    table.add_column("항목", style="cyan")
    table.add_column("값", style="green")
    
    status_color = "green" if status["status"] == "healthy" else "red"
    table.add_row("상태", f"[{status_color}]{status['status']}[/{status_color}]")
    table.add_row("온도", f"{status['temperature']}°C")
    table.add_row("사용 시간", f"{status['power_on_hours']} 시간")
    table.add_row("재할당된 섹터", str(status['reallocated_sectors']))
    
    console.print(table)

def get_all_storage_devices():
    """시스템의 모든 저장 장치 목록을 반환"""
    devices = []
    
    # 물리 디스크 확인
    for partition in psutil.disk_partitions():
        if '/dev/' in partition.device:
            device = partition.device.split('p')[0] if 'p' in partition.device else partition.device
            if device not in [d['device'] for d in devices]:
                devices.append({
                    'device': device,
                    'mountpoint': partition.mountpoint,
                    'type': 'disk',
                    'fstype': partition.fstype
                })
    
    # RAID 디바이스 확인
    try:
        result = subprocess.run(['sudo', 'mdadm', '--detail', '--scan'], 
                              capture_output=True, 
                              text=True)
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if 'ARRAY' in line:
                    device = line.split()[1]
                    mountpoint = next(
                        (disk['mountpoint'] for disk in devices 
                         if disk['device'] == device),
                        None
                    )
                    devices.append({
                        'device': device,
                        'mountpoint': mountpoint,
                        'type': 'raid',
                        'fstype': 'md'  # RAID 파일시스템 타입
                    })
    except Exception as e:
        console.print(f"[red]RAID 정보 조회 중 오류 발생: {str(e)}[/red]")
    
    return devices

def display_device_selection(devices, title="사용 가능한 장치"):
    """장치 선택을 위한 테이블 표시"""
    table = Table(title=title)
    table.add_column("번호", style="cyan")
    table.add_column("장치", style="green")
    table.add_column("유형", style="yellow")
    table.add_column("파일시스템", style="blue")
    table.add_column("마운트 위치", style="magenta")
    
    for idx, dev in enumerate(devices, 1):
        table.add_row(
            str(idx),
            dev['device'],
            dev['type'],
            dev['fstype'] or "미지정",
            dev['mountpoint'] or "마운트되지 않음"
        )
    
    console.print(table)
    return Prompt.ask(
        "작업할 장치 번호를 선택하세요",
        choices=[str(i) for i in range(1, len(devices) + 1)]
    )

@cli.command()
def format_device():
    """선택한 디스크 또는 RAID 디바이스를 포맷합니다."""
    devices = get_all_storage_devices()
    
    # 장치 선택
    choice = display_device_selection(devices, "포맷할 장치 선택")
    selected_device = devices[int(choice) - 1]
    
    # 경고 메시지
    console.print(f"\n[red]주의: {selected_device['device']}의 모든 데이터가 삭제됩니다![/red]")
    if not Confirm.ask("정말로 포맷하시겠습니까?"):
        return
    
    # 파일시스템 선택
    fs_types = ["ext4", "xfs", "btrfs"]
    fs_choice = Prompt.ask(
        "파일시스템 유형을 선택하세요",
        choices=fs_types,
        default="ext4"
    )
    
    try:
        # 마운트된 경우 언마운트
        if selected_device['mountpoint']:
            subprocess.run(['sudo', 'umount', selected_device['device']], 
                         check=True)
        
        # 포맷 명령 실행
        if selected_device['type'] == 'raid':
            # RAID 디바이스 포맷
            subprocess.run(['sudo', 'mkfs.' + fs_choice, selected_device['device']], 
                         check=True)
        else:
            # 일반 디스크 포맷
            subprocess.run(['sudo', 'mkfs.' + fs_choice, selected_device['device']], 
                         check=True)
        
        console.print(f"[green]장치가 성공적으로 {fs_choice}로 포맷되었습니다.[/green]")
        
    except subprocess.CalledProcessError as e:
        console.print(f"[red]포맷 중 오류 발생: {str(e)}[/red]")
    except Exception as e:
        console.print(f"[red]오류 발생: {str(e)}[/red]")

@cli.command()
def mount_device():
    """선택한 디스크 또는 RAID 디바이스를 마운트합니다."""
    devices = get_all_storage_devices()
    unmounted_devices = [d for d in devices if not d['mountpoint']]
    
    if not unmounted_devices:
        console.print("[yellow]마운트 가능한 장치가 없습니다.[/yellow]")
        return
    
    # 장치 선택
    choice = display_device_selection(unmounted_devices, "마운트할 장치 선택")
    selected_device = unmounted_devices[int(choice) - 1]
    
    # 마운트 위치 입력
    mount_point = Prompt.ask("마운트 위치를 입력하세요")
    
    try:
        # 마운트 위치 생성
        Path(mount_point).mkdir(parents=True, exist_ok=True)
        
        # 마운트 실행
        subprocess.run(['sudo', 'mount', selected_device['device'], mount_point], 
                     check=True)
        
        # fstab 업데이트 여부 확인
        if Confirm.ask("마운트 설정을 영구적으로 저장하시겠습니까? (fstab에 추가)"):
            uuid = subprocess.run(
                ['sudo', 'blkid', '-s', 'UUID', '-o', 'value', selected_device['device']],
                capture_output=True,
                text=True
            ).stdout.strip()
            
            fstab_entry = f"UUID={uuid} {mount_point} auto defaults 0 0\n"
            
            with open('/etc/fstab', 'a') as f:
                f.write(fstab_entry)
            
            console.print("[green]fstab에 성공적으로 추가되었습니다.[/green]")
        
        console.print(f"[green]장치가 성공적으로 {mount_point}에 마운트되었습니다.[/green]")
        
    except subprocess.CalledProcessError as e:
        console.print(f"[red]마운트 중 오류 발생: {str(e)}[/red]")
    except Exception as e:
        console.print(f"[red]오류 발생: {str(e)}[/red]")

@cli.command()
def unmount_device():
    """선택한 디스크 또는 RAID 디바이스를 언마운트합니다."""
    devices = get_all_storage_devices()
    mounted_devices = [d for d in devices if d['mountpoint']]
    
    if not mounted_devices:
        console.print("[yellow]언마운트 가능한 장치가 없습니다.[/yellow]")
        return
    
    # 장치 선택
    choice = display_device_selection(mounted_devices, "언마운트할 장치 선택")
    selected_device = mounted_devices[int(choice) - 1]
    
    try:
        # 언마운트 실행
        subprocess.run(['sudo', 'umount', selected_device['device']], 
                     check=True)
        
        console.print(f"[green]장치가 성공적으로 언마운트되었습니다.[/green]")
        
    except subprocess.CalledProcessError as e:
        console.print(f"[red]언마운트 중 오류 발생: {str(e)}[/red]")
    except Exception as e:
        console.print(f"[red]오류 발생: {str(e)}[/red]")

@cli.command()
def remount_device():
    """선택한 디스크 또는 RAID 디바이스를 재마운트합니다."""
    devices = get_all_storage_devices()
    mounted_devices = [d for d in devices if d['mountpoint']]
    
    if not mounted_devices:
        console.print("[yellow]재마운트 가능한 장치가 없습니다.[/yellow]")
        return
    
    # 장치 선택
    choice = display_device_selection(mounted_devices, "재마운트할 장치 선택")
    selected_device = mounted_devices[int(choice) - 1]
    
    try:
        # RAID 매니저 초기화
        raid_manager = RAIDManager()
        
        # 재마운트 실행
        if raid_manager.remount_device(selected_device['device']):
            console.print(f"[green]장치가 성공적으로 재마운트되었습니다.[/green]")
        else:
            console.print(f"[red]장치 재마운트에 실패했습니다.[/red]")
        
    except Exception as e:
        console.print(f"[red]오류 발생: {str(e)}[/red]")

@cli.command()
def update():
    """ubuntu-raid-cli를 최신 버전으로 업데이트합니다."""
    try:
        console.print("[yellow]ubuntu-raid-cli 업데이트를 시작합니다...[/yellow]")
        
        # 현재 설치된 버전 확인
        current_version = subprocess.run(
            ['pip', 'show', 'ubuntu-raid-cli'],
            capture_output=True,
            text=True
        ).stdout.strip()
        
        if not current_version:
            console.print("[red]ubuntu-raid-cli가 설치되어 있지 않습니다.[/red]")
            return
            
        # 현재 버전 출력
        for line in current_version.split('\n'):
            if line.startswith('Version:'):
                current_version = line.split(':')[1].strip()
                console.print(f"현재 버전: {current_version}")
                break
        
        # 최신 버전 설치
        console.print("\n최신 버전을 설치합니다...")
        result = subprocess.run(
            ['sudo', 'pip', 'install', '--upgrade', 'git+https://github.com/devcomfort/ubuntu-raid-cli.git'],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            console.print("[green]업데이트가 완료되었습니다![/green]")
            
            # 업데이트된 버전 확인
            new_version = subprocess.run(
                ['pip', 'show', 'ubuntu-raid-cli'],
                capture_output=True,
                text=True
            ).stdout.strip()
            
            for line in new_version.split('\n'):
                if line.startswith('Version:'):
                    new_version = line.split(':')[1].strip()
                    console.print(f"업데이트된 버전: {new_version}")
                    break
        else:
            console.print(f"[red]업데이트 중 오류가 발생했습니다: {result.stderr}[/red]")
            
    except Exception as e:
        console.print(f"[red]업데이트 중 오류 발생: {str(e)}[/red]")

@cli.command()
def version():
    """프로그램의 현재 버전을 표시합니다."""
    try:
        # pyproject.toml 파일 경로
        pyproject_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "pyproject.toml")
        
        # pyproject.toml 파일 읽기
        with open(pyproject_path, "rb") as f:
            pyproject_data = tomli.load(f)
        
        # 버전 정보 가져오기
        version = pyproject_data["project"]["version"]
        
        # 버전 정보 표시
        console.print(f"\n[bold blue]Ubuntu RAID CLI[/bold blue]")
        console.print(f"[bold]버전:[/bold] {version}")
        console.print(f"[bold]라이선스:[/bold] MIT")
        console.print(f"[bold]저자:[/bold] DevComfort")
        
    except Exception as e:
        console.print(f"[red]버전 정보를 가져오는 중 오류가 발생했습니다: {str(e)}[/red]")

if __name__ == '__main__':
    cli() 
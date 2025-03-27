# PURPOSE: RAID 설정 및 관리를 위한 주요 기능을 포함하는 모듈
"""
RAID 설정, 해제, 상태 확인 등의 주요 기능을 제공하는 모듈
"""

import os
import subprocess
from typing import List, Optional
from rich.console import Console
from rich.prompt import Confirm, Prompt
from .utils import run_command, get_disk_list, display_disk_table

console = Console()

class RAIDManager:
    def __init__(self):
        self.console = Console()
    
    def setup_raid(self, disks: List[str], level: int, device_name: str, mount_point: str) -> bool:
        """RAID 배열을 설정합니다."""
        try:
            # 디스크 선택 확인
            self.console.print("\n[red]경고: 선택한 디스크의 모든 데이터가 삭제됩니다![/red]")
            if not Confirm.ask("계속하시겠습니까?"):
                return False
            
            # 파티션 생성
            for disk in disks:
                self._create_partition(disk)
            
            # RAID 배열 생성
            self._create_raid_array(disks, level, device_name)
            
            # 파일 시스템 생성
            self._create_filesystem(device_name)
            
            # 마운트 포인트 생성 및 마운트
            self._mount_raid(device_name, mount_point)
            
            # fstab 설정
            self._update_fstab(device_name, mount_point)
            
            # 시스템 업데이트
            self._update_system()
            
            self.console.print("[green]RAID 설정이 완료되었습니다![/green]")
            return True
            
        except Exception as e:
            self.console.print(f"[red]RAID 설정 중 오류 발생: {str(e)}[/red]")
            return False
    
    def _create_partition(self, disk: str) -> None:
        """디스크에 파티션을 생성합니다."""
        # GPT 레이블 생성
        run_command(["parted", "-s", disk, "mklabel", "gpt"])
        
        # 파티션 생성
        run_command(["parted", "-s", disk, "mkpart", "primary", "0%", "100%"])
        
        # RAID 플래그 설정
        run_command(["parted", "-s", disk, "set", "1", "raid", "on"])
    
    def _create_raid_array(self, disks: List[str], level: int, device_name: str) -> None:
        """RAID 배열을 생성합니다."""
        partitions = [f"{disk}1" for disk in disks]
        cmd = [
            "mdadm", "--create", "--verbose",
            device_name,
            "--level", str(level),
            "--raid-devices", str(len(disks))
        ] + partitions
        
        run_command(cmd)
    
    def _create_filesystem(self, device_name: str) -> None:
        """RAID 배열에 파일 시스템을 생성합니다."""
        run_command(["mkfs.ext4", device_name])
    
    def _mount_raid(self, device_name: str, mount_point: str) -> None:
        """RAID를 마운트합니다."""
        os.makedirs(mount_point, exist_ok=True)
        run_command(["mount", device_name, mount_point])
    
    def _update_fstab(self, device_name: str, mount_point: str) -> None:
        """fstab에 RAID 마운트 설정을 추가합니다."""
        # UUID 가져오기
        result = run_command(["blkid", "-s", "UUID", "-o", "value", device_name])
        uuid = result.stdout.strip()
        
        # fstab에 추가
        fstab_entry = f"UUID={uuid} {mount_point} ext4 defaults 0 0\n"
        with open("/etc/fstab", "a") as f:
            f.write(fstab_entry)
    
    def _update_system(self) -> None:
        """시스템 설정을 업데이트합니다."""
        # mdadm.conf 업데이트
        run_command(["mdadm", "--detail", "--scan"], stdout=open("/etc/mdadm/mdadm.conf", "w"))
        
        # initramfs 업데이트
        run_command(["update-initramfs", "-u"])
    
    def remove_raid(self, device_name: str) -> bool:
        """RAID 배열을 제거합니다."""
        try:
            # RAID 배열 중지
            run_command(["mdadm", "--stop", device_name])
            
            # 슈퍼블록 제거
            for disk in self._get_raid_disks(device_name):
                run_command(["mdadm", "--zero-superblock", disk])
            
            # fstab에서 제거
            self._remove_from_fstab(device_name)
            
            self.console.print("[green]RAID 배열이 제거되었습니다![/green]")
            return True
            
        except Exception as e:
            self.console.print(f"[red]RAID 제거 중 오류 발생: {str(e)}[/red]")
            return False
    
    def _get_raid_disks(self, device_name: str) -> List[str]:
        """RAID 배열의 디스크 목록을 반환합니다."""
        result = run_command(["mdadm", "--detail", device_name])
        disks = []
        for line in result.stdout.split("\n"):
            if line.startswith("    "):
                parts = line.strip().split()
                if len(parts) >= 7 and parts[0].startswith("/dev/"):
                    disks.append(parts[0])
        return disks
    
    def _remove_from_fstab(self, device_name: str) -> None:
        """fstab에서 RAID 설정을 제거합니다."""
        result = run_command(["blkid", "-s", "UUID", "-o", "value", device_name])
        uuid = result.stdout.strip()
        
        with open("/etc/fstab", "r") as f:
            lines = f.readlines()
        
        with open("/etc/fstab", "w") as f:
            for line in lines:
                if uuid not in line:
                    f.write(line)
    
    def change_mount_point(self, device_name: str, new_mount_point: str) -> bool:
        """RAID의 마운트 포인트를 변경합니다."""
        try:
            # 현재 마운트 해제
            run_command(["umount", device_name])
            
            # 새 마운트 포인트 생성
            os.makedirs(new_mount_point, exist_ok=True)
            
            # 새 위치에 마운트
            run_command(["mount", device_name, new_mount_point])
            
            # fstab 업데이트
            self._update_fstab(device_name, new_mount_point)
            
            self.console.print("[green]마운트 포인트가 변경되었습니다![/green]")
            return True
            
        except Exception as e:
            self.console.print(f"[red]마운트 포인트 변경 중 오류 발생: {str(e)}[/red]")
            return False 
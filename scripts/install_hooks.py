import os
import stat
from pathlib import Path
from hatchling.builders.hooks.plugin.interface import BuildHookInterface

class CustomBuildHook(BuildHookInterface):
    def initialize(self, version, build_data):
        """설치 후 처리를 수행합니다."""
        # raid 실행 파일 경로
        raid_path = Path("/usr/local/bin/raid")
        
        if raid_path.exists():
            # 실행 권한 설정
            current_mode = os.stat(raid_path).st_mode
            os.chmod(raid_path, current_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
            
            print("Successfully set executable permissions for raid command")
        else:
            print("Warning: raid command not found in /usr/local/bin") 
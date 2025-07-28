# 테스트 신뢰성 분석 보고서

## 🔍 신뢰성 문제가 있는 테스트들

### 1. 과도한 모킹으로 인한 더미 테스트 (개선 필요)

#### 1.1 블록 디바이스 정보 조회 테스트
**문제**: `blkid`, `lsblk` 등의 명령어를 모킹하여 가짜 데이터로 테스트
**현재 상태**: 
```bash
# tests/test_helpers.bash - mock_blkid()
mock_blkid() {
    case "$device" in
        "/dev/sda"|"/dev/sda1")
            echo "UUID=\"12345678-1234-1234-1234-123456781234\" TYPE=\"ext4\""
            ;;
    esac
}
```

**개선 방안**: 실제 시스템의 블록 디바이스 정보 사용
```bash
# 개선된 접근법
@test "실제 블록 디바이스 정보 파싱" {
    # 실제 lsblk 출력 사용 (시스템에 최소 1개 디스크는 존재)
    run lsblk -J
    assert_command_success
    
    # JSON 파싱 로직 테스트
    local output="$output"
    run parse_lsblk_json "$output"
    assert_command_success
}
```

#### 1.2 fstab 파일 조작 테스트
**문제**: 실제 파일 조작 대신 모킹된 환경에서만 테스트
**현재 상태**: `TEST_FSTAB_FILE` 사용은 좋지만, 일부 함수는 모킹에 의존

**개선 방안**: 완전한 임시 파일 기반 테스트
```bash
@test "fstab 항목 추가 - 실제 파일 조작" {
    local temp_fstab="${TEST_TEMP_DIR}/test_fstab"
    cat > "$temp_fstab" << 'EOF'
UUID=existing-uuid / ext4 defaults 0 1
EOF
    
    # 실제 파일 조작 테스트
    FSTAB_FILE="$temp_fstab" run add_fstab_entry "UUID=new-uuid" "/data" "ext4" "defaults" "0" "2"
    assert_command_success
    
    # 결과 검증
    run grep "UUID=new-uuid" "$temp_fstab"
    assert_command_success
    assert_output_contains "/data"
}
```

### 2. 재현 불가능한 테스트 (모킹이 정당화됨)

#### 2.1 RAID 하드웨어 시뮬레이션
**정당한 모킹**: 실제 RAID 생성은 하드웨어 필요, 데이터 손실 위험
```bash
# 이런 경우는 모킹이 적절함
mock_mdadm() {
    case "$1" in
        "--create")
            echo "mdadm: array /dev/md0 started."
            ;;
        "--detail")
            echo "Version : 1.2"
            echo "Raid Level : raid1"
            ;;
    esac
}
```

#### 2.2 디스크 손상 시뮬레이션
**정당한 모킹**: SMART 오류, 디스크 실패 상황은 실제로 재현하기 어려움
```bash
# 이런 경우도 모킹이 적절함
mock_smartctl() {
    if [[ "$device" == "/dev/failing-disk" ]]; then
        echo "SMART Health Status: FAILING_NOW"
        return 1
    fi
}
```

## 🔧 개선 계획

### Phase 1: 임시 파일 기반 테스트로 전환
1. **fstab 관련 테스트**: 모든 fstab 테스트를 실제 임시 파일 기반으로 변경
2. **설정 파일 테스트**: config 파일 조작 테스트도 임시 파일 사용
3. **로그 파일 테스트**: 로그 생성/파싱 테스트를 실제 임시 파일로

### Phase 2: 실제 시스템 명령어 활용
1. **블록 디바이스 조회**: 실제 `lsblk`, `blkid` 출력을 파싱하는 테스트
2. **파일시스템 정보**: 실제 `/proc/mounts`, `/proc/filesystems` 읽기
3. **시스템 정보**: 실제 `uname`, `free` 등 시스템 명령어 사용

### Phase 3: 샌드박스 환경 구축
1. **네임스페이스 활용**: mount namespace를 이용한 격리된 마운트 테스트
2. **루프백 디바이스**: 실제 파일시스템 생성/마운트 테스트
3. **컨테이너 환경**: Docker/LXC를 이용한 완전 격리 테스트

## 📊 우선순위

### 🚨 즉시 개선 필요 (High Priority)
1. **fstab 파일 조작 테스트**: 100% 임시 파일 기반으로 전환
2. **설정 파일 파싱 테스트**: 실제 파일 읽기/쓰기로 전환
3. **blkid/lsblk 파싱 테스트**: 실제 명령어 출력 파싱으로 전환

### 🔄 점진적 개선 (Medium Priority)
1. **디스크 정보 조회 테스트**: 일부 모킹 제거, 실제 시스템 정보 활용
2. **마운트 상태 확인 테스트**: 실제 `/proc/mounts` 파싱
3. **시스템 호환성 테스트**: 실제 `/etc/os-release`, 커널 정보 사용

### 🎯 장기 목표 (Low Priority)
1. **RAID 테스트 샌드박스**: 루프백 디바이스를 이용한 실제 RAID 테스트
2. **마운트 테스트 네임스페이스**: 격리된 환경에서 실제 마운트 테스트
3. **성능 테스트**: 실제 I/O 성능 측정 테스트

## 🛠️ 구체적 개선 사항

### setup 명령어 의존성 검사 강화
현재 `install/install-deps.sh`가 존재하지만, 다음 개선 필요:

1. **누락된 패키지**:
   - `ruby`, `ruby-dev` (bashcov 의존성)
   - `curl`, `wget` (다운로드 도구)
   - `git` (버전 관리)

2. **설치 후 검증**:
```bash
# 설치 후 각 도구의 실제 작동 확인
verify_installation() {
    echo "설치 검증 중..."
    lsblk --version || exit 1
    mdadm --version || exit 1
    smartctl --version || exit 1
    # bashcov 검증
    bashcov --version || echo "⚠️ bashcov 설치 필요"
}
```

3. **테스트 환경 검증**:
```bash
# 테스트 실행 전 환경 검증
verify_test_environment() {
    [[ -w /tmp ]] || { echo "❌ /tmp 쓰기 권한 없음"; exit 1; }
    command -v bats || { echo "❌ bats 설치 필요"; exit 1; }
    [[ -d /proc ]] || { echo "❌ /proc 파일시스템 없음"; exit 1; }
}
``` 
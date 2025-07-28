# Ubuntu Disk Toolkit - Code Coverage Configuration
SimpleCov.start do
  # 프로젝트 이름 설정
  command_name 'Ubuntu Disk Toolkit Tests'
  
  # 커버리지 대상 디렉토리 지정
  add_filter '/tests/'        # 테스트 파일들은 커버리지에서 제외
  add_filter '/coverage/'     # 커버리지 결과 디렉토리 제외
  add_filter '/tmp/'          # 임시 파일들 제외
  
  # 라이브러리와 바이너리 파일들만 커버리지 대상으로 포함
  add_group 'Libraries', 'lib/'
  add_group 'Binaries', 'bin/'
  add_group 'Configuration', 'config/'
  
  # 커버리지 결과를 저장할 디렉토리
  coverage_dir 'coverage'
  
  # 최소 커버리지 임계값 설정 (80%)
  minimum_coverage 80
  
  # HTML 리포트 활성화
  formatter SimpleCov::Formatter::HTMLFormatter
  
  # 분석할 파일 패턴 지정
  track_files '{lib,bin,config}/**/*.{sh,bash}'
  
  # 프로젝트 루트 디렉토리 설정
  root Dir.pwd
end 
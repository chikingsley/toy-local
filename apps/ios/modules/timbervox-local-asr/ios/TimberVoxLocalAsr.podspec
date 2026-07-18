Pod::Spec.new do |s|
  s.name = 'TimberVoxLocalAsr'
  s.version = '1.0.0'
  s.summary = 'TimberVox on-device FluidAudio transcription'
  s.description = 'Downloads and runs the paired Parakeet batch and realtime models used by TimberVox.'
  s.author = 'Peacockery Studio'
  s.homepage = 'https://docs.expo.dev/modules/'
  s.platforms = { :ios => '18.0' }
  s.source = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'
  s.dependency 'FluidAudio'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.source_files = '**/*.{h,m,mm,swift,hpp,cpp}'
end

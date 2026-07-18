Pod::Spec.new do |s|
  s.name = 'TimberVoxSystem'
  s.version = '1.0.0'
  s.summary = 'TimberVox iOS system integrations'
  s.description = 'Native App Intents and system UI used by TimberVox.'
  s.author = 'Peacockery Studio'
  s.homepage = 'https://docs.expo.dev/modules/'
  s.platforms = { :ios => '18.0' }
  s.source = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.source_files = '**/*.{h,m,mm,swift,hpp,cpp}'
end

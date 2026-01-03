#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint screen_time_blocker.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'screen_time_blocker'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for blocking apps using iOS Screen Time API.'
  s.description      = <<-DESC
A Flutter plugin that provides access to Apple's Screen Time and Family Controls
frameworks, allowing apps to block other applications until certain conditions are met.
                       DESC
  s.homepage         = 'https://github.com/developerjamiu/screen_time_blocker'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Developer Jamiu' => 'your-email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.frameworks = 'FamilyControls', 'ManagedSettings', 'DeviceActivity'
end

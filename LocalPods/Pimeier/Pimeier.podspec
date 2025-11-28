Pod::Spec.new do |s|
  s.name             = 'Pimeier'
  s.version          = '0.1.0'
  s.summary          = 'A dynamic XML-based UI rendering engine powered by Yoga.'
  s.description      = <<-DESC
                       Pimeier is a lightweight framework for building iOS UIs using XML templates and JavaScript logic.
                       It supports hot reloading, native bridging, and Flexbox layout via Yoga.
                       DESC
  s.homepage         = 'https://github.com/yourname/Pimeier'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Your Name' => 'your.email@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }
  
  s.ios.deployment_target = '14.0'
  s.swift_version = '5.0'

  s.source_files = 'Classes/**/*'
  
  # Dependencies
  s.dependency 'YogaKit'
  
  # Frameworks
  s.frameworks = 'UIKit', 'Foundation', 'JavaScriptCore'

  # Auto-Start Dev Server Build Phase
  s.script_phase = {
    :name => 'Auto-Start Pimeier Server',
    :script => '${PODS_TARGET_SRCROOT}/../../scripts/auto_launch_server.sh',
    :execution_position => :before_compile
  }
end


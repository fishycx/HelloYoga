# Uncomment the next line to define a global platform for your project
platform :ios, '14.0'

target 'HelloYoga' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  
  # Disable warnings for pods
  inhibit_all_warnings!

  # Pods for HelloYoga
  # Using YogaKit from CocoaPods
  pod 'YogaKit'
  
  # Local Pod for Pimeier SDK
  pod 'Pimeier', :path => './LocalPods/Pimeier'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      
      # Fix for Yoga compilation error with newer Clang
      if target.name == 'Yoga' || target.name == 'YogaKit'
        config.build_settings['GCC_TREAT_WARNINGS_AS_ERRORS'] = 'NO'
        config.build_settings['WARNING_CFLAGS'] ||= ['$(inherited)']
        config.build_settings['WARNING_CFLAGS'] << '-Wno-bitwise-instead-of-logical'
        config.build_settings['OTHER_CFLAGS'] ||= ['$(inherited)']
        config.build_settings['OTHER_CFLAGS'] << '-Wno-bitwise-instead-of-logical'
        config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      end
    end
  end
end

Pod::Spec.new do |s|
  s.name             = 'kadr_diffusion'
  s.version          = '0.1.0'
  s.summary          = 'Kadr AI on-device painter (stable-diffusion.cpp).'
  s.homepage         = 'https://github.com/leejet/stable-diffusion.cpp'
  s.license          = { :type => 'MIT' }
  s.author           = { 'HOOKKADR' => 'dev@hookkadr.local' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '16.0'
  s.dependency 'Flutter'
  # Built by tool/build_ios.sh from the pinned stable-diffusion.cpp and src/kadr_sd.cpp.
  s.vendored_frameworks = 'Frameworks/KadrSd.xcframework'
  s.frameworks = 'Foundation', 'Accelerate', 'Metal', 'MetalKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end

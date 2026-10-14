Pod::Spec.new do |s|
  s.name             = 'kadr_llm'
  s.version          = '0.1.0'
  s.summary          = 'Kadr AI on-device language model runtime (llama.cpp).'
  s.homepage         = 'https://github.com/ggml-org/llama.cpp'
  s.license          = { :type => 'MIT' }
  s.author           = { 'HOOKKADR' => 'dev@hookkadr.local' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '16.0'
  s.dependency 'Flutter'
  # Built by tool/build_ios.sh from the pinned llama.cpp and src/kadr_llm.cpp.
  s.vendored_frameworks = 'Frameworks/KadrLlm.xcframework'
  s.frameworks = 'Foundation', 'Accelerate', 'Metal', 'MetalKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end

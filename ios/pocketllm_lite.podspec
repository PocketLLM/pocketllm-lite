Pod::Spec.new do |s|
  s.name             = 'pocketllm_lite'
  s.version          = '1.0.22'
  s.summary          = 'Local llama.cpp inference engine with Metal acceleration for PocketLLM Lite.'
  s.description      = <<-DESC
A lightweight plugin enabling local GGUF model execution inside PocketLLM Lite.
Accelerated using iOS Metal Shading Language (MSL) for high performance offline inference.
                       DESC
  s.homepage         = 'https://github.com/PocketLLM/pocketllm-lite'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'PocketLLM Team' => 'support@pocketllm.com' }
  s.source           = { :path => '.' }
  
  s.source_files = 'Classes/**/*', 'llama.cpp/*.{h,c,cpp}', 'llama.cpp/common/*.{h,cpp}'
  s.public_header_files = 'Classes/**/*.h', 'llama.cpp/*.h'
  
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/llama.cpp $(PODS_TARGET_SRCROOT)/llama.cpp/common',
    # Enable Metal acceleration, loop vectorization and aggressive speed optimization
    'OTHER_CFLAGS' => '$(inherited) -O3 -flto -DGGML_USE_METAL -DGGML_METAL_NDEBUG',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -O3 -flto -std=c++17 -DGGML_USE_METAL -DGGML_METAL_NDEBUG'
  }
  
  # Metal Shaders compiler resources bundle (contains default llama.cpp ggml-metal.metal shader file)
  s.resource_bundles = {
    'pocketllm_lite_privacy' => ['Resources/PrivacyInfo.xcprivacy'],
    'pocketllm_lite_shaders' => ['llama.cpp/*.metal']
  }
  
  s.frameworks = 'Foundation', 'Metal', 'MetalKit', 'Accelerate'
  s.swift_version = '5.0'
end

Pod::Spec.new do |s|
  s.name             = 'RustCore'
  s.version          = '0.0.1'
  s.summary          = 'The Rust Brain of SatyaSetu.'
  s.homepage         = 'http://example.com'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Satya' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'src/**/*.{rs}' # Dummy to satisfy podspec
  s.vendored_libraries = 'target/universal/release/librust_core.a'
  s.platform         = :ios, '13.0'
  # This enables the "force load" logic automatically
  s.pod_target_xcconfig = { 'OTHER_LDFLAGS' => '-force_load "$(PODS_TARGET_SRCROOT)/target/universal/release/librust_core.a"' }
end

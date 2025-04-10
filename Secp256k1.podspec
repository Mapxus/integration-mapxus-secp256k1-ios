Pod::Spec.new do |s|
  version = '1.0.0'

  s.name             = 'Secp256k1'
  s.version          = version
  s.summary          = 'A library for working with secp256k1 elliptic curve cryptography'
  s.description      = 'libsecp256k1 is a library for working with secp256k1 elliptic curve cryptography. This pod provides the XCFramework version of the library.'
  s.homepage         = 'https://github.com/bitcoin-core/secp256k1'
  s.license          = { :type => 'BSD 3-Clause', :file => 'LICENSE' }
  s.author           = { 'Mapxus' => 'developer@maphive.io' }

  s.platform         = :ios, '9.0'

  s.source           = { :http => "https://nexus3.mapxus.com/repository/mapxus-secp256k1-ios/#{version.to_s}/mapxus-secp256k1-ios.zip", :flatten => true }

  s.requires_arc = true
  s.module_name  = 'Secp256k1'
  s.vendored_frameworks = 'dynamic/Secp256k1.xcframework'
end 
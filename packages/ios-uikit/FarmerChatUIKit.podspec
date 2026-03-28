Pod::Spec.new do |s|
  s.name         = "FarmerChatUIKit"
  s.version      = "0.0.0"
  s.summary      = "FarmerChat UIKit SDK - AI-powered agricultural advisory chat"
  s.homepage     = "https://github.com/digitalgreen/farmerchat-sdk"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Digital Green" => "sdk@digitalgreen.org" }
  s.source       = { :git => "https://github.com/digitalgreen/farmerchat-sdk.git", :tag => s.version.to_s }
  s.platform     = :ios, "15.0"
  s.swift_version = "5.9"
  s.source_files = "Sources/FarmerChatUIKit/**/*.swift"
end

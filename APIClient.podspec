Pod::Spec.new do |spec|
  spec.name = "APIClient"
  spec.version = "1.0.0"
  spec.summary = "A light weight http client and endpoint abstraction library."
  spec.homepage = "https://github.com/DanielCardonaRojas/APIClient"
  spec.license = { type: 'MIT', file: 'LICENSE' }
  spec.authors = { "Your Name" => 'd.cardona.rojas@gmail.com' }
  spec.platform = :ios, "9.1"
  spec.requires_arc = true
  spec.source = { git: "https://github.com/DanielCardonaRojas/APIClient.git", tag: "v#{spec.version}", submodules: true }
  spec.source_files = "APIClient/**/*.{h,swift}"
end

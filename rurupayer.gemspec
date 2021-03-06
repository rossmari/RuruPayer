# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rurupayer/version'

Gem::Specification.new do |spec|
  spec.name          = "rurupayer"
  spec.version       = Rurupayer::VERSION
  spec.authors       = ["Rossmari"]
  spec.email         = ["roman-bujenko@yandex.ru"]
  spec.description   = %q{Gem for electronic payments through RuRu pay service}
  spec.summary       = %q{Summary}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end

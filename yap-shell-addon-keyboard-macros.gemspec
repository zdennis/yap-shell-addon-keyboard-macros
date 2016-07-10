require File.dirname(__FILE__) + '/lib/yap-shell-addon-keyboard-macros/version'

Gem::Specification.new do |spec|
  spec.name    = 'yap-shell-addon-keyboard-macros'
  spec.version = YapShellAddonKeyboardMacros::VERSION
  spec.authors = ['Zach Dennis']
  spec.email   = 'zach.dennis@gmail.com'
  spec.date    = Date.today.to_s

  spec.summary = 'Keyboard macro library for yap-shell'
  spec.description = 'An amazing keyboard macro library for yap-shell'
  spec.homepage = 'http://github.com/zdennis/yap-shell-keyboard-macros-addon'
  spec.license = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(/^(test|spec|features)\//) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(/^exe\//) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "yap-shell-core", "~> 0.7.2"
  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 11.2"
  spec.add_development_dependency "rspec", "~> 3.4"
end

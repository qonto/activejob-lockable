# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activejob/lockable/version'

Gem::Specification.new do |spec|
  spec.name          = 'activejob-lockable'
  spec.version       = ActiveJob::Lockable::VERSION
  spec.authors       = ['Dmytro Zakharov']
  spec.email         = ['dmytro@qonto.eu']

  spec.summary       = %q{Prevents jobs from enqueuing with unique arguments for a certain period of time}
  spec.homepage      = 'https://github.com/qonto/activejob-lockable'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activejob'
  spec.add_dependency 'activesupport'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'fakeredis'
  spec.add_development_dependency 'pry'
end

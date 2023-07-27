# encoding: utf-8
$:.push File.expand_path("../lib", __FILE__)
require "audited/version"

Gem::Specification.new do |gem|
  gem.name        = 'audited'
  gem.version     = Audited::VERSION
  gem.platform    = Gem::Platform::RUBY

  gem.authors     = ['Brandon Keepers', 'Kenneth Kalmer', 'Daniel Morrison', 'Brian Ryckbost', 'Steve Richert', 'Ryan Glover']
  gem.email       = 'info@collectiveidea.com'
  gem.description = 'Log all changes to your models'
  gem.summary     = gem.description
  gem.homepage    = 'https://github.com/collectiveidea/audited'
  gem.license     = 'MIT'

  gem.files         = `git ls-files`.split($\).reject{|f| f =~ /(\.gemspec|lib\/audited\-|adapters|generators)/ }
  gem.test_files    = gem.files.grep(/^spec\//)
  gem.require_paths = ['lib']

  gem.add_dependency 'rails-observers', '~> 0.1.2'

  gem.add_development_dependency 'appraisal', '~> 1.0.0'
  gem.add_development_dependency 'mongo_mapper', '~> 0.15.0'
  gem.add_development_dependency 'rails', '~> 5.2.0'
  gem.add_development_dependency 'rspec-rails', '~> 4.0'

  # https://github.com/rails/sprockets-rails/issues/444#issuecomment-637817050
  gem.add_development_dependency 'sprockets', "<4"
end


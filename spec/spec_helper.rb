ENV['RAILS_ENV'] = 'test'

require 'bundler'
if Bundler.definition.dependencies.map(&:name).include?('protected_attributes')
  require 'protected_attributes'
end

require 'rails_app/config/environment'
require 'rspec/rails'
require 'audited'
require 'audited_spec_helpers'

SPEC_ROOT = Pathname.new(File.expand_path('../', __FILE__))

Dir[SPEC_ROOT.join('support/*.rb')].each{|f| require f }

RSpec.configure do |config|
  config.include AuditedSpecHelpers

  config.use_transactional_fixtures = false if Rails.version.start_with?('4.')
  config.use_transactional_tests = false if config.respond_to?(:use_transactional_tests=)

  config.before(:each, :adapter => :active_record) do
    Audited.audit_class = Audited::Adapters::ActiveRecord::Audit
  end

  config.before(:each, :adapter => :mongo_mapper) do
    Audited.audit_class = Audited::Adapters::MongoMapper::Audit
  end

  config.filter_run_when_matching :focus
end

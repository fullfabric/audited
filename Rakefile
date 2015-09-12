#!/usr/bin/env rake

require 'bundler/gem_helper'
require 'rspec/core/rake_task'
require 'rake/testtask'
require 'appraisal'

Bundler::GemHelper.install_tasks(name: 'audited')
Bundler::GemHelper.install_tasks(name: 'audited-activerecord')
Bundler::GemHelper.install_tasks(name: 'audited-mongo_mapper')

ADAPTERS = %w(active_record mongo_mapper)

ADAPTERS.each do |adapter|
  desc "Run RSpec code examples for #{adapter} adapter"
  RSpec::Core::RakeTask.new(adapter) do |t|
    t.pattern = "spec/audited/adapters/#{adapter}/**/*_spec.rb"
  end
end

task :spec do
  ADAPTERS.each do |adapter|
    Rake::Task[adapter].invoke
  end
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

task default: [:spec, :test]

namespace :db do
  desc "setup the test database"
  task :setup do
    ENV['RAILS_ENV'] = 'test'
    require File.expand_path("../spec/rails_app/config/environment", __FILE__)
    require File.expand_path("../spec/support/active_record/schema", __FILE__)
  end
end
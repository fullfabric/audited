require 'active_record'
require 'audited/auditor'
require 'audited/adapters/active_record/audit'

module Audited::Auditor::AuditedClassMethods
  protected

  def class_prefix
    table_name
  end
end

ActiveSupport.on_load :active_record do
  require "audited/audit"
  include Audited::Auditor
end

Audited.audit_class = Audited::Adapters::ActiveRecord::Audit

require 'audited/sweeper'

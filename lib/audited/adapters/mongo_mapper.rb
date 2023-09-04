require 'mongo_mapper'
require 'audited/auditor'
require 'audited/adapters/mongo_mapper/audited_changes'
require 'audited/adapters/mongo_mapper/audit'

module Audited::Auditor::ClassMethods
  def table_name
    name.tableize
  end
end

module Audited::Auditor::AuditedClassMethods
  def default_ignored_attributes
    ['id', '_id', 'created_on', 'created_at', 'updated_at', 'updated_on', 'lock_version'] + Audited.ignored_attributes
  end

  protected

  def class_prefix
    collection_name
  end
end

::MongoMapper::Document.plugin Audited::Auditor

Audited.audit_class = Audited::Adapters::MongoMapper::Audit

require 'audited/sweeper'

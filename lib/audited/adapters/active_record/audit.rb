require 'set'
require 'audited/audit'

module Audited
  class YAMLIfTextColumnType
    class << self
      def load(obj)
        if Audited.audit_class.columns_hash["audited_changes"].type.to_s == "text"
          ::ActiveRecord::Coders::YAMLColumn.new(Object).load(obj)
        else
          obj
        end
      end

      def dump(obj)
        if Audited.audit_class.columns_hash["audited_changes"].type.to_s == "text"
          ::ActiveRecord::Coders::YAMLColumn.new(Object).dump(obj)
        else
          obj
        end
      end
    end
  end

  module Adapters
    module ActiveRecord
      # Audit saves the changes to ActiveRecord models.  It has the following attributes:
      #
      # * <tt>auditable</tt>: the ActiveRecord model that was changed
      # * <tt>user</tt>: the user that performed the change; a string or an ActiveRecord model
      # * <tt>action</tt>: one of create, update, or delete
      # * <tt>audited_changes</tt>: a hash of all the changes
      # * <tt>comment</tt>: a comment set with the audit
      # * <tt>version</tt>: the version of the model
      # * <tt>request_uuid</tt>: a uuid based that allows audits from the same controller request
      # * <tt>created_at</tt>: Time that the change was performed
      #
      class Audit < ::ActiveRecord::Base
        include Audited::Audit

        serialize :audited_changes, YAMLIfTextColumnType

        scope :ascending,     ->{ reorder(version: :asc) }
        scope :descending,    ->{ reorder(version: :desc)}
        scope :creates,       ->{ where(action: 'create')}
        scope :updates,       ->{ where(action: 'update')}
        scope :destroys,      ->{ where(action: 'destroy')}

        scope :up_until,      ->(date_or_time){ where("created_at <= ?", date_or_time) }
        scope :from_version,  ->(version){ where('version >= ?', version) }
        scope :to_version,    ->(version){ where('version <= ?', version) }
        scope :auditable_finder, ->(auditable_id, auditable_type){ where(auditable_id: auditable_id, auditable_type: auditable_type) }
        # Return all audits older than the current one.
        def ancestors
          self.class.ascending.auditable_finder(auditable_id, auditable_type).to_version(version)
        end

        # Allows user to be set to either a string or an ActiveRecord object
        # @private
        def user_as_string=(user)
          # reset both either way
          self.user_as_model = self.username = nil
          user.is_a?(::ActiveRecord::Base) ?
            self.user_as_model = user :
            self.username = user
        end
        alias_method :user_as_model=, :user=
        alias_method :user=, :user_as_string=

        # @private
        def user_as_string
          user_as_model || username
        end
        alias_method :user_as_model, :user
        alias_method :user, :user_as_string

      private
        def set_version_number
          max = self.class.auditable_finder(auditable_id, auditable_type).maximum(:version) || 0
          self.version = max + 1
        end
      end
    end
  end
end

module Audited
  module Audit
    def self.included(klass)
      klass.extend(ClassMethods)
      klass.setup_audit
    end

    module ClassMethods
      def setup_audit
        belongs_to :auditable,  polymorphic: true
        belongs_to :user,       polymorphic: true
        belongs_to :associated, polymorphic: true

        before_create :set_version_number, :set_audit_user, :set_request_uuid, :set_remote_address

        cattr_accessor :audited_class_names
        self.audited_class_names = Set.new
      end

      # Returns the list of classes that are being audited
      def audited_classes
        audited_class_names.map(&:constantize)
      end

      # All audits made during the block called will be recorded as made
      # by +user+. This method is hopefully threadsafe, making it ideal
      # for background operations that require audit information.
      def as_user(user, &block)
        ::Audited.store[:audited_user] = user
        yield
      ensure
        ::Audited.store[:audited_user] = nil
      end

      # @private
      def reconstruct_attributes(audits)
        attributes = {}
        result = audits.collect do |audit|
          attributes.merge!(audit.new_attributes)[:version] = audit.version
          yield attributes if block_given?
        end
        block_given? ? result : attributes
      end

      # @private
      def assign_revision_attributes(record, attributes)
        attributes.each do |attr, val|
          record = record.dup if record.frozen?

          if record.respond_to?("#{attr}=")
            record.attributes.key?(attr.to_s) ?
              record[attr] = val :
              record.send("#{attr}=", val)
          end
        end
        record
      end

      # use created_at as timestamp cache key
      def collection_cache_key(collection = all, timestamp_column = :created_at)
        super(collection, :created_at)
      end
    end

    # Return an instance of what the object looked like at this revision. If
    # the object has been destroyed, this will be a new record.
    def revision
      clazz = auditable_type.constantize
      (clazz.find_by_id(auditable_id) || clazz.new).tap do |m|
        self.class.assign_revision_attributes(m, self.class.reconstruct_attributes(ancestors).merge(version: version))
      end
    end

    # Returns a hash of the changed attributes with the new values
    def new_attributes
      (audited_changes || {}).inject({}.with_indifferent_access) do |attrs, (attr, values)|
        attrs[attr] = values.is_a?(Array) ? values.last : values
        attrs
      end
    end

    # Returns a hash of the changed attributes with the old values
    def old_attributes
      (audited_changes || {}).inject({}.with_indifferent_access) do |attrs, (attr, values)|
        attrs[attr] = Array(values).first
        attrs
      end
    end

    # Allows user to undo changes
    def undo
      model = self.auditable_type.constantize
      if action == 'create'
        # destroys a newly created record
        record = model.find(auditable_id)

        if record.respond_to?(:destroy!)
          # ActiveRecord
          record.destroy!
        else
          # MongoMapper
          record.destroy
        end
      elsif action == 'destroy'
        # creates a new record with the destroyed record attributes
        model.create(audited_changes)
      else
        # changes back attributes
        audited_object = model.find(auditable_id)
        self.audited_changes.each do |k, v|
          audited_object[k] = v[0]
        end
        audited_object.save
      end
    end

    private

    def set_version_number
      max = self.class.auditable_finder(auditable_id, auditable_type).descending.first.try(:version) || 0
      self.version = max + 1
    end

    def set_audit_user
      self.user ||= ::Audited.store[:audited_user] # from .as_user
      self.user ||= ::Audited.store[:current_user].try!(:call) # from Sweeper
      nil # prevent stopping callback chains
    end

    def set_request_uuid
      self.request_uuid ||= ::Audited.store[:current_request_uuid]
      self.request_uuid ||= SecureRandom.uuid
    end

    def set_remote_address
      self.remote_address ||= ::Audited.store[:current_remote_address]
    end
  end
end

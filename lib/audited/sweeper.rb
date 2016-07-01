require "rails/observers/activerecord/active_record"
require "rails/observers/action_controller/caching"

module Audited
  class Sweeper < ActionController::Caching::Sweeper
    observe Audited.audit_class

    def around(controller)
      self.controller = controller
      yield
    ensure
      self.controller = nil
    end

    def before_create(audit)
      audit.user ||= current_user
      audit.remote_address = controller.try(:request).try(:remote_ip)
      audit.request_uuid = request_uuid if request_uuid
    end

    def current_user
      controller.send(Audited.current_user_method) if controller.respond_to?(Audited.current_user_method, true)
    end

    def request_uuid
      controller.try(:request).try(:uuid)
    end

    def add_observer!(klass)
      if defined?(::ActiveRecord)
        super
        define_callback(klass)
      end
    end

    def define_callback(klass)
      observer = self
      callback_meth = :_notify_audited_sweeper
      klass.send(:define_method, callback_meth) do
        observer.update(:before_create, self)
      end
      klass.send(:before_create, callback_meth)
    end

    def controller
      ::Audited.store[:current_controller]
    end

    def controller=(value)
      ::Audited.store[:current_controller] = value
    end
  end
end

ActiveSupport.on_load(:action_controller) do
  # Create dynamic subclass of Audited::Sweeper otherwise rspec will
  # fail with both ActiveRecord and MongoMapper tests as there will be
  # around_filter collision
  sweeper_class = Class.new(Audited::Sweeper) do
    def self.name
      "#{Audited.audit_class}::Sweeper"
    end
  end

  if defined?(ActionController::Base)
    ActionController::Base.around_action sweeper_class.instance
  end

  if defined?(ActionController::API)
    ActionController::API.around_action sweeper_class.instance
  end
end

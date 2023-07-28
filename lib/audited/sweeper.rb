module Audited
  class Sweeper
    STORED_DATA = {
      current_remote_address: :remote_ip,
      current_request_uuid: :request_uuid,
      current_user: :current_user
    }

    delegate :store, to: ::Audited

    def around(controller)
      self.controller = controller
      STORED_DATA.each { |k,m| store[k] = send(m) }
      yield
    ensure
      self.controller = nil
      STORED_DATA.keys.each { |k| store.delete(k) }
    end

    def current_user
      controller.send(Audited.current_user_method) if controller.respond_to?(Audited.current_user_method, true)
    end

    def remote_ip
      controller.try(:request).try(:remote_ip)
    end

    def request_uuid
      controller.try(:request).try(:uuid)
    end

    def controller
      store[:current_controller]
    end

    def controller=(value)
      store[:current_controller] = value
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
    ActionController::Base.around_action sweeper_class.new
  end

  if defined?(ActionController::API)
    ActionController::API.around_action sweeper_class.new
  end
end

require File.expand_path('../mongo_mapper_spec_helper', __FILE__)

class MongoAuditsController < ActionController::Base
  attr_reader :company

  def create
    @company = Models::MongoMapper::Company.create
    head :ok
  end

  def update
    current_user.update_attributes(password: 'foo')
    head :ok
  end

  private

  attr_accessor :current_user
  attr_accessor :custom_user
end

describe MongoAuditsController, :adapter => :mongo_mapper do
  include RSpec::Rails::ControllerExampleGroup

  before(:each) do
    Audited.current_user_method = :current_user
  end

  let( :user ) { create_mongo_user }

  describe "POST audit" do

    it "should audit user" do
      controller.send(:current_user=, user)

      expect {
        post :create
      }.to change(Audited.audit_class, :count)

      expect(controller.company.audits.last.user).to eq(user)
    end

    it "should support custom users for sweepers" do
      controller.send(:custom_user=, user)
      Audited.current_user_method = :custom_user

      expect {
        post :create
      }.to change(Audited.audit_class, :count)

      expect(controller.company.audits.last.user).to eq(user)
    end

    it "should record the remote address responsible for the change" do
      request.env['REMOTE_ADDR'] = "1.2.3.4"
      controller.send(:current_user=, user)

      post :create

      expect(controller.company.audits.last.remote_address).to eq('1.2.3.4')
    end

    it "should record a UUID for the web request responsible for the change" do
      allow_any_instance_of(ActionDispatch::Request).to receive(:uuid).and_return("abc123")
      controller.send(:current_user=, user)

      post :create

      expect(controller.company.audits.last.request_uuid).to eq("abc123")
    end

  end

  describe "PUT update" do
    it "should not save blank audits" do
      controller.send(:current_user=, user)

      expect {
        put :update, id: 123
      }.to_not change(Audited.audit_class, :count)
    end
  end
end


describe Audited::Sweeper, :adapter => :mongo_mapper do

  it "should be thread-safe" do
    t1 = Thread.new do
      sleep 0.5
      Audited::Sweeper.instance.controller = 'thread1 controller instance'
      expect(Audited::Sweeper.instance.controller).to eq('thread1 controller instance')
    end

    t2 = Thread.new do
      Audited::Sweeper.instance.controller = 'thread2 controller instance'
      sleep 1
      expect(Audited::Sweeper.instance.controller).to eq('thread2 controller instance')
    end

    t1.join; t2.join

    expect(Audited::Sweeper.instance.controller).to be_nil
  end

end

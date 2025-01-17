require File.expand_path('../mongo_mapper_spec_helper', __FILE__)

describe Audited::Adapters::MongoMapper::Audit, adapter: :mongo_mapper do
  let(:user) { Models::MongoMapper::User.new name: 'Testing' }

  it "sets created_at timestamp when audit is created" do
    subject.save!
    expect(subject.created_at).to be_a Time
  end

  describe "user=" do
    it "should be able to set the user to a model object" do
      subject.user = user
      expect(subject.user).to eq(user)
    end

    it "should be able to set the user to nil" do
      subject.user_id = 1
      subject.user_type = 'Models::MongoMapper::User'
      subject.username = 'joe'

      subject.user = nil

      expect(subject.user).to be_nil
      expect(subject.user_id).to be_nil
      expect(subject.user_type).to be_nil
      expect(subject.username).to be_nil
    end

    it "should be able to set the user to a string" do
      subject.user = 'test'
      expect(subject.user).to eq('test')
    end

    it "should clear model when setting to a string" do
      subject.user = user
      subject.user = 'testing'
      expect(subject.user_id).to be_nil
      expect(subject.user_type).to be_nil
    end

    it "should clear the username when setting to a model" do
      subject.username = 'test'
      subject.user = user
      expect(subject.username).to be_nil
    end
  end

  describe "revision" do
    it "should recreate attributes" do
      user = Models::MongoMapper::User.create :name => "1"
      5.times { |i| user.update_attribute :name, (i + 2).to_s }

      user.audits.each do |audit|
        expect(audit.revision.name).to eq(audit.version.to_s)
      end
    end

    it "should set protected attributes" do
      u = Models::MongoMapper::User.create(:name => 'Brandon')
      u.update_attribute :logins, 1
      u.update_attribute :logins, 2

      expect(u.audits[2].revision.logins).to eq(2)
      expect(u.audits[1].revision.logins).to eq(1)
      expect(u.audits[0].revision.logins).to eq(0)
    end

    it "should bypass attribute assignment wrappers" do
      u = Models::MongoMapper::User.create(:name => '<Joe>')
      expect(u.audits.first.revision.name).to eq('&lt;Joe&gt;')
    end

    it "should work for deleted records" do
      user = Models::MongoMapper::User.create :name => "1"
      user.destroy
      revision = user.audits.last.revision
      expect(revision.name).to eq(user.name)
      expect(revision).to be_a_new_record
    end
  end

  it "should set the version number on create" do
    user = Models::MongoMapper::User.create! :name => 'Set Version Number'
    expect(user.audits.first.version).to eq(1)
    user.update_attribute :name, "Set to 2"
    audits = user.audits.reload.all
    expect(audits.first.version).to eq(1)
    expect(audits.last.version).to eq(2)
    user.destroy
    expect(Audited.audit_class.where(:auditable_type => 'Models::MongoMapper::User', :auditable_id => user.id).all.last.version).to eq(3)
  end

  it "should set the request uuid on create" do
    user = Models::MongoMapper::User.create! :name => 'Set Request UUID'
    audits = user.audits.reload.all
    expect(audits.first.request_uuid).not_to be_blank
  end

  describe "reconstruct_attributes" do
    it "should work with the old way of storing just the new value" do
      audits = Audited.audit_class.reconstruct_attributes([Audited.audit_class.new(:audited_changes => {'attribute' => 'value'})])
      expect(audits['attribute']).to eq('value')
    end
  end

  describe "audited_classes" do
    class Models::MongoMapper::CustomUser
      include ::MongoMapper::Document
    end
    class Models::MongoMapper::CustomUserSubclass < Models::MongoMapper::CustomUser
      audited
    end

    it "should include audited classes" do
      expect(Audited.audit_class.audited_classes).to include(Models::MongoMapper::User)
    end

    it "should include subclasses" do
      expect(Audited.audit_class.audited_classes).to include(Models::MongoMapper::CustomUserSubclass)
    end
  end

  describe "new_attributes" do
    it "should return a hash of the new values" do
      new_attributes = Audited.audit_class.new(:audited_changes => {:a => [1, 2], :b => [3, 4]}).new_attributes
      expect(new_attributes).to eq({'a' => 2, 'b' => 4})
    end
  end

  describe "old_attributes" do
    it "should return a hash of the old values" do
      old_attributes = Audited.audit_class.new(:audited_changes => {:a => [1, 2], :b => [3, 4]}).old_attributes
      expect(old_attributes).to eq({'a' => 1, 'b' => 3})
    end
  end

  describe "as_user" do
    it "should record user objects" do
      Audited.audit_class.as_user(user) do
        company = Models::MongoMapper::Company.create :name => 'The auditors'
        company.name = 'The Auditors, Inc'
        company.save

        company.audits.each do |audit|
          expect(audit.user).to eq(user)
        end
      end
    end

    it "should record usernames" do
      Audited.audit_class.as_user(user.name) do
        company = Models::MongoMapper::Company.create :name => 'The auditors'
        company.name = 'The Auditors, Inc'
        company.save

        company.audits.each do |audit|
          expect(audit.username).to eq(user.name)
        end
      end
    end

    it "should be thread safe" do
      t1 = Thread.new do
        Audited.audit_class.as_user(user) do
          sleep 1
          expect(Models::MongoMapper::Company.create(:name => 'The Auditors, Inc').audits.first.user).to eq(user)
        end
      end

      t2 = Thread.new do
        Audited.audit_class.as_user(user.name) do
          expect(Models::MongoMapper::Company.create(:name => 'The Competing Auditors, LLC').audits.first.username).to eq(user.name)
          sleep 0.5
        end
      end

      t1.join
      t2.join
    end

    it "should return the value from the yield block" do
      result = Audited.audit_class.as_user('foo') do
        42
      end
      expect(result).to eq(42)
    end

    it "should reset audited_user when the yield block raises an exception" do
      expect {
        Audited.audit_class.as_user('foo') do
          raise StandardError
        end
      }.to raise_exception
      expect(Audited.store[:audited_user]).to be_nil
    end
  end

  describe "undo" do
    it "should undo changes" do
      user = Models::MongoMapper::User.create(name: "John")
      user.update_attribute(:name, 'Joe')
      user.audits.last.undo
      user.reload

      expect(user.name).to eq("John")
    end

    it "should undo destroyed model" do
      user = Models::MongoMapper::User.create(name: "John")
      user.destroy
      user.audits.last.undo
      user = Models::MongoMapper::User.find_by_name("John")
      expect(user.name).to eq("John")
    end

    it "should undo created model" do
      user = Models::MongoMapper::User.create(name: "John")
      expect {user.audits.last.undo}.to change(Models::MongoMapper::User, :count).by(-1)
    end
  end

  describe "embedded documents" do
    fit "audits changes to the embedded documents" do
      model = Models::MongoMapper::EmbeddingModel.create({
        name: 'Embedding Model',
        embedded_model: Models::MongoMapper::EmbeddedModel.new({
          name: 'Embedded Model',
          description: 'Description'
        })
      })

      model.embedded_model.name = 'New Name'
      model.embedded_model.description = 'New Description'

      expect(model.audits.first.version).to eq(1)
      expect(model.embedded_model.audits.first.version).to eq(1)

      model.save!

      audits = model.audits.reload.all
      expect(audits.length).to eq(1)

      audits = model.embedded_model.audits.reload.all
      expect(audits.length).to eq(2)
      expect(audits.last.version).to eq(2)
    end
  end
end

describe Audited::Audit do
  # Most tests are in the specific adaptor's spec file.

  describe "audit class" do
    around(:example) do |example|
      original_audit_class = Audited.audit_class

      class CustomAudit < Audited::Audit
        def custom_method
          "I'm custom!"
        end
      end

      class TempModel < ::ActiveRecord::Base
        self.table_name = :companies
      end

      example.run

      Audited.config { |config| config.audit_class = original_audit_class }
      Audited::Audit.audited_class_names.delete("TempModel")
      Object.send(:remove_const, :TempModel)
      Object.send(:remove_const, :CustomAudit)
    end

    context "when a custom audit class is configured" do
      it "should be used in place of #{described_class}" do
        Audited.config { |config| config.audit_class = CustomAudit }
        TempModel.audited

        record = TempModel.create

        audit = record.audits.first
        expect(audit).to be_a CustomAudit
        expect(audit.custom_method).to eq "I'm custom!"
      end
    end

    context "when a custom audit class is not configured" do
      it "should default to #{described_class}" do
        TempModel.audited

        record = TempModel.create

        audit = record.audits.first
        expect(audit).to be_a Audited::Adapters::ActiveRecord::Audit
        expect(audit.respond_to?(:custom_method)).to be false
      end
    end
  end
end
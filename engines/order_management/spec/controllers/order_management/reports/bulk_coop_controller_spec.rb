# frozen_string_literal: true

require "spec_helper"

describe OrderManagement::Reports::BulkCoopController, type: :controller do
  let(:report_klass) { OrderManagement::Reports::BulkCoop }

  let!(:distributor) { create(:distributor_enterprise) }

  let(:current_user) { distributor.owner }

  before do
    allow(controller).to receive(:spree_current_user) { current_user }
  end

  describe "#new" do
    it "renders the report form" do
      get :new

      expect(response).to be_success
      expect(response).to render_template(new_template_path)
    end
  end

  describe "#create" do
    context "when the parameters are valid" do
      it "sends the generated report in the correct format" do
        post :create, report: {
          start_at: "2018-10-09 07:30:00",
          report_type: "bulk_coop_supplier_report"
        }, report_format: "csv"

        expect(response).to be_success
        expect(response.body).not_to be_blank
        expect(response.header["Content-Type"]).to eq("text/csv")
      end
    end

    context "when the parameters are invalid" do
      it "renders the report form with an error" do
        post :create, report: {
          start_at: "invalid_date",
          report_type: "bulk_coop_supplier_report"
        }, report_format: "csv"

        expect(flash[:error]).to eq(I18n.t("invalid_filter_parameters", scope: i18n_scope))
        expect(response).to render_template(new_template_path)
      end
    end

    context "when some parameters are now allowed" do
      let!(:distributor) { create(:distributor_enterprise) }
      let!(:other_distributor) { create(:distributor_enterprise) }

      let(:current_user) { distributor.owner }

      it "renders the report form with an error" do
        post :create, report: {
          distributor_ids: [other_distributor.id],
          report_type: "bulk_coop_supplier_report"
        }, report_format: "csv"

        expect(flash[:error]).to eq(report_klass::Authorizer.parameter_not_allowed_error_message)
        expect(response).to render_template(new_template_path)
      end
    end

    describe "filtering results based on permissions" do
      let!(:distributor) { create(:distributor_enterprise) }
      let!(:other_distributor) { create(:distributor_enterprise) }

      let(:current_user) { distributor.owner }

      it "applies permissions to report" do
        post :create, report: {}, report_format: "csv"

        expect(assigns(:permissions).allowed_distributors.to_a).to eq([distributor])
      end
    end
  end

  private

  def default_report_params
    {
      report_type: "bulk_coop_supplier_report"
    }
  end

  def i18n_scope
    "order_management.reports.enterprise_fee_summary"
  end

  def new_template_path
    "order_management/reports/bulk_coop/new"
  end
end

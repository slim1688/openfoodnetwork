# frozen_string_literal: true

require "spec_helper"

module Api
  describe TermsAndConditionsController, type: :controller do
    include AuthenticationHelper

    let(:enterprise_owner) { create(:user) }
    let(:enterprise) { create(:enterprise, owner: enterprise_owner ) }
    let(:enterprise_manager) { create(:user, enterprises: [enterprise]) }

    describe "removing terms and conditions file" do
      fake_terms_file_path = File.open(Rails.root.join("app", "assets", "images", "logo-black.png"))
      let(:terms_and_conditions_file) { Rack::Test::UploadedFile.new(fake_terms_file_path, "application/pdf") }
      let(:enterprise) { create(:enterprise, owner: enterprise_owner) }

      before do
        allow(controller).to receive(:spree_current_user) { current_user }
        enterprise.update terms_and_conditions: terms_and_conditions_file
      end

      context "as manager" do
        let(:current_user) { enterprise_manager }

        it "removes terms and conditions file" do
          spree_delete :destroy, enterprise_id: enterprise

          expect(response).to be_success
          expect(json_response["id"]).to eq enterprise.id
          enterprise.reload
          expect(enterprise.terms_and_conditions?).to be false
        end

        context "when terms and conditions file does not exist" do
          let(:enterprise) { create(:enterprise, owner: enterprise_owner) }

          before do
            enterprise.update terms_and_conditions: nil
          end

          it "responds with error" do
            spree_delete :destroy, enterprise_id: enterprise

            expect(response.status).to eq(409)
            expect(json_response["error"]).to eq I18n.t("api.enterprise_terms_and_conditions.destroy_attachment_does_not_exist")
          end
        end
      end
    end
  end
end

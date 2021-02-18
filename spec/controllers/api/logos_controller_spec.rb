# frozen_string_literal: true

require "spec_helper"

module Api
  describe LogosController, type: :controller do
    include AuthenticationHelper

    let(:admin_user) { create(:admin_user) }
    let(:enterprise_owner) { create(:user) }
    let(:enterprise) { create(:enterprise, owner: enterprise_owner ) }
    let(:enterprise_manager) { create(:user, enterprise_limit: 10, enterprises: [enterprise]) }
    let(:other_enterprise_owner) { create(:user) }
    let(:other_enterprise) { create(:enterprise, owner: other_enterprise_owner ) }
    let(:other_enterprise_manager) { create(:user, enterprise_limit: 10, enterprises: [other_enterprise]) }

    describe "removing logo" do
      image_path = File.open(Rails.root.join("app", "assets", "images", "logo-black.png"))
      let(:image) { Rack::Test::UploadedFile.new(image_path, "image/png") }

      let(:enterprise) { create(:enterprise, owner: enterprise_owner, logo: image) }

      before do
        allow(controller).to receive(:spree_current_user) { current_user }
      end

      context "as manager" do
        let(:current_user) { enterprise_manager }

        it "removes logo" do
          spree_delete :destroy, enterprise_id: enterprise

          expect(response).to be_success
          expect(json_response["id"]).to eq enterprise.id
          enterprise.reload
          expect(enterprise.logo?).to be false
        end

        context "when logo does not exist" do
          let(:enterprise) { create(:enterprise, owner: enterprise_owner, logo: nil) }

          it "responds with error" do
            spree_delete :destroy, enterprise_id: enterprise

            expect(response.status).to eq(409)
            expect(json_response["error"]).to eq I18n.t("api.enterprise_logo.destroy_attachment_does_not_exist")
          end
        end
      end

      context "as owner" do
        let(:current_user) { enterprise_owner }

        it "allows removal of logo" do
          spree_delete :destroy, enterprise_id: enterprise
          expect(response).to be_success
        end
      end

      context "as super admin" do
        let(:current_user) { admin_user }

        it "allows removal of logo" do
          spree_delete :destroy, enterprise_id: enterprise
          expect(response).to be_success
        end
      end

      context "as manager of other enterprise" do
        let(:current_user) { other_enterprise_manager }

        it "does not allow removal of logo" do
          spree_delete :destroy, enterprise_id: enterprise
          expect(response.status).to eq(401)
          enterprise.reload
          expect(enterprise.logo?).to be true
        end
      end

      context "as owner of other enterprise" do
        let(:current_user) { other_enterprise_owner }

        it "does not allow removal of logo" do
          spree_delete :destroy, enterprise_id: enterprise
          expect(response.status).to eq(401)
          enterprise.reload
          expect(enterprise.logo?).to be true
        end
      end
    end
  end
end

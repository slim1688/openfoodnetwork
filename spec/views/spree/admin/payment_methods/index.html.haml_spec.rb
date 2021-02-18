# frozen_string_literal: true

require "spec_helper"

describe "spree/admin/payment_methods/index.html.haml" do
  include AuthenticationHelper

  before do
    controller.singleton_class.class_eval do
      helper_method :new_object_url, :edit_object_url, :object_url

      def new_object_url() "" end

      def edit_object_url(_object, _options = {}) "" end

      def object_url(_object = nil, _options = {}) "" end
    end

    assign(:payment_methods, [
             create(:payment_method),
             create(:payment_method)
           ])
  end

  describe "payment methods index page" do
    context "when user is not admin" do
      before do
        allow(view).to receive_messages spree_current_user: create(:user)
      end

      it "shows only the providers of the existing payment methods" do
        render

        expect(rendered).to have_content "Cash/EFT/etc. (payments for which automatic validation is not required)", count: 2
      end

      it "does not show Enviroment column" do
        render

        expect(rendered).not_to have_content "Environment"
      end

      it "does not show column content" do
        render

        expect(rendered).not_to have_content "Test"
      end
    end

    context "when user is admin" do
      before do
        allow(view).to receive_messages spree_current_user: create(:admin_user)
      end

      it "shows only the providers of the existing payment methods" do
        render

        expect(rendered).to have_content "Cash/EFT/etc. (payments for which automatic validation is not required)", count: 2
      end

      it "shows the Enviroment column" do
        render

        expect(rendered).to have_content "Environment"
      end

      it "shows the column content" do
        render

        expect(rendered).to have_content "Test"
      end
    end
  end
end

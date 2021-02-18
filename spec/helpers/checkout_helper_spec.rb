# frozen_string_literal: true

require 'spec_helper'

describe CheckoutHelper, type: :helper do
  it "generates html for validated inputs" do
    expect(helper).to receive(:render).with(
      "shared/validated_input",
      name: "test",
      path: "foo",
      attributes: { :required => true, :type => :email, :name => "foo", :id => "foo", "ng-model" => "foo", "ng-class" => "{error: !fieldValid('foo')}" }
    )

    helper.validated_input("test", "foo", type: :email)
  end

  describe "displaying the tax total for an order" do
    let(:order) { double(:order, total_tax: 123.45, currency: 'AUD') }

    it "retrieves the total tax on the order" do
      expect(helper.display_checkout_tax_total(order)).to eq(Spree::Money.new(123.45, currency: 'AUD'))
    end
  end

  it "knows if guests can checkout" do
    distributor = create(:distributor_enterprise)
    order = create(:order, distributor: distributor)
    allow(helper).to receive(:current_order) { order }
    expect(helper.guest_checkout_allowed?).to be true

    order.distributor.allow_guest_orders = false
    expect(helper.guest_checkout_allowed?).to be false
  end

  describe "#checkout_adjustments_for" do
    let(:order) { create(:order_with_totals_and_distribution) }
    let(:enterprise_fee) { create(:enterprise_fee, amount: 123) }
    let!(:fee_adjustment) {
      create(:adjustment, originator: enterprise_fee, adjustable: order, source: order)
    }

    before do
      # Sanity check initial adjustments state
      expect(order.adjustments.shipping.count).to eq 1
      expect(order.adjustments.enterprise_fee.count).to eq 1
    end

    it "collects adjustments on the order" do
      adjustments = helper.checkout_adjustments_for(order)

      shipping_adjustment = order.adjustments.shipping.first
      expect(adjustments).to include shipping_adjustment

      admin_fee_summary = adjustments.last
      expect(admin_fee_summary.label).to eq I18n.t(:orders_form_admin)
      expect(admin_fee_summary.amount).to eq 123
    end
  end
end

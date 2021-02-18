# frozen_string_literal: true

require 'spec_helper'

describe ConfirmOrderJob do
  let(:order) { create(:order) }

  it "sends confirmation emails to both the user and the shop owner" do
    customer_confirm_fake = double(:confirm_email_for_customer)
    shop_confirm_fake = double(:confirm_email_for_shop)
    expect(Spree::OrderMailer).to receive(:confirm_email_for_customer).and_return customer_confirm_fake
    expect(Spree::OrderMailer).to receive(:confirm_email_for_shop).and_return shop_confirm_fake
    expect(customer_confirm_fake).to receive :deliver_now
    expect(shop_confirm_fake).to receive :deliver_now

    ConfirmOrderJob.perform_now order.id
  end
end

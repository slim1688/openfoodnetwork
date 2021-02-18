# frozen_string_literal: true

require 'spec_helper'

describe Api::OrderSerializer do
  let(:serializer) { Api::OrderSerializer.new order }
  let(:order) { create(:completed_order_with_totals) }

  describe '#serializable_hash' do
    let!(:completed_payment) do
      create(:payment, order: order, state: 'completed', amount: order.total - 1)
    end
    let!(:payment) { create(:payment, order: order, state: 'checkout', amount: 123.45) }

    it "serializes an order" do
      expect(serializer.serializable_hash[:number]).to eq(order.number)
    end

    it "convert the state attributes to translatable keys" do
      hash = serializer.serializable_hash

      expect(hash[:state]).to eq("complete")
      expect(hash[:payment_state]).to eq("balance_due")
    end

    it "only serializes completed payments" do
      hash = serializer.serializable_hash

      expect(hash[:payments].first[:amount]).to eq(completed_payment.amount)
    end
  end

  describe '#outstanding_balance' do
    context 'when the customer_balance feature is enabled' do
      before do
        allow(OpenFoodNetwork::FeatureToggle)
          .to receive(:enabled?).with(:customer_balance, order.user) { true }

        allow(order).to receive(:balance_value).and_return(-1.23)
      end

      it "returns the object's balance_value from the users perspective" do
        expect(serializer.serializable_hash[:outstanding_balance]).to eq(1.23)
      end
    end

    context 'when the customer_balance is not enabled' do
      before do
        allow(OpenFoodNetwork::FeatureToggle)
          .to receive(:enabled?).with(:customer_balance, order.user) { false }

        allow(order).to receive(:outstanding_balance).and_return(123.0)
      end

      it 'calls #outstanding_balance on the object' do
        expect(serializer.serializable_hash[:outstanding_balance]).to eq(123.0)
      end
    end
  end
end

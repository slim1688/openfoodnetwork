# frozen_string_literal: true

require 'spec_helper'

describe OrderCyclesHelper, type: :helper do
  let(:oc) { double(:order_cycle) }

  describe "finding producer enterprise options" do
    before do
      allow(helper).to receive(:permitted_producer_enterprises_for) { "enterprise list" }
    end

    it "asks for a validation option list" do
      expect(helper).to receive(:validated_enterprise_options).with("enterprise list")
      helper.permitted_producer_enterprise_options_for(oc)
    end
  end

  describe "finding coodinator enterprise options" do
    before do
      allow(helper).to receive(:permitted_coordinating_enterprises_for) { "enterprise list" }
    end

    it "asks for a validation option list" do
      expect(helper).to receive(:validated_enterprise_options).with("enterprise list")
      helper.permitted_coordinating_enterprise_options_for(oc)
    end
  end

  describe "finding hub enterprise options" do
    before do
      allow(helper).to receive(:permitted_hub_enterprises_for) { "enterprise list" }
    end

    it "asks for a validation option list" do
      expect(helper).to receive(:validated_enterprise_options).with("enterprise list", shipping_and_payment_methods: true)
      helper.permitted_hub_enterprise_options_for(oc)
    end
  end

  describe "building a validated enterprise list" do
    let(:e) { create(:distributor_enterprise, name: 'enterprise') }

    it "returns enterprises without shipping methods as disabled" do
      create(:payment_method, distributors: [e])
      expect(helper.send(:validated_enterprise_options, [e], shipping_and_payment_methods: true))
        .to eq [['enterprise (no shipping methods)', e.id, { disabled: true }]]
    end

    it "returns enterprises without payment methods as disabled" do
      create(:shipping_method, distributors: [e])
      expect(helper.send(:validated_enterprise_options, [e], shipping_and_payment_methods: true))
        .to eq [['enterprise (no payment methods)', e.id, { disabled: true }]]
    end

    it "returns enterprises with unavailable payment methods as disabled" do
      create(:shipping_method, distributors: [e])
      create(:payment_method, distributors: [e], active: false)
      expect(helper.send(:validated_enterprise_options, [e], shipping_and_payment_methods: true))
        .to eq [['enterprise (no payment methods)', e.id, { disabled: true }]]
    end

    it "returns enterprises with neither shipping nor payment methods as disabled" do
      expect(helper.send(:validated_enterprise_options, [e], shipping_and_payment_methods: true))
        .to eq [['enterprise (no shipping or payment methods)', e.id, { disabled: true }]]
    end
  end

  describe "pickup time" do
    it "gives me the pickup time for the current order cycle" do
      d = create(:distributor_enterprise, name: 'Green Grass')
      oc1 = create(:simple_order_cycle, name: 'oc 1', distributors: [d])
      exchange = Exchange.find(oc1.exchanges.to_enterprises(d).outgoing.first.id)
      exchange.update_attribute :pickup_time, "turtles"

      allow(helper).to receive(:current_order_cycle).and_return oc1
      allow(helper).to receive(:current_distributor).and_return d
      expect(helper.pickup_time).to eq("turtles")
    end

    it "gives me the pickup time for any order cycle" do
      d = create(:distributor_enterprise, name: 'Green Grass')
      oc1 = create(:simple_order_cycle, name: 'oc 1', distributors: [d])
      oc2 = create(:simple_order_cycle, name: 'oc 1', distributors: [d])

      exchange = Exchange.find(oc2.exchanges.to_enterprises(d).outgoing.first.id)
      exchange.update_attribute :pickup_time, "turtles"

      allow(helper).to receive(:current_order_cycle).and_return oc1
      allow(helper).to receive(:current_distributor).and_return d
      expect(helper.pickup_time(oc2)).to eq("turtles")
    end
  end
end

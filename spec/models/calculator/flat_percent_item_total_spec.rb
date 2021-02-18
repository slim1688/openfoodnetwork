# frozen_string_literal: true

require 'spec_helper'

describe Calculator::FlatPercentItemTotal do
  let(:calculator) { Calculator::FlatPercentItemTotal.new }
  let(:line_item) { build_stubbed(:line_item, price: 10, quantity: 1) }

  before { allow(calculator).to receive_messages preferred_flat_percent: 10 }

  it "computes amount correctly for a single line item" do
    expect(calculator.compute(line_item)).to eq(1.0)
  end

  context "extends LocalizedNumber" do
    it_behaves_like "a model using the LocalizedNumber module", [:preferred_flat_percent]
  end

  it "computes amount correctly for a given OrderManagement::Stock::Package" do
    order = double(:order, line_items: [line_item] )
    package = double(:package, order: order)

    expect(calculator.compute(package)).to eq(1.0)
  end
end

# frozen_string_literal: true

# This class will be used to get Tax Adjustments related to an order,
# and proceed basic calcultation over them.

class OrderTaxAdjustmentsFetcher
  def initialize(order)
    @order = order
  end

  def totals
    all.each_with_object({}) do |adjustment, hash|
      tax_rates_hash = tax_rates_hash(adjustment)
      hash.update(tax_rates_hash) { |_tax_rate, amount1, amount2| amount1 + amount2 }
    end
  end

  private

  attr_reader :order

  def all
    Spree::Adjustment
      .with_tax
      .where(order_adjustments.or(line_item_adjustments))
      .order('created_at ASC')
  end

  def order_adjustments
    table[:adjustable_id].eq(order.id)
      .and(table[:adjustable_type].eq('Spree::Order'))
  end

  def line_item_adjustments
    table[:adjustable_id].eq_any(order.line_item_ids)
      .and(table[:adjustable_type].eq('Spree::LineItem'))
  end

  def table
    @table ||= Spree::Adjustment.arel_table
  end

  def tax_rates_hash(adjustment)
    tax_rates = TaxRateFinder.tax_rates_of(adjustment)

    Hash[tax_rates.collect do |tax_rate|
      tax_amount = if tax_rates.one?
                     adjustment.included_tax
                   else
                     tax_rate.compute_tax(adjustment.amount)
                   end
      [tax_rate, tax_amount]
    end]
  end
end

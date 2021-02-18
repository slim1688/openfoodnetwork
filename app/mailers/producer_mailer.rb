# frozen_string_literal: true

class ProducerMailer < Spree::BaseMailer
  include I18nHelper

  def order_cycle_report(producer, order_cycle)
    @producer = producer
    @order_cycle = order_cycle

    with_unscoped_products_and_variants do
      load_data

      I18n.with_locale(owner_locale) do
        return unless orders?(order_cycle, producer)

        mail(
          to: @producer.contact.email,
          from: from_address,
          subject: subject,
          reply_to: @coordinator.contact.email,
          cc: @coordinator.contact.email
        )
      end
    end
  end

  private

  def owner_locale
    valid_locale(@producer.owner)
  end

  def load_data
    @coordinator = @order_cycle.coordinator

    line_items = line_items_from(@order_cycle, @producer)

    @grouped_line_items = line_items.group_by(&:product_and_full_name)
    @receival_instructions = @order_cycle.receival_instructions_for(@producer)
    @total = total_from_line_items(line_items)
    @tax_total = tax_total_from_line_items(line_items)
  end

  def subject
    order_cycle_subject = I18n.t('producer_mailer.order_cycle.subject', producer: @producer.name)
    "[#{Spree::Config.site_name}] #{order_cycle_subject}"
  end

  def orders?(order_cycle, producer)
    line_items_from(order_cycle, producer).any?
  end

  def line_items_from(order_cycle, producer)
    @line_items ||= Spree::LineItem.
      includes(:option_values, variant: [:product, { option_values: :option_type }]).
      from_order_cycle(order_cycle).
      sorted_by_name_and_unit_value.
      merge(Spree::Product.in_supplier(producer)).
      merge(Spree::Order.by_state('complete'))
  end

  def total_from_line_items(line_items)
    Spree::Money.new line_items.to_a.sum(&:total)
  end

  def tax_total_from_line_items(line_items)
    Spree::Money.new line_items.to_a.sum(&:included_tax)
  end

  # This hack makes ActiveRecord skip the default_scope (deleted_at IS NULL)
  # when eager loading associations. Further details:
  # https://github.com/rails/rails/issues/11036
  def with_unscoped_products_and_variants
    variant_default_scopes = Spree::Variant.default_scopes
    product_default_scopes = Spree::Product.default_scopes

    Spree::Variant.default_scopes = []
    Spree::Product.default_scopes = []

    return_value = yield

    Spree::Variant.default_scopes = variant_default_scopes
    Spree::Product.default_scopes = product_default_scopes

    return_value
  end
end

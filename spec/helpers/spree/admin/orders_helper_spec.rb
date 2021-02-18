# frozen_string_literal: true

require 'spec_helper'

describe Spree::Admin::OrdersHelper, type: :helper do
  describe "#orders_links" do
    let(:order) { double(:order) }
    let(:distributor) { double(:enterprise) }

    around do |example|
      original_invoices_setting = Spree::Config[:enable_invoices?]
      original_tickets_setting = Spree::Config[:enable_receipt_printing?]
      example.run
      Spree::Config[:enable_invoices?] = original_invoices_setting
      Spree::Config[:enable_receipt_printing?] = original_tickets_setting
    end

    before do
      allow(order).to receive(:complete?) { false }
      allow(order).to receive(:ready_to_ship?) { false }
      allow(order).to receive(:can_cancel?) { false }
      Spree::Config[:enable_invoices?] = false
      Spree::Config[:enable_receipt_printing?] = false
    end

    it "returns only edit order link when all conditions are set to false" do
      links = helper.order_links(order)

      expect(links.size).to eq 1
      expect(links.first[:name]).to eq "Edit Order"
    end

    context "complete order" do
      before do
        allow(order).to receive(:complete?) { true }
      end

      it "returns edit order and resend confirmation links" do
        links = helper.order_links(order)

        expect(links.size).to eq 2
        expect(links[0][:name]).to eq "Edit Order"
        expect(links[1][:name]).to eq "Resend Confirmation"
      end

      context "that can be canceled" do
        before do
          allow(order).to receive(:can_cancel?) { true }
          allow(order).to receive(:number) { 111 }
        end

        it "adds cancel order link" do
          links = helper.order_links(order)

          expect(links.size).to eq 3
          expect(links[2][:name]).to eq "Cancel Order"
        end
      end

      context "that can be shipped" do
        before do
          allow(order).to receive(:ready_to_ship?) { true }
        end

        it "adds ship order link" do
          links = helper.order_links(order)

          expect(links.size).to eq 3
          expect(links[2][:name]).to eq "Ship Order"
        end
      end

      context "with invoices enabled" do
        before do
          Spree::Config[:enable_invoices?] = true
          allow(order).to receive(:distributor) { distributor }
          allow(distributor).to receive(:can_invoice?) { true }
        end

        it "adds send and print invoice links" do
          links = helper.order_links(order)

          expect(links.size).to eq 4
          expect(links[2][:name]).to eq "Send Invoice"
          expect(links[3][:name]).to eq "Print Invoice"
        end
      end

      context "with tickets enabled" do
        before do
          Spree::Config[:enable_receipt_printing?] = true
        end

        it "adds print and select ticket links" do
          links = helper.order_links(order)

          expect(links.size).to eq 4
          expect(links[2][:name]).to eq "Print Ticket"
          expect(links[3][:name]).to eq "Select printer for tickets"
        end
      end
    end
  end
end

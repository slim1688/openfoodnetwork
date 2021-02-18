# frozen_string_literal: true

require 'spec_helper'

module OrderManagement
  module Order
    describe Updater do
      let(:order) { create(:order) }
      let(:updater) { OrderManagement::Order::Updater.new(order) }

      before { allow(order).to receive(:backordered?) { false } }

      it "updates totals" do
        allow(order).to receive_message_chain(:payments, :completed, :sum).and_return(10)

        line_items = [double(amount: 10), double(amount: 20)]
        allow(order).to receive_messages line_items: line_items

        allow(order).to receive_message_chain(:adjustments, :eligible, :sum).and_return(-10)

        updater.update_totals
        expect(order.payment_total).to eq 10
        expect(order.item_total).to eq 30
        expect(order.adjustment_total).to eq(-10)
        expect(order.total).to eq 20
      end

      context "updating shipment state" do
        let(:shipment) { build(:shipment) }

        before do
          allow(order).to receive(:shipments).and_return([shipment])
        end

        it "is backordered" do
          allow(shipment).to receive(:backordered?) { true }
          updater.update_shipment_state

          expect(order.shipment_state).to eq 'backorder'
        end

        it "is nil" do
          allow(shipment).to receive(:state).and_return(nil)

          updater.update_shipment_state
          expect(order.shipment_state).to be_nil
        end

        ["shipped", "ready", "pending"].each do |state|
          it "is #{state}" do
            allow(shipment).to receive(:state).and_return(state)
            updater.update_shipment_state
            expect(order.shipment_state).to eq state.to_s
          end
        end
      end

      it "state change" do
        order = create(:order)
        order.shipment_state = 'shipped'
        state_changes = double
        allow(order).to receive(:state_changes) { state_changes }
        expect(state_changes).to receive(:create).with(
          previous_state: nil,
          next_state: 'shipped',
          name: 'shipment',
          user_id: order.user_id
        )

        order.state_changed('shipment')
      end

      context "completed order" do
        before { allow(order).to receive(:completed?) { true } }

        it "updates payment state" do
          expect(updater).to receive(:update_payment_state)
          updater.update
        end

        it "updates shipment state" do
          expect(updater).to receive(:update_shipment_state)
          updater.update
        end

        it "updates the order shipment" do
          shipment = build(:shipment)
          allow(order).to receive_messages shipments: [shipment]

          expect(shipment).to receive(:update!).with(order)
          updater.update
        end
      end

      context "incompleted order" do
        before { allow(order).to receive_messages completed?: false }

        it "doesnt update payment state" do
          expect(updater).not_to receive(:update_payment_state)
          updater.update
        end

        it "doesnt update shipment state" do
          expect(updater).not_to receive(:update_shipment_state)
          updater.update
        end

        it "doesnt update the order shipment" do
          shipment = build(:shipment)
          allow(order).to receive_messages shipments: [shipment]

          expect(shipment).not_to receive(:update!).with(order)
          updater.update
        end
      end

      it "updates totals twice" do
        expect(updater).to receive(:update_totals).twice
        updater.update
      end

      it "updates all adjustments" do
        expect(updater).to receive(:update_all_adjustments)
        updater.update
      end

      it "is failed if no valid payments" do
        allow(order).to receive_message_chain(:payments, :valid, :empty?).and_return(true)

        updater.update_payment_state
        expect(order.payment_state).to eq('failed')
      end

      context "payment total is greater than order total" do
        it "is credit_owed" do
          order.payment_total = 2
          order.total = 1

          expect {
            updater.update_payment_state
          }.to change { order.payment_state }.to 'credit_owed'
        end
      end

      context "order total is greater than payment total" do
        it "is credit_owed" do
          order.payment_total = 1
          order.total = 2

          expect {
            updater.update_payment_state
          }.to change { order.payment_state }.to 'balance_due'
        end
      end

      context "order total equals payment total" do
        it "is paid" do
          order.payment_total = 30
          order.total = 30

          expect {
            updater.update_payment_state
          }.to change { order.payment_state }.to 'paid'
        end
      end

      context "order is canceled" do
        before do
          order.state = 'canceled'
        end

        context "and is still unpaid" do
          it "is void" do
            order.payment_total = 0
            order.total = 30
            expect {
              updater.update_payment_state
            }.to change { order.payment_state }.to 'void'
          end
        end

        context "and is paid" do
          it "is credit_owed" do
            order.payment_total = 30
            order.total = 30
            allow(order).to receive_message_chain(:payments, :valid, :empty?).and_return(false)
            allow(order).to receive_message_chain(:payments, :completed, :empty?).and_return(false)
            expect {
              updater.update_payment_state
            }.to change { order.payment_state }.to 'credit_owed'
          end
        end

        context "and payment is refunded" do
          it "is void" do
            order.payment_total = 0
            order.total = 30
            allow(order).to receive_message_chain(:payments, :valid, :empty?).and_return(false)
            allow(order).to receive_message_chain(:payments, :completed, :empty?).and_return(false)
            expect {
              updater.update_payment_state
            }.to change { order.payment_state }.to 'void'
          end
        end
      end

      context 'when the set payment_state does not match the last payment_state' do
        before { order.payment_state = 'previous_to_paid' }

        context 'and the order is being updated' do
          before { allow(order).to receive(:persisted?) { true } }

          it 'creates a new state_change for the order' do
            expect { updater.update_payment_state }
              .to change { order.state_changes.size }.by(1)
          end
        end

        context 'and the order is being created' do
          before { allow(order).to receive(:persisted?) { false } }

          it 'creates a new state_change for the order' do
            expect { updater.update_payment_state }
              .not_to change { order.state_changes.size }
          end
        end
      end

      context 'when the set payment_state matches the last payment_state' do
        before { order.payment_state = 'paid' }

        it 'does not create any state_change' do
          expect { updater.update_payment_state }
            .not_to change { order.state_changes.size }
        end
      end

      context '#before_save_hook' do
        let(:distributor) { build(:distributor_enterprise) }
        let(:shipment) {
          create(:shipment_with, :shipping_method, shipping_method: shipping_method)
        }

        before do
          order.distributor = distributor
          order.shipments = [shipment]
        end

        context 'when shipping method is pickup' do
          let(:shipping_method) { create(:shipping_method_with, :pickup) }
          let(:address) { build(:address, firstname: 'joe') }
          before { distributor.address = address }

          it "populates the shipping address from distributor" do
            updater.before_save_hook
            expect(order.ship_address.address1).to eq(distributor.address.address1)
          end
        end

        context 'when shipping_method is delivery' do
          let(:shipping_method) { create(:shipping_method_with, :delivery) }
          let(:address) { build(:address, firstname: 'will') }
          before { order.ship_address = address }

          it "does not populate the shipping address from distributor" do
            updater.before_save_hook
            expect(order.ship_address.firstname).to eq("will")
          end
        end
      end
    end
  end
end

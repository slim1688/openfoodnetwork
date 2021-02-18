# frozen_string_literal: true

require 'spec_helper'

module OrderManagement
  module Order
    describe StripeScaPaymentAuthorize do
      let(:order) { create(:order) }
      let(:payment_authorize) {
        OrderManagement::Order::StripeScaPaymentAuthorize.new(order)
      }

      describe "#call!" do
        context "when no pending payments are present" do
          before { allow(order).to receive(:pending_payments).once { [] } }

          it "does nothing" do
            expect(payment_authorize.call!).to eq nil
          end
        end

        context "when a payment is present" do
          let(:payment) { create(:payment, amount: 10) }

          before { allow(order).to receive(:pending_payments).once { [payment] } }

          context "in a state that is not checkout" do
            before { payment.state = "processing" }

            it "does nothing" do
              payment_authorize.call!

              expect(payment.state).to eq "processing"
              expect(order.errors.size).to eq 0
            end
          end

          context "in the checkout state" do
            before { payment.state = "checkout" }

            context "and payment authorize moves the payment state to pending" do
              before { expect(payment).to receive(:authorize!) { payment.state = "pending" } }

              it "does nothing" do
                payment_authorize.call!

                expect(order.errors.size).to eq 0
              end
            end

            context "and payment authorize does not move the payment state to pending" do
              before { allow(payment).to receive(:authorize!) { payment.state = "failed" } }

              it "adds an error to the order indicating authorization failure" do
                payment_authorize.call!

                expect(order.errors[:base].first).to eq "Authorization Failure"
              end
            end

            context "and payment authorize requires additional authorization" do
              let(:mail_mock) { double(:mailer_mock, deliver_now: true) }

              before do
                allow(PaymentMailer).to receive(:authorize_payment) { mail_mock }
                allow(PaymentMailer).to receive(:authorization_required) { mail_mock }
                allow(payment).to receive(:authorize!) {
                  payment.state = "pending"
                  payment.cvv_response_message = "https://stripe.com/redirect"
                }
              end

              it "sends an email requesting authorization and an email notifying the shop owner when requested" do
                payment_authorize.extend(OrderManagement::Order::SendAuthorizationEmails).call!

                expect(order.errors.size).to eq 0
                expect(PaymentMailer).to have_received(:authorize_payment)
                expect(PaymentMailer).to have_received(:authorization_required)
                expect(mail_mock).to have_received(:deliver_now).twice
              end

              it "doesn't send emails by default" do
                payment_authorize.call!

                expect(order.errors.size).to eq 0
                expect(PaymentMailer).to_not have_received(:authorize_payment)
                expect(PaymentMailer).to_not have_received(:authorization_required)
                expect(mail_mock).to_not have_received(:deliver_now)
              end
            end
          end
        end
      end
    end
  end
end

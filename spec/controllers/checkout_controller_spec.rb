# frozen_string_literal: true

require 'spec_helper'

describe CheckoutController, type: :controller do
  let(:distributor) { create(:distributor_enterprise, with_payment_and_shipping: true) }
  let(:order_cycle) { create(:simple_order_cycle) }
  let(:order) { create(:order) }
  let(:reset_order_service) { double(OrderCompletionReset) }

  before do
    allow(order).to receive(:checkout_allowed?).and_return true
    allow(controller).to receive(:check_authorization).and_return true
  end

  it "redirects home when no distributor is selected" do
    get :edit
    expect(response).to redirect_to root_path
  end

  it "redirects to the shop when no order cycle is selected" do
    allow(controller).to receive(:current_distributor).and_return(distributor)
    get :edit
    expect(response).to redirect_to shop_path
  end

  it "redirects home with message if hub is not ready for checkout" do
    allow(distributor).to receive(:ready_for_checkout?) { false }
    allow(order).to receive_messages(distributor: distributor, order_cycle: order_cycle)
    allow(controller).to receive(:current_order).and_return(order)

    expect(order).to receive(:empty!)
    expect(order).to receive(:set_distribution!).with(nil, nil)

    get :edit

    expect(response).to redirect_to root_url
    expect(flash[:info]).to eq(I18n.t('order_cycles_closed_for_hub'))
  end

  describe "redirection to cart and stripe" do
    let(:order_cycle_distributed_variants) { double(:order_cycle_distributed_variants) }

    before do
      allow(controller).to receive(:current_order).and_return(order)
      allow(order).to receive(:distributor).and_return(distributor)
      order.order_cycle = order_cycle

      allow(OrderCycleDistributedVariants).to receive(:new).and_return(order_cycle_distributed_variants)
    end

    it "redirects when some items are out of stock" do
      allow(order).to receive_message_chain(:insufficient_stock_lines, :empty?).and_return false

      get :edit
      expect(response).to redirect_to cart_path
    end

    it "redirects when some items are not available" do
      allow(order).to receive_message_chain(:insufficient_stock_lines, :empty?).and_return true
      expect(order_cycle_distributed_variants).to receive(:distributes_order_variants?).with(order).and_return(false)

      get :edit
      expect(response).to redirect_to cart_path
    end

    describe "when items are available and in stock" do
      before do
        allow(order).to receive_message_chain(:insufficient_stock_lines, :empty?).and_return true
      end

      describe "order variants are distributed in the OC" do
        before do
          expect(order_cycle_distributed_variants).to receive(:distributes_order_variants?).with(order).and_return(true)
        end

        it "does not redirect" do
          get :edit
          expect(response).to be_success
        end

        it "returns a specific flash message when Spree::Core::GatewayError occurs" do
          order_checkout_restart = double(:order_checkout_restart)
          allow(OrderCheckoutRestart).to receive(:new) { order_checkout_restart }
          call_count = 0
          allow(order_checkout_restart).to receive(:call) do
            call_count += 1
            raise Spree::Core::GatewayError, "Gateway blow up" if call_count == 1
          end

          spree_post :edit

          expect(response.status).to eq(200)
          flash_message = I18n.t(:spree_gateway_error_flash_for_checkout, error: "Gateway blow up")
          expect(flash[:error]).to eq flash_message
        end
      end

      describe "when the order is in payment state and a stripe payment intent is provided" do
        before do
          order.update_attribute :state, "payment"
          order.ship_address = create(:address)
          order.save!
          order.payments << create(:payment, state: "pending", response_code: "pi_123")

          # this is called a 2nd time after order completion from the reset_order_service
          expect(order_cycle_distributed_variants).to receive(:distributes_order_variants?).twice.and_return(true)
        end

        it "completes the order and redirects to the order confirmation page" do
          get :edit, { payment_intent: "pi_123" }
          expect(order.completed?).to be true
          expect(response).to redirect_to order_path(order)
        end
      end
    end
  end

  describe "building the order" do
    before do
      allow(controller).to receive(:current_distributor).and_return(distributor)
      allow(controller).to receive(:current_order_cycle).and_return(order_cycle)
      allow(controller).to receive(:current_order).and_return(order)
    end

    it "set shipping_address_from_distributor when re-rendering edit" do
      expect(order.updater).to receive(:shipping_address_from_distributor)
      allow(order).to receive(:update).and_return false
      spree_post :update, format: :json, order: {}
    end

    it "set shipping_address_from_distributor when the order state cannot be advanced" do
      expect(order.updater).to receive(:shipping_address_from_distributor)
      allow(order).to receive(:update).and_return true
      allow(order).to receive(:next).and_return false
      spree_post :update, format: :json, order: {}
    end

    context "#update with shipping_method_id" do
      let(:test_shipping_method_id) { "111" }

      before do
        # stub order and OrderCompletionReset
        allow(OrderCompletionReset).to receive(:new).with(controller, order) { reset_order_service }
        allow(reset_order_service).to receive(:call)
        allow(order).to receive(:update).and_return true
        allow(controller).to receive(:current_order).and_return order

        # make order workflow pass through delivery
        allow(order).to receive(:next).twice do
          if order.state == 'cart'
            order.update_column :state, 'delivery'
          else
            order.update_column :state, 'complete'
          end
        end
      end

      it "does not fail to update" do
        expect(controller).to_not receive(:clear_ship_address)
        spree_post :update, order: { shipping_method_id: test_shipping_method_id }
      end

      it "does not send shipping_method_id to the order model as an attribute" do
        expect(order).to receive(:update).with({})
        spree_post :update, order: { shipping_method_id: test_shipping_method_id }
      end

      it "selects the shipping_method in the order" do
        expect(order).to receive(:select_shipping_method).with(test_shipping_method_id)
        spree_post :update, order: { shipping_method_id: test_shipping_method_id }
      end
    end

    context 'when completing the order' do
      before do
        order.state = 'complete'
        order.save!
        allow(order).to receive(:update).and_return(true)
        allow(order).to receive(:next).and_return(true)
        allow(order).to receive(:set_distributor!).and_return(true)
      end

      it "sets the new order's token to the same as the old order" do
        order = controller.current_order(true)
        spree_post :update, order: {}
        expect(controller.current_order.token).to eq order.token
      end

      it 'expires the current order' do
        allow(controller).to receive(:expire_current_order)
        put :update, order: {}
        expect(controller).to have_received(:expire_current_order)
      end

      it 'sets the access_token of the session' do
        put :update, order: {}
        expect(session[:access_token]).to eq(controller.current_order.token)
      end
    end
  end

  describe '#expire_current_order' do
    it 'empties the order_id of the session' do
      expect(session).to receive(:[]=).with(:order_id, nil)
      controller.expire_current_order
    end

    it 'resets the @current_order ivar' do
      controller.expire_current_order
      expect(controller.instance_variable_get(:@current_order)).to be_nil
    end
  end

  context "via xhr" do
    before do
      allow(controller).to receive(:current_distributor).and_return(distributor)

      allow(controller).to receive(:current_order_cycle).and_return(order_cycle)
      allow(controller).to receive(:current_order).and_return(order)
    end

    it "returns errors and flash if order.update_attributes fails" do
      spree_post :update, format: :json, order: {}
      expect(response.status).to eq(400)
      expect(response.body).to eq({ errors: assigns[:order].errors, flash: { error: order.errors.full_messages.to_sentence } }.to_json)
    end

    it "returns errors and flash if order.next fails" do
      allow(order).to receive(:update).and_return true
      allow(order).to receive(:next).and_return false
      spree_post :update, format: :json, order: {}
      expect(response.body).to eq({ errors: assigns[:order].errors, flash: { error: "Payment could not be processed, please check the details you entered" } }.to_json)
    end

    it "returns order confirmation url on success" do
      allow(OrderCompletionReset).to receive(:new).with(controller, order) { reset_order_service }
      expect(reset_order_service).to receive(:call)

      allow(order).to receive(:update).and_return true
      allow(order).to receive(:state).and_return "complete"

      spree_post :update, format: :json, order: {}
      expect(response.status).to eq(200)
      expect(response.body).to eq({ path: order_path(order) }.to_json)
    end

    it "returns an error on unexpected failure" do
      allow(order).to receive(:update).and_raise

      spree_post :update, format: :json, order: {}
      expect(response.status).to eq(400)
      expect(response.body).to eq({ errors: {}, flash: { error: I18n.t("checkout.failed") } }.to_json)
    end

    it "returns a specific error on Spree::Core::GatewayError" do
      allow(order).to receive(:update).and_raise(Spree::Core::GatewayError.new("Gateway blow up"))
      spree_post :update, format: :json, order: {}

      expect(response.status).to eq(400)
      flash_message = I18n.t(:spree_gateway_error_flash_for_checkout, error: "Gateway blow up")
      expect(json_response["flash"]["error"]).to eq flash_message
    end

    describe "stale object handling" do
      it "retries when a stale object error is encountered" do
        allow(OrderCompletionReset).to receive(:new).with(controller, order) { reset_order_service }
        expect(reset_order_service).to receive(:call)

        allow(order).to receive(:update).and_return true
        allow(controller).to receive(:state_callback)

        # The first time, raise a StaleObjectError. The second time, succeed.
        allow(order).to receive(:next).once.
          and_raise(ActiveRecord::StaleObjectError.new(Spree::Variant.new, 'update'))
        allow(order).to receive(:next).once do
          order.update_column :state, 'complete'
          true
        end

        spree_post :update, format: :json, order: {}
        expect(response.status).to eq(200)
      end

      it "tries a maximum of 3 times before giving up and returning an error" do
        allow(order).to receive(:update).and_return true
        allow(order).to receive(:next) { raise ActiveRecord::StaleObjectError.new(Spree::Variant.new, 'update') }

        spree_post :update, format: :json, order: {}
        expect(response.status).to eq(400)
      end
    end
  end

  describe "Payment redirects" do
    before do
      allow(controller).to receive(:current_distributor) { distributor }
      allow(controller).to receive(:current_order_cycle) { order_cycle }
      allow(controller).to receive(:current_order) { order }
      allow(order).to receive(:update) { true }
      allow(order).to receive(:state) { "payment" }
    end

    describe "paypal redirect" do
      let(:payment_method) { create(:payment_method, type: "Spree::Gateway::PayPalExpress") }
      let(:paypal_redirect) { instance_double(Checkout::PaypalRedirect) }

      it "should call Paypal redirect and redirect if a path is provided" do
        expect(Checkout::PaypalRedirect).to receive(:new).and_return(paypal_redirect)
        expect(paypal_redirect).to receive(:path).and_return("test_path")

        spree_post :update, order: { payments_attributes: [{ payment_method_id: payment_method.id }] }

        expect(response.body).to eq({ path: "test_path" }.to_json)
      end
    end

    describe "stripe redirect" do
      let(:payment_method) { create(:payment_method, type: "Spree::Gateway::StripeSCA") }
      let(:stripe_redirect) { instance_double(Checkout::StripeRedirect) }

      it "should call Stripe redirect and redirect if a path is provided" do
        expect(Checkout::StripeRedirect).to receive(:new).and_return(stripe_redirect)
        expect(stripe_redirect).to receive(:path).and_return("test_path")

        spree_post :update, order: { payments_attributes: [{ payment_method_id: payment_method.id }] }

        expect(response.body).to eq({ path: "test_path" }.to_json)
      end
    end
  end

  describe "#action_failed" do
    let(:restart_checkout) { instance_double(OrderCheckoutRestart, call: true) }

    before do
      controller.instance_variable_set(:@order, order)
      allow(OrderCheckoutRestart).to receive(:new) { restart_checkout }
      allow(controller).to receive(:current_order) { order }
    end

    it "set shipping_address_from_distributor and restarts the checkout" do
      expect(order.updater).to receive(:shipping_address_from_distributor)
      expect(restart_checkout).to receive(:call)
      expect(controller).to receive(:respond_to)

      controller.send(:action_failed)
    end
  end
end

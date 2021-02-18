# frozen_string_literal: true

require 'spec_helper'
require 'open_food_network/user_balance_calculator'

module Admin
  describe CustomersController, type: :controller do
    include AuthenticationHelper

    describe "index" do
      let(:enterprise) { create(:distributor_enterprise) }
      let(:another_enterprise) { create(:distributor_enterprise) }

      context "html" do
        before do
          allow(controller).to receive(:spree_current_user) { enterprise.owner }
        end

        it "returns an empty @collection" do
          get :index, format: :html
          expect(assigns(:collection)).to eq []
        end
      end

      context "json" do
        let!(:customer) { create(:customer, enterprise: enterprise) }

        context "where I manage the enterprise" do
          before do
            allow(controller).to receive(:spree_current_user) { enterprise.owner }
          end

          context "and enterprise_id is given in params" do
            let(:params) { { format: :json, enterprise_id: enterprise.id } }

            it "scopes @collection to customers of that enterprise" do
              get :index, params
              expect(assigns(:collection)).to eq [customer]
            end

            it "serializes the data" do
              expect(ActiveModel::ArraySerializer).to receive(:new)
              get :index, params
            end

            context 'when the customer_balance feature is enabled' do
              let(:customers_with_balance) { instance_double(CustomersWithBalance) }

              before do
                allow(OpenFoodNetwork::FeatureToggle)
                  .to receive(:enabled?).with(:customer_balance, enterprise.owner) { true }
              end

              it 'calls CustomersWithBalance' do
                allow(CustomersWithBalance)
                  .to receive(:new).with(enterprise) { customers_with_balance }

                expect(customers_with_balance).to receive(:query) { Customer.none }

                get :index, params
              end

              it 'serializes using CustomerWithBalanceSerializer' do
                expect(Api::Admin::CustomerWithBalanceSerializer).to receive(:new)

                get :index, params
              end
            end

            context 'when the customer_balance feature is not enabled' do
              let(:calculator) do
                instance_double(OpenFoodNetwork::UserBalanceCalculator, balance: 0)
              end

              it 'calls Customer.of' do
                expect(Customer).to receive(:of).twice.with(enterprise) { Customer.none }

                get :index, params
              end

              it 'serializes calling the UserBalanceCalculator' do
                expect(OpenFoodNetwork::UserBalanceCalculator)
                  .to receive(:new).with(customer.email, customer.enterprise) { calculator }

                get :index, params
              end
            end

            context 'when the customer has no orders' do
              it 'includes the customer balance in the response' do
                get :index, params
                expect(json_response.first["balance"]).to eq("$0.00")
              end
            end

            context 'when the customer has complete orders' do
              let(:order) { create(:order, customer: customer, state: 'complete') }
              let!(:line_item) { create(:line_item, order: order, price: 10.0) }

              before do
                allow(OpenFoodNetwork::FeatureToggle)
                  .to receive(:enabled?).with(:customer_balance, enterprise.owner) { true }
              end

              it 'includes the customer balance in the response' do
                get :index, params
                expect(json_response.first["balance"]).to eq("$-10.00")
              end
            end

            context 'when the customer has canceled orders' do
              let(:order) { create(:order, customer: customer) }
              let!(:line_item) { create(:line_item, order: order, price: 10.0) }
              let!(:payment) { create(:payment, order: order, amount: order.total) }

              before do
                allow(OpenFoodNetwork::FeatureToggle)
                  .to receive(:enabled?).with(:customer_balance, enterprise.owner) { true }

                allow_any_instance_of(Spree::Payment).to receive(:completed?).and_return(true)
                order.process_payments!

                order.update_attribute(:state, 'canceled')
              end

              it 'includes the customer balance in the response' do
                get :index, params
                expect(json_response.first["balance"]).to eq("$10.00")
              end
            end

            context 'when the customer has cart orders' do
              let(:order) { create(:order, customer: customer, state: 'cart') }
              let!(:line_item) { create(:line_item, order: order, price: 10.0) }

              it 'includes the customer balance in the response' do
                get :index, params
                expect(json_response.first["balance"]).to eq("$0.00")
              end
            end

            context 'when the customer has an order with a void payment' do
              let(:order) { create(:order, customer: customer, state: 'complete') }
              let!(:line_item) { create(:line_item, order: order, price: 10.0) }
              let!(:payment) { create(:payment, order: order, amount: order.total) }

              before do
                allow(OpenFoodNetwork::FeatureToggle)
                  .to receive(:enabled?).with(:customer_balance, enterprise.owner) { true }

                allow_any_instance_of(Spree::Payment).to receive(:completed?).and_return(true)
                order.process_payments!

                payment.void_transaction!
              end

              it 'includes the customer balance in the response' do
                expect(order.payment_total).to eq(0)
                get :index, params
                expect(json_response.first["balance"]).to eq('$-10.00')
              end
            end
          end

          context "and enterprise_id is not given in params" do
            it "returns an empty collection" do
              get :index, format: :json
              expect(assigns(:collection)).to eq []
            end
          end
        end

        context "and I do not manage the enterprise" do
          before do
            allow(controller).to receive(:spree_current_user) { another_enterprise.owner }
          end

          it "returns an empty collection" do
            get :index, format: :json
            expect(assigns(:collection)).to eq []
          end
        end
      end
    end

    describe "update" do
      let(:enterprise) { create(:distributor_enterprise) }
      let(:another_enterprise) { create(:distributor_enterprise) }

      context "json" do
        let!(:customer) { create(:customer, enterprise: enterprise) }

        context "where I manage the customer's enterprise" do
          render_views

          before do
            allow(controller).to receive(:spree_current_user) { enterprise.owner }
          end

          it "allows me to update the customer" do
            spree_put :update, format: :json, id: customer.id, customer: { email: 'new.email@gmail.com' }
            expect(JSON.parse(response.body)["id"]).to eq customer.id
            expect(assigns(:customer)).to eq customer
            expect(customer.reload.email).to eq 'new.email@gmail.com'
          end
        end

        context "where I don't manage the customer's enterprise" do
          before do
            allow(controller).to receive(:spree_current_user) { another_enterprise.owner }
          end

          it "prevents me from updating the customer" do
            spree_put :update, format: :json, id: customer.id, customer: { email: 'new.email@gmail.com' }
            expect(response).to redirect_to unauthorized_path
            expect(assigns(:customer)).to eq nil
            expect(customer.email).to_not eq 'new.email@gmail.com'
          end
        end
      end
    end

    describe "create" do
      let(:enterprise) { create(:distributor_enterprise) }
      let(:another_enterprise) { create(:distributor_enterprise) }

      def create_customer(enterprise)
        spree_put :create, format: :json, customer: { email: 'new@example.com', enterprise_id: enterprise.id }
      end

      context "json" do
        context "where I manage the customer's enterprise" do
          before do
            allow(controller).to receive(:spree_current_user) { enterprise.owner }
          end

          it "allows me to create the customer" do
            expect { create_customer enterprise }.to change(Customer, :count).by(1)
          end
        end

        context "where I don't manage the customer's enterprise" do
          before do
            allow(controller).to receive(:spree_current_user) { another_enterprise.owner }
          end

          it "prevents me from creating the customer" do
            expect { create_customer enterprise }.to change(Customer, :count).by(0)
          end
        end

        context "where I am the admin user" do
          before do
            allow(controller).to receive(:spree_current_user) { create(:admin_user) }
          end

          it "allows admins to create the customer" do
            expect { create_customer enterprise }.to change(Customer, :count).by(1)
          end
        end
      end
    end

    describe "show" do
      let(:enterprise) { create(:distributor_enterprise) }
      let(:another_enterprise) { create(:distributor_enterprise) }

      context "json" do
        let!(:customer) { create(:customer, enterprise: enterprise) }

        context "where I manage the customer's enterprise" do
          render_views

          before do
            allow(controller).to receive(:spree_current_user) { enterprise.owner }
          end

          it "renders the customer as json" do
            get :show, format: :json, id: customer.id
            expect(JSON.parse(response.body)["id"]).to eq customer.id
          end
        end

        context "where I don't manage the customer's enterprise" do
          before do
            allow(controller).to receive(:spree_current_user) { another_enterprise.owner }
          end

          it "prevents me from updating the customer" do
            get :show, format: :json, id: customer.id
            expect(response).to redirect_to unauthorized_path
          end
        end
      end
    end
  end
end

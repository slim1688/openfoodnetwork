# frozen_string_literal: true

require 'spec_helper'

describe Api::EnterprisesController, type: :controller do
  render_views

  let(:enterprise) { create(:distributor_enterprise) }

  context "as an enterprise owner" do
    let(:enterprise_owner) { create(:user) }
    let!(:enterprise) { create(:distributor_enterprise, owner: enterprise_owner) }

    before do
      allow(controller).to receive(:spree_current_user) { enterprise_owner }
    end

    describe "creating an enterprise" do
      let(:australia) { Spree::Country.find_by(name: 'Australia') }
      let(:new_enterprise_params) do
        {
          name: 'name', contact_name: 'Sheila', address_attributes: {
            address1: '123 Abc Street',
            city: 'Northcote',
            zipcode: '3070',
            state_id: australia.states.first.id,
            country_id: australia.id
          }
        }
      end

      it "creates as sells=any when it is not a producer" do
        api_post :create, { enterprise: new_enterprise_params }
        expect(response).to be_success

        enterprise = Enterprise.last
        expect(enterprise.sells).to eq('any')
      end

      it "saves all user ids submitted" do
        manager1 = create(:user)
        manager2 = create(:user)
        api_post :create, {
          enterprise: new_enterprise_params.
            merge({ user_ids: [enterprise_owner.id, manager1.id, manager2.id] })
        }
        expect(response).to be_success

        enterprise = Enterprise.last
        expect(enterprise.user_ids).to match_array([enterprise_owner.id, manager1.id, manager2.id])
      end
    end
  end

  context "as an enterprise manager" do
    let(:enterprise_manager) { create(:user) }

    before do
      enterprise_manager.enterprise_roles.build(enterprise: enterprise).save
      allow(controller).to receive(:spree_current_user) { enterprise_manager }
    end

    describe "submitting a valid image" do
      before do
        allow(Enterprise)
          .to receive(:find_by).with({ permalink: enterprise.id.to_s }) { enterprise }
        allow(enterprise).to receive(:update).and_return(true)
      end

      it "I can update enterprise image" do
        api_post :update_image, logo: 'a logo', id: enterprise.id
        expect(response).to be_success
      end
    end
  end

  context "as an non-managing user" do
    let(:non_managing_user) { create(:user) }

    before do
      allow(Enterprise)
        .to receive(:find_by).with({ permalink: enterprise.id.to_s }) { enterprise }
      allow(controller).to receive(:spree_current_user) { non_managing_user }
    end

    describe "submitting a valid image" do
      it "I can't update enterprise image" do
        api_post :update_image, logo: 'a logo', id: enterprise.id
        assert_unauthorized!
      end
    end
  end
end

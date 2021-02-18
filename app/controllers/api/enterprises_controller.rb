module Api
  class EnterprisesController < Api::BaseController
    before_action :override_owner, only: [:create, :update]
    before_action :check_type, only: :update
    before_action :override_sells, only: [:create, :update]
    before_action :override_visible, only: [:create, :update]
    respond_to :json

    def create
      authorize! :create, Enterprise

      # params[:user_ids] breaks the enterprise creation
      # We remove them from params and save them after creating the enterprise
      user_ids = params[:enterprise].delete(:user_ids)
      @enterprise = Enterprise.new(enterprise_params)
      if @enterprise.save
        @enterprise.user_ids = user_ids
        render json: @enterprise.id, status: :created
      else
        invalid_resource!(@enterprise)
      end
    end

    def update
      @enterprise = Enterprise.find_by(permalink: params[:id]) || Enterprise.find(params[:id])
      authorize! :update, @enterprise

      if @enterprise.update(enterprise_params)
        render json: @enterprise.id, status: :ok
      else
        invalid_resource!(@enterprise)
      end
    end

    def update_image
      @enterprise = Enterprise.find_by(permalink: params[:id]) || Enterprise.find(params[:id])
      authorize! :update, @enterprise

      if params[:logo] && @enterprise.update( logo: params[:logo] )
        render text: @enterprise.logo.url(:medium), status: :ok
      elsif params[:promo] && @enterprise.update( promo_image: params[:promo] )
        render text: @enterprise.promo_image.url(:medium), status: :ok
      else
        invalid_resource!(@enterprise)
      end
    end

    private

    def override_owner
      params[:enterprise][:owner_id] = current_api_user.id
    end

    def check_type
      params[:enterprise].delete :type unless current_api_user.admin?
    end

    def override_sells
      has_hub = current_api_user.owned_enterprises.is_hub.any?
      new_enterprise_is_producer = !!params[:enterprise][:is_primary_producer]

      params[:enterprise][:sells] = if has_hub && !new_enterprise_is_producer
                                      'any'
                                    else
                                      'unspecified'
                                    end
    end

    def override_visible
      params[:enterprise][:visible] = false
    end

    def enterprise_params
      PermittedAttributes::Enterprise.new(params).call
    end
  end
end

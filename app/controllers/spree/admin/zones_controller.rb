module Spree
  module Admin
    class ZonesController < ::Admin::ResourceController
      before_action :load_data, except: [:index]

      def new
        @zone.zone_members.build
      end

      protected

      def collection
        params[:q] ||= {}
        params[:q][:s] ||= "ascend_by_name"
        @search = super.ransack(params[:q])
        @zones = @search.result.page(params[:page]).per(Spree::Config[:orders_per_page])
      end

      def load_data
        @countries = Country.order(:name)
        @states = State.order(:name)
        @zones = Zone.order(:name)
      end

      def permitted_resource_params
        params.require(:zone).permit(
          :name, :description, :default_tax, :kind,
          zone_members_attributes: [:id, :zoneable_id, :zoneable_type, :_destroy]
        )
      end

      def location_after_save
        edit_object_url(@zone)
      end
    end
  end
end

# frozen_string_literal: true

module Spree
  module Core
    # This module exists to reduce duplication in S3 settings between
    # the Image and Taxon models in Spree
    module S3Support
      extend ActiveSupport::Concern

      included do
        def self.supports_s3(field)
          # Load user defined paperclip settings
          config = Spree::Config
          return unless config[:use_s3]

          s3_creds = { access_key_id: config[:s3_access_key],
                       secret_access_key: config[:s3_secret],
                       bucket: config[:s3_bucket] }
          attachment_definitions[field][:storage] = :s3
          attachment_definitions[field][:s3_credentials] = s3_creds
          attachment_definitions[field][:s3_headers] = ActiveSupport::JSON.
            decode(config[:s3_headers])
          attachment_definitions[field][:bucket] = config[:s3_bucket]
          if config[:s3_protocol].present?
            attachment_definitions[field][:s3_protocol] = config[:s3_protocol].downcase
          end

          return if config[:s3_host_alias].blank?

          attachment_definitions[field][:s3_host_alias] = config[:s3_host_alias]
        end
      end
    end
  end
end

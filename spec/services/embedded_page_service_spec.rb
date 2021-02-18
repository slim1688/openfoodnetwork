# frozen_string_literal: true

require 'spec_helper'

describe EmbeddedPageService do
  let(:enterprise_slug) { 'test-enterprise' }
  let(:params) { { controller: 'enterprises', action: 'shop', id: enterprise_slug, embedded_shopfront: true } }
  let(:session) { {} }
  let(:request) { ActionController::TestRequest.new('HTTP_HOST' => 'ofn-instance.com', 'HTTP_REFERER' => 'https://embedding-enterprise.com') }
  let(:response) { ActionController::TestResponse.new(200, 'X-Frame-Options' => 'DENY', 'Content-Security-Policy' => "frame-ancestors 'none'") }
  let(:service) { EmbeddedPageService.new(params, session, request, response) }

  before do
    Spree::Config.set(
      enable_embedded_shopfronts: true,
      embedded_shopfronts_whitelist: 'embedding-enterprise.com example.com'
    )
  end

  describe "processing embedded page requests" do
    context "when the request's referer is in the whitelist" do
      before { service.embed! }

      it "sets the response headers to enables embedding requests from the embedding site" do
        expect(response.headers).to_not include 'X-Frame-Options' => 'DENY'
        expect(response.headers).to include 'Content-Security-Policy' => "frame-ancestors 'self' embedding-enterprise.com"
      end

      it "sets session variables" do
        expect(session[:embedded_shopfront]).to eq true
        expect(session[:embedding_domain]).to eq 'embedding-enterprise.com'
        expect(session[:shopfront_redirect]).to eq '/' + enterprise_slug + '/shop?embedded_shopfront=true'
      end

      it "publicly reports that embedded layout should be used" do
        expect(service.use_embedded_layout?).to be true
      end
    end

    context "when embedding is enabled for a different site in the current session" do
      before do
        session[:embedding_domain] = 'another-enterprise.com'
        session[:shopfront_redirect] = '/another-enterprise/shop?embedded_shopfront=true'
        service.embed!
      end

      it "resets the session variables for the new request" do
        expect(session[:embedded_shopfront]).to eq true
        expect(session[:embedding_domain]).to eq 'embedding-enterprise.com'
        expect(session[:shopfront_redirect]).to eq '/' + enterprise_slug + '/shop?embedded_shopfront=true'
      end
    end

    context "when the request's referer is not in the whitelist" do
      before do
        Spree::Config.set(embedded_shopfronts_whitelist: 'example.com')
        service.embed!
      end

      it "does not enable embedding" do
        expect(response.headers['X-Frame-Options']).to eq 'DENY'
      end
    end

    context "when the request's referer is malformed" do
      let(:request) { ActionController::TestRequest.new('HTTP_HOST' => 'ofn-instance.com', 'HTTP_REFERER' => 'hello') }
      before do
        service.embed!
      end

      it "returns a 200 status" do
        expect(response.status).to eq 200
      end
    end
  end
end

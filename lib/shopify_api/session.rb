require 'openssl'
require 'rack'

module ShopifyAPI

  class ValidationException < StandardError
  end

  class Session
    cattr_accessor :api_key, :secret, :myshopify_domain
    self.myshopify_domain = 'myshopify.com'

    attr_accessor :url, :token, :api_version, :name, :extra

    class << self

      def setup(params)
        params.each { |k,value| public_send("#{k}=", value) }
      end

      def temp(domain, token, api_version, &block)
        session = new(domain, token, api_version)
        original_site = ShopifyAPI::Base.site.to_s
        original_token = ShopifyAPI::Base.headers['X-Shopify-Access-Token']
        original_version = ShopifyAPI::Base.api_version
        original_session = new(original_site, original_token, original_version)

        begin
          ShopifyAPI::Base.activate_session(session)
          yield
        ensure
          ShopifyAPI::Base.activate_session(original_session)
        end
      end

      def prepare_url(url)
        return nil if url.blank?
        # remove http:// or https://
        url = url.strip.gsub(/\Ahttps?:\/\//, '')
        # extract host, removing any username, password or path
        shop = URI.parse("https://#{url}").host
        # extract subdomain of .myshopify.com
        if idx = shop.index(".")
          shop = shop.slice(0, idx)
        end
        return nil if shop.empty?
        "#{shop}.#{myshopify_domain}"
      rescue URI::InvalidURIError
        nil
      end

      def validate_signature(params)
        params = (params.respond_to?(:to_unsafe_hash) ? params.to_unsafe_hash : params).with_indifferent_access
        return false unless signature = params[:hmac]

        calculated_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new(), secret, encoded_params_for_signature(params))

        Rack::Utils.secure_compare(calculated_signature, signature)
      end

      private

      def encoded_params_for_signature(params)
        params = params.except(:signature, :hmac, :action, :controller)
        params.map{|k,v| "#{URI.escape(k.to_s, '&=%')}=#{URI.escape(v.to_s, '&%')}"}.sort.join('&')
      end
    end

    def initialize(url, token, api_version, extra = {})
      self.url = self.class.prepare_url(url)
      self.api_version = api_version
      self.token = token
      self.extra = extra
    end

    def create_permission_url(scope, redirect_uri = nil)
      params = {:client_id => api_key, :scope => scope.join(',')}
      params[:redirect_uri] = redirect_uri if redirect_uri
      construct_oauth_url("authorize", params)
    end

    def request_token(params)
      return token if token

      unless self.class.validate_signature(params) && params[:timestamp].to_i > 24.hours.ago.utc.to_i
        raise ShopifyAPI::ValidationException, "Invalid Signature: Possible malicious login"
      end

      response = access_token_request(params['code'])
      if response.code == "200"
        self.extra = JSON.parse(response.body)
        self.token = extra.delete('access_token')

        if expires_in = extra.delete('expires_in')
          extra['expires_at'] = Time.now.utc.to_i + expires_in
        end
        token
      else
        raise RuntimeError, response.msg
      end
    end

    def shop
      Shop.current
    end

    def site
      "https://#{url}"
    end

    def api_version=(version)
      @api_version = version.nil? ? nil : ApiVersion.coerce_to_version(version)
    end

    def valid?
      url.present? && token.present? && api_version.present?
    end

    def expires_in
      return unless expires_at.present?
      [0, expires_at.to_i - Time.now.utc.to_i].max
    end

    def expires_at
      return unless extra.present?
      @expires_at ||= Time.at(extra['expires_at']).utc
    end

    def expired?
      return false if expires_in.nil?
      expires_in <= 0
    end

    private

    def parameterize(params)
      URI.escape(params.collect { |k, v| "#{k}=#{v}" }.join('&'))
    end

    def access_token_request(code)
      uri = URI.parse(construct_oauth_url('access_token'))
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data('client_id' => api_key, 'client_secret' => secret, 'code' => code)
      https.request(request)
    end

    def construct_oauth_url(path, query_params = {})
      query_string = "?#{parameterize(query_params)}" unless query_params.empty?
      "https://#{url}/admin/oauth/#{path}#{query_string}"
    end
  end
end

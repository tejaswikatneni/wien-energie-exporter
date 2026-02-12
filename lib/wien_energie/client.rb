# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'
require 'json'

module WienEnergie
  # HTTP client responsible for fetching raw POIs from
  # Wien Energie's AJAX endpoint.
  #
  # This client does not perform filtering or transformation.
  # It only retrieves the raw JSON response.
  class Client
    DEFAULT_URL = 'https://www.wienenergie.at/wp-admin/admin-ajax.php'

    DEFAULT_BBOX = {
      'northLat' => '48.33320022893203',
      'eastLng' => '16.583913525390617',
      'southLat' => '48.08289392875922',
      'westLng' => '16.163686474609367'
    }.freeze

    def initialize(ajax_nonce:, url: DEFAULT_URL)
      @ajax_nonce = ajax_nonce
      @conn = Faraday.new(url: url) do |f|
        f.request :url_encoded
        f.request :retry, max: 3, interval: 0.2, backoff_factor: 2
        f.adapter Faraday.default_adapter
      end
    end

    def fetch_pois(bbox: DEFAULT_BBOX)
      resp = @conn.post do |req|
        apply_headers(req)
        req.body = build_body(bbox)
      end

      validate_response!(resp)
      parse_json(resp)
    end

    private

    def apply_headers(req)
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8'
      req.headers['X-Requested-With'] = 'XMLHttpRequest'
      req.headers['Accept'] = 'application/json, text/javascript, */*; q=0.01'
      req.headers['User-Agent'] = browser_user_agent
      req.headers['Origin'] = 'https://www.wienenergie.at'
      req.headers['Referer'] = 'https://www.wienenergie.at/'
    end

    def build_body(bbox)
      {
        'action' => 'we_theme_tanke_fetch_poi',
        '_ajax_nonce' => @ajax_nonce
      }.merge(bbox)
    end

    def validate_response!(resp)
      return if resp.success?

      raise "HTTP #{resp.status}\n#{resp.body.to_s[0, 500]}"
    end

    def parse_json(resp)
      json = JSON.parse(resp.body)
      raise 'Unexpected response (success != true)' unless json['success'] == true

      json
    end

    def browser_user_agent
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 ' \
        '(KHTML, like Gecko) Chrome/120.0 Safari/537.36'
    end
  end
end

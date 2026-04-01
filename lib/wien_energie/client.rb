# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'
require 'faraday/multipart'
require 'json'

module WienEnergie
  class Client
    DEFAULT_URL = 'https://www.wienenergie.at/api/wordpress-ajax/'
    DEFAULT_PAGE_URL = 'https://www.wienenergie.at/privat/produkte/e-mobilitaet/e-ladestation-finder/'

    DEFAULT_BBOX = {
      'northLat' => '48.33320022893203',
      'eastLng' => '16.583913525390617',
      'southLat' => '48.08289392875922',
      'westLng' => '16.163686474609367'
    }.freeze

    def initialize(url: DEFAULT_URL, page_url: DEFAULT_PAGE_URL)
      @url = url
      @page_url = page_url
    end

    def fetch_pois(bbox: DEFAULT_BBOX)
      nonce_config = fetch_nonce_config
      resp = build_connection(url: nonce_config[:ajax_url]).post do |req|
        apply_headers(req)
        req.body = build_body(bbox, nonce_config[:ajax_nonce])
      end

      validate_response!(resp)
      parse_json(resp)
    end

    private

    def fetch_nonce_config
      resp = build_connection(url: @page_url).get do |req|
        req.headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
        req.headers['User-Agent'] = browser_user_agent
      end
      validate_response!(resp)

      extract_nonce_config(resp.body)
    end

    def extract_nonce_config(html)
      # The page can contain either raw JSON (`"acf":{...}`) or JSON escaped inside a string (`\"acf\":{...}`).
      if (m = html.match(/"acf":\{.*?"ajaxurl":"([^"]+)".*?"we_theme_tanke_fetch_poi":"([^"]+)"/m))
        return { ajax_url: m[1], ajax_nonce: m[2] }
      end

      if (m = html.match(/\\"acf\\":\{.*?\\"ajaxurl\\":\\"([^\\"]+)\\".*?\\"we_theme_tanke_fetch_poi\\":\\"([^\\"]+)\\"/m))
        return { ajax_url: m[1], ajax_nonce: m[2] }
      end

      marker = '"acf":'
      marker_idx = html.index(marker)
      raise 'Unable to extract nonce config: "acf" marker missing' unless marker_idx

      obj_start = html.index('{', marker_idx + marker.length)
      raise 'Unable to extract nonce config: ACF object start missing' unless obj_start

      obj_end = find_balanced_json_end(html, obj_start)
      raise 'Unable to extract nonce config: ACF object end missing' unless obj_end

      acf = JSON.parse(html[obj_start..obj_end])
      ajax_url = acf['ajaxurl']
      ajax_nonce = acf.dig('nonces', 'we_theme_tanke_fetch_poi')

      raise 'Missing nonce config key: ajaxurl' if ajax_url.to_s.empty?
      raise 'Missing nonce config key: nonces.we_theme_tanke_fetch_poi' if ajax_nonce.to_s.empty?

      { ajax_url: ajax_url, ajax_nonce: ajax_nonce }
    rescue JSON::ParserError => e
      raise "Unable to parse nonce config JSON: #{e.message}"
    end

    def find_balanced_json_end(text, start_idx)
      depth = 0
      in_string = false
      escaped = false

      (start_idx...text.length).each do |idx|
        ch = text[idx]

        if escaped
          escaped = false
          next
        end

        if in_string
          if ch == '\\'
            escaped = true
          elsif ch == '"'
            in_string = false
          end
          next
        end

        if ch == '"'
          in_string = true
        elsif ch == '{'
          depth += 1
        elsif ch == '}'
          depth -= 1
          return idx if depth.zero?
        end
      end

      nil
    end

    def apply_headers(req)
      req.headers['Accept'] = 'application/json, text/plain, */*'
      req.headers['X-Requested-With'] = 'XMLHttpRequest'
      req.headers['User-Agent'] = browser_user_agent
      req.headers['Origin'] = 'https://www.wienenergie.at'
      req.headers['Referer'] = 'https://www.wienenergie.at/privat/produkte/e-mobilitaet/e-ladestation-finder/'
    end

    def build_body(bbox, ajax_nonce)
      {
        'action' => 'we_theme_tanke_fetch_poi',
        '_ajax_nonce' => ajax_nonce
      }.merge(bbox)
    end

    def build_connection(url:)
      Faraday.new(url: url) do |f|
        f.request :multipart
        f.request :url_encoded
        f.request :retry, max: 3, interval: 0.2, backoff_factor: 2
        f.adapter Faraday.default_adapter
      end
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
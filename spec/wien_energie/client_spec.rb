# frozen_string_literal: true

require_relative '../../lib/wien_energie/client'

RSpec.describe WienEnergie::Client do
  it 'posts to admin-ajax and parses JSON response' do
    body = File.read('spec/fixtures/pois.json')

    stub_request(:post, WienEnergie::Client::DEFAULT_URL)
      .with do |req|
        req.body.include?('action=we_theme_tanke_fetch_poi') &&
          req.body.include?('_ajax_nonce=testnonce') &&
          req.body.include?('northLat=') &&
          req.body.include?('eastLng=')
      end
      .to_return(status: 200, body: body, headers: { 'Content-Type' => 'application/json' })

    client = described_class.new(ajax_nonce: 'testnonce')
    json = client.fetch_pois

    expect(json['success']).to be(true)
    expect(json['data']).to be_a(Array)
  end

  it 'raises on non-200 response' do
    stub_request(:post, WienEnergie::Client::DEFAULT_URL)
      .to_return(status: 403, body: 'Forbidden')

    client = described_class.new(ajax_nonce: 'testnonce')
    expect { client.fetch_pois }.to raise_error(RuntimeError, /HTTP 403/)
  end
end

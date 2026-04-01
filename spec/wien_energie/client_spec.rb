# frozen_string_literal: true

require_relative '../../lib/wien_energie/client'

RSpec.describe WienEnergie::Client do
  let(:page_url) { WienEnergie::Client::DEFAULT_PAGE_URL }
  let(:ajax_url) { 'https://cms-backend.wienenergie.at/wp-admin/admin-ajax.php' }
  let(:page_html) do
    <<~HTML
      <html>
        <body>
          <script>
            window.__PAGE_DATA__ = {"acf":{"ajaxurl":"#{ajax_url}","nonces":{"we_theme_tanke_fetch_poi":"testnonce"}}};
          </script>
        </body>
      </html>
    HTML
  end

  it 'posts to admin-ajax and parses JSON response' do
    body = File.read('spec/fixtures/pois.json')

    stub_request(:get, page_url)
      .to_return(status: 200, body: page_html, headers: { 'Content-Type' => 'text/html' })

    stub_request(:post, ajax_url)
      .with do |req|
        req.body.include?('action=we_theme_tanke_fetch_poi') &&
          req.body.include?('_ajax_nonce=testnonce') &&
          req.body.include?('northLat=') &&
          req.body.include?('eastLng=')
      end
      .to_return(status: 200, body: body, headers: { 'Content-Type' => 'application/json' })

    client = described_class.new
    json = client.fetch_pois

    expect(json['success']).to be(true)
    expect(json['data']).to be_a(Array)
  end

  it 'raises on non-200 response' do
    stub_request(:get, page_url)
      .to_return(status: 200, body: page_html, headers: { 'Content-Type' => 'text/html' })

    stub_request(:post, ajax_url)
      .to_return(status: 403, body: 'Forbidden')

    client = described_class.new
    expect { client.fetch_pois }.to raise_error(RuntimeError, /HTTP 403/)
  end

  it 'raises when nonce payload cannot be extracted' do
    stub_request(:get, page_url)
      .to_return(status: 200, body: '<html><body>No ACF JSON here</body></html>', headers: { 'Content-Type' => 'text/html' })

    client = described_class.new
    expect { client.fetch_pois }.to raise_error(RuntimeError, /Unable to extract nonce config/)
  end
end

# frozen_string_literal: true

require 'json'
require_relative '../../lib/wien_energie/transformer'

RSpec.describe WienEnergie::Transformer do
  def load_fixture
    JSON.parse(File.read('spec/fixtures/pois.json'))
  end

  it 'filters only VIE/VNA stations and emits one row per charger' do
    rows = described_class.new(load_fixture).rows

    # Only VIE/VNA should be present. Fixture includes 1 VIE station with 6 chargers.
    expect(rows.size).to eq(6)
    expect(rows.map { |r| r['OperatorID'] }.uniq).to eq(['VIE'])
  end

  it 'normalizes connector types and power, including other for schuko' do
    rows = described_class.new(load_fixture).rows

    wipark_rows = rows.select { |r| r['Name'].include?('Schenk-Danzinger') }
    expect(wipark_rows.size).to eq(6)

    type2 = wipark_rows.count { |r| r['Connector'] == 'type2' && r['Power'] == 11 }
    other = wipark_rows.count { |r| r['Connector'] == 'other' && r['Power'] == 3 }

    expect(type2).to eq(4)
    expect(other).to eq(2)
  end

  it "formats the address as 'Street, ZIP City' and parses coordinates as floats" do
    rows = described_class.new(load_fixture).rows
    row = rows.first

    expect(row['Address']).to eq('Schenk-Danzinger-Gasse 4-6, 1220 Wien')
    expect(row['Longitude']).to be_within(0.000001).of(16.500918)
    expect(row['Latitude']).to be_within(0.000001).of(48.224867)
  end
end

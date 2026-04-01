# frozen_string_literal: true

module WienEnergie
  # Transforms raw POI JSON response into flat CSV rows.
  #
  # - Filters to Wien Energie stations by operatorEvseId (VIE/VNA)
  # - Emits one row per charger (connector instance)
  # - Normalizes connector types into: type2, ccs, chademo, other
  class Transformer
    ALLOWED_OPERATOR_IDS = %w[VIE VNA].freeze

    def initialize(raw_json)
      @raw = raw_json
    end

    def rows
      seen_charger_ids = {}
      wien_energie_stations.flat_map do |station|
        build_rows_for_station(station, seen_charger_ids)
      end
    end

    private

    def wien_energie_stations
      stations = @raw.fetch('data', [])
      stations.select { |station| ALLOWED_OPERATOR_IDS.include?(station['operatorEvseId'].to_s) }
    end

    def build_rows_for_station(station, seen_charger_ids)
      base = base_row(station)
      chargers = station.fetch('chargers', [])
      chargers.each_with_object([]) do |charger, arr|

        next if duplicate_charger?(charger, seen_charger_ids)

        arr << base.merge(
          'Connector' => normalize_connector(connector_key(charger)),
          'Power' => power_kw(charger)
        )
      end
    end

    def base_row(station)
      {
        'Name' => station['name'].to_s,
        'Address' => format_address(station),
        'Longitude' => to_float(station.dig('coordinates', 'lng') || station['lng']),
        'Latitude' => to_float(station.dig('coordinates', 'lat') || station['lat']),
        'OperatorID' => station['operatorEvseId'].to_s
      }
    end

    def duplicate_charger?(charger, seen_charger_ids)
      charger_evse_id = charger['evseId'].to_s
      return false if charger_evse_id.empty?
      return true if seen_charger_ids[charger_evse_id]

      seen_charger_ids[charger_evse_id] = true
      false
    end

    def connector_key(charger)
      charger['plugType'] || charger.dig('connectorTypes', 0, 'standard')
    end

    def power_kw(charger)
      value = to_float(charger['maxChargingPowerInKw'])
      value&.round
    end

    def format_address(station)
      street = station['address'].to_s.strip
      house  = station['houseNumber'].to_s.strip
      zip    = station['postcode'].to_s.strip
      city   = station['city'].to_s.strip

      street_part = [street, house].reject(&:empty?).join(' ')
      "#{street_part}, #{zip} #{city}".strip
    end

    def normalize_connector(raw)
      key = raw.to_s.upcase
      return 'type2' if key == 'IEC_62196_T2'
      return 'ccs' if key == 'IEC_62196_T2_COMBO'
      return 'chademo' if key == 'CHADEMO'

      'other' # e.g. DOMESTIC_F (Schuko) and everything else
    end

    def to_float(value)
      return nil if value.nil?

      Float(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end

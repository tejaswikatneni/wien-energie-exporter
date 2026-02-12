# frozen_string_literal: true

require 'csv'

module WienEnergie
  # Writes normalized station rows into a CSV file in the required format.
  class CsvWriter
    HEADERS = %w[Name Address Longitude Latitude OperatorID Connector Power].freeze

    def self.write(path, rows)
      CSV.open(path, 'w', write_headers: true, headers: HEADERS) do |csv|
        rows.each { |row| csv << HEADERS.map { |h| row[h] } }
      end
    end
  end
end

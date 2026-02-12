# Approach

## Data source
Wien Energie lists charging stations via AJAX endpoint (`admin-ajax.php`) used by their map UI. This endpoint returns structured JSON with a `data` array of POIs, including charging stations from multiple operators.

## Filtering Wien Energie stations
The task requires only Wien Energie stations. These can be identified using the `operatorEvseId` field:
- VIE
- VNA

All other operators are discarded.

## One row per connector
Each station contains a `chargers` array. In observed responses, each entry represents a physical connector/EVSE instance (e.g., multiple Type2 sockets show up as multiple entries). Therefore the exporter emits one CSV row per `chargers[]` element.

## Normalization
- Address: `"<address> <houseNumber>, <postcode> <city>"` (houseNumber omitted when empty)
- Connector mapping:
  - IEC_62196_T2 -> type2
  - IEC_62196_T2_COMBO -> ccs
  - CHADEMO -> chademo
  - everything else (e.g. DOMESTIC_F / Schuko) -> other
- Power: `maxChargingPowerInKw` rounded to integer

## Reliability notes
The AJAX request requires a `_ajax_nonce` which can expire. For this challenge it is passed via envvariable `WE_AJAX_NONCE`.

## Testing
- HTTP calls are mocked using WebMock.
- Transformer is tested using a small fixture JSON response to ensure correct filtering and row expansion.

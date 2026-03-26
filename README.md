# Wien Energie Charging Stations Exporter

This project fetches Wien Energie charging station data from their public website API and exports it into a normalized CSV file.

It demonstrates:

* HTTP integration
* data transformation
* clean architecture
* automated tests
* reproducibility
* production-style tooling

---

## Overview

The Wien Energie website exposes charging station data via a WordPress AJAX endpoint.
This exporter retrieves that dataset, filters Wien Energie stations, and outputs a CSV with one row per connector.

---

## Output Format

The CSV contains the following columns:

| Column     | Description                |
| ---------- | -------------------------- |
| Name       | Station name               |
| Address    | Street + ZIP + City        |
| Longitude  | Float                      |
| Latitude   | Float                      |
| OperatorID | VIE or VNA                 |
| Connector  | type2, ccs, chademo, other |
| Power      | Integer kW                 |

---

## Data Rules Implemented

* Only stations with `operatorEvseId` **VIE or VNA** are included
* One row is generated **per connector**
* Connectors are normalized:

| Raw value          | Output  |
| ------------------ | ------- |
| IEC_62196_T2       | type2   |
| IEC_62196_T2_COMBO | ccs     |
| CHADEMO            | chademo |
| Anything else      | other   |

* Power values are rounded integers
* Duplicate charger IDs are ignored defensively

---

## Installation

```bash
git clone https://github.com/tejaswikatneni/wien-energie-exporter.git
cd wien-energie-exporter
bundle install
```

---

## Usage

The endpoint requires a short-lived `_ajax_nonce`.

### 1. Get nonce from browser

Open browser DevTools → Network → find request to:

```
admin-ajax.php
```

Copy the value of:

```
_ajax_nonce
```

---

### 2. Run exporter

```bash
WE_AJAX_NONCE=YOUR_NONCE bundle exec ruby bin/export_csv
```

Output:

```
output/wien_energie_stations.csv
```

---

## Example Output Size

At time of development:

* ~879 Wien Energie stations
* ~2400+ connector rows

The dataset is live and may change over time.

---

## Running Tests

```bash
bundle exec rspec
```

Tests include:

* HTTP call mocking
* transformer correctness
* connector normalization
* filtering logic

---

## Linting

```bash
bundle exec rubocop
```

---

## Project Structure

```
bin/
  export_csv        # CLI entrypoint

lib/wien_energie/
  client.rb         # HTTP client
  transformer.rb    # data transformation
  csv_writer.rb     # CSV output

spec/
  fixtures/         # mocked API responses
  wien_energie/     # specs

docs/
  approach.md       # design explanation
```

---

## Design Decisions

### Why Faraday instead of Net::HTTP?

Faraday provides:

* middleware support
* retries
* cleaner API
* easier testing

For production integrations this is preferred over raw Net::HTTP.

---

### Why environment variable for nonce?

The nonce is:

* short-lived
* session dependent
* dynamically generated

For this challenge it is supplied via environment variable.

In production the exporter would first fetch the page and extract the nonce automatically.

---

### Why one row per connector?

Each element inside `chargers[]` represents a physical connector instance.
The task explicitly requires one CSV row per connector.

---



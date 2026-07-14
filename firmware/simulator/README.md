# firmware/simulator

Payload simulator standing in for ESP32 firmware before hardware exists (docs/07 Sensor
Data Pipeline). Posts one aggregated telemetry payload every ~10s (the doc's default
transmit interval) to the deployed `telemetry-intake` Edge Function, using the same
`POST /telemetry` contract a real device would (docs/10).

## Setup

```
npm install
cp .env.example .env   # fill in FURFEEL_DEVICE_KEY with the device's plaintext ingest key
```

The ingest key is generated once when a device is provisioned (SHA-256 hashed and stored in
`devices.ingest_key_hash`) — it is never stored in the database in plaintext, so you need the
original value from whoever provisioned the device.

## Usage

```
npm start                              # steady calm-range readings, forever, every 10s
npm start -- --sweep                   # ramp calm -> high over --sweep-ticks, then hold high
npm start -- --sweep --max-ticks=20    # bounded run, useful for smoke tests
npm start -- --interval-ms=1000        # faster loop for local testing
```

All options can also be set via env vars / `.env` (`FURFEEL_FUNCTION_URL`,
`FURFEEL_DEVICE_CODE`, `FURFEEL_DEVICE_KEY`); CLI flags take precedence. Run
`node src/simulate.ts --help` for the full flag list.

`npm run typecheck` runs `tsc --noEmit`. The script itself runs directly via
`node src/simulate.ts` (Node 22+ strips TypeScript types natively) — no build step needed.

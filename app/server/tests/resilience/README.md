# Resilience tests

Opt-in tests that exercise the server under adverse client and network behavior
(clients that stall, stop reading, or disconnect mid-request), and verify it
degrades gracefully and reclaims resources (connections, pooled DB clients,
memory) rather than leaking or crashing.

They drive a running server over real TCP, so they are **excluded from
`npm test`** and run only via `npm run test:resilience`.

Everything here drives the **local server over HTTP only**. Never point it at a
deployed or shared environment.

## Prerequisites

The app server running on `:3001`, pointed at the dev DB. The tests hit the app
directly on localhost, not BrowserSync or any other proxy in front of it.

## Run

```sh
npm run test:resilience
```

## Configuration

Override via env where needed:

| Var | Default | Purpose |
| --- | --- | --- |
| `PORT` | `3001` | the app's localhost port, the same default `app/server.js` uses |
| `DB_POOL_MAX` | `10` | pool size, from `.env.local` |
| `STREAM_IDLE_TIMEOUT` | `10000` | used by `streamIdleTimeout.test.js`; from `.env.local` |
| `RST_ITERATIONS` | `500` | aborted requests `clientDisconnect.test.js` fires |
| `RST_MAX_DELAY_MS` | `50` | upper bound on `clientDisconnect.test.js`'s post-send abort delay |

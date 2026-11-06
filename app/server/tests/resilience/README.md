# Resilience tests

Opt-in tests that exercise the server under adverse client and network behavior
— clients that stall, stop reading, or disconnect mid-request — and verify it
degrades gracefully and reclaims resources (connections, pooled DB clients,
memory) rather than leaking or crashing.

They drive a running server over real TCP, so they are **excluded from
`npm test`** and run only via `npm run test:resilience`.

Everything here drives the **local server over HTTP only** — never point it at a
deployed or shared environment.

## Prerequisites

The server running on `:3001`, pointed at the dev DB.

## Run

```sh
npm run test:resilience
```

## Configuration

Override via env where needed:

| Var | Default | Purpose |
| --- | --- | --- |
| `SERVER_URL` | `http://localhost:3001` | the local server to drive |
| `DB_POOL_MAX` | `10` | pool size, from `.env.local` |
| `STREAM_IDLE_TIMEOUT` | `10000` | used by `streamIdleTimeout.test.js`; from `.env.local` |

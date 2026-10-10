# Doris Learning Environment

This directory contains a minimal single-node Apache Doris learning setup based
on the official Doris quick-start image layout.

- `1 FE`
- `1 BE`

Compose file:

- `docker-compose.doris.yml`

Default host ports:

- FE HTTP: `8030`
- FE MySQL: `9030`
- FE Edit Log: `9010`
- BE HTTP: `8040`
- BE Heartbeat: `9050`

Notes:

- On resource-constrained laptops, `rt-doris-be` may need a retry after FE becomes fully ready.
- The compose file now uses `restart: unless-stopped` so BE can recover from a first-boot timeout automatically.
- If you still need to verify cluster health manually, use `SHOW BACKENDS;` in Doris FE and confirm `Alive = true`.

#!/bin/sh
set -eu

node dist/accounts/migrate.js
exec node dist/server.js

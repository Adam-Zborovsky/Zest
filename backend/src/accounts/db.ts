// Driver-agnostic database handle. Production wires node-postgres (server.ts);
// tests wire PGlite and cast it to this type — the driver differs only in its
// underlying transport, not in the drizzle query-builder surface this code uses.
import type { NodePgDatabase } from 'drizzle-orm/node-postgres';
import * as schema from './schema.js';

export type Schema = typeof schema;
export type Db = NodePgDatabase<Schema>;

export { schema };

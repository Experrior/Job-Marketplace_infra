CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- CONFIGURE REPLICATION
DROP USER IF EXISTS replicator;
CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replicator_password';

SELECT pg_create_physical_replication_slot('replication_slot');

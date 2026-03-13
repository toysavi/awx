-- postgres/init.sql
-- ============================================================
-- PostgreSQL initialization for AWX.
-- Runs once on first container start (when data dir is empty).
-- AWX Django migrations handle all table creation on app start.
-- ============================================================

-- Connect to the AWX database
\connect awx;

-- Enable extensions required by AWX
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Set database defaults
ALTER DATABASE awx SET timezone TO 'UTC';
ALTER DATABASE awx SET client_encoding TO 'UTF8';

-- Ensure awx user has full access
GRANT ALL PRIVILEGES ON DATABASE awx TO awx;
GRANT ALL ON SCHEMA public TO awx;

-- Log slow queries for performance monitoring
ALTER DATABASE awx SET log_min_duration_statement TO 1000;

-- postgres/init.sql
-- ============================================================
-- PostgreSQL Initialization Script for AWX
-- This script runs once when the database is first created.
-- The AWX application runs its own Django migrations on startup
-- to create all application tables.
-- ============================================================

-- Connect to the AWX database
\connect awx;

-- ── Extensions ────────────────────────────────────────────────
-- Enable pg_stat_statements for query performance monitoring
-- Useful for diagnosing slow queries in AWX
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Enable uuid-ossp for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Database settings ─────────────────────────────────────────
-- Use UTC for all timestamps (required by Django/AWX)
ALTER DATABASE awx SET timezone TO 'UTC';

-- Set client encoding
ALTER DATABASE awx SET client_encoding TO 'UTF8';

-- ── Privileges ────────────────────────────────────────────────
-- Ensure the AWX user has full access to the database
GRANT ALL PRIVILEGES ON DATABASE awx TO awx;

-- Grant schema privileges (needed for AWX migrations)
GRANT ALL ON SCHEMA public TO awx;

-- ── Performance hints ─────────────────────────────────────────
-- These are hints; actual tuning is done in postgresql.conf
-- via the ConfigMap in k8s/base/postgres/configmap.yaml

-- Log slow queries (> 1000ms) for monitoring
ALTER DATABASE awx SET log_min_duration_statement TO 1000;

-- ── Verification ──────────────────────────────────────────────
-- List created extensions (visible in logs on first start)
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- Confirm timezone
SHOW timezone;

-- Runs once, on first initialisation of the postgres_data volume.
-- The test database must be separate from development: the suite truncates it.
CREATE DATABASE aea_onboarding_test;

-- Extension Usage Examples for CNPG with Nhost Extensions
-- This file demonstrates how to use various extensions included in the image

-- ============================================================================
-- POSTGIS - Geospatial Data
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgis;

-- Create a locations table with geometry
CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    location GEOMETRY(Point, 4326)
);

-- Insert some sample locations (using longitude, latitude)
INSERT INTO locations (name, description, location) VALUES
    ('San Francisco Office', 'Main office', ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)),
    ('New York Office', 'East coast office', ST_SetSRID(ST_MakePoint(-74.0060, 40.7128), 4326)),
    ('London Office', 'European office', ST_SetSRID(ST_MakePoint(-0.1276, 51.5074), 4326));

-- Find locations within 1000km of San Francisco
SELECT name,
       ST_Distance(location::geography, ST_MakePoint(-122.4194, 37.7749)::geography) / 1000 as distance_km
FROM locations
WHERE ST_DWithin(location::geography, ST_MakePoint(-122.4194, 37.7749)::geography, 1000000)
ORDER BY distance_km;

-- ============================================================================
-- VECTOR - AI/ML Embeddings
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS vector;

-- Create a table for storing document embeddings
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    content TEXT,
    embedding vector(1536)  -- OpenAI embedding dimension
);

-- Create an HNSW index for fast similarity search
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops);

-- Insert sample embeddings (normally these would come from an AI model)
INSERT INTO documents (content, embedding) VALUES
    ('PostgreSQL is a powerful database', array_fill(0.1, ARRAY[1536])::vector),
    ('Machine learning with embeddings', array_fill(0.2, ARRAY[1536])::vector);

-- Find similar documents (cosine similarity)
SELECT content,
       1 - (embedding <=> array_fill(0.15, ARRAY[1536])::vector) as similarity
FROM documents
ORDER BY embedding <=> array_fill(0.15, ARRAY[1536])::vector
LIMIT 5;

-- ============================================================================
-- TIMESCALEDB - Time-Series Data
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create a metrics table
CREATE TABLE metrics (
    time TIMESTAMPTZ NOT NULL,
    device_id INTEGER NOT NULL,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION,
    pressure DOUBLE PRECISION
);

-- Convert to a hypertable for time-series optimization
SELECT create_hypertable('metrics', 'time');

-- Insert sample data
INSERT INTO metrics (time, device_id, temperature, humidity, pressure)
SELECT
    time,
    (random() * 10)::integer as device_id,
    20 + (random() * 10) as temperature,
    40 + (random() * 40) as humidity,
    1000 + (random() * 50) as pressure
FROM generate_series(
    NOW() - INTERVAL '30 days',
    NOW(),
    INTERVAL '5 minutes'
) AS time;

-- Query with time-based aggregation
SELECT
    time_bucket('1 hour', time) AS hour,
    device_id,
    AVG(temperature) as avg_temp,
    MAX(temperature) as max_temp,
    MIN(temperature) as min_temp
FROM metrics
WHERE time > NOW() - INTERVAL '7 days'
GROUP BY hour, device_id
ORDER BY hour DESC, device_id
LIMIT 20;

-- ============================================================================
-- PG_CRON - Job Scheduling
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule a cleanup job to run daily at 3 AM
SELECT cron.schedule(
    'cleanup-old-logs',
    '0 3 * * *',
    $$DELETE FROM logs WHERE created_at < NOW() - INTERVAL '90 days'$$
);

-- Schedule a vacuum job to run weekly
SELECT cron.schedule(
    'weekly-vacuum',
    '0 0 * * 0',
    $$VACUUM ANALYZE$$
);

-- List all scheduled jobs
SELECT * FROM cron.job;

-- Unschedule a job
-- SELECT cron.unschedule('cleanup-old-logs');

-- ============================================================================
-- PGMQ - Message Queue
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgmq;

-- Create a message queue
SELECT pgmq.create('tasks');

-- Send messages to the queue
SELECT pgmq.send('tasks', jsonb_build_object(
    'task_type', 'send_email',
    'recipient', 'user@example.com',
    'subject', 'Welcome!'
));

SELECT pgmq.send('tasks', jsonb_build_object(
    'task_type', 'process_image',
    'image_id', 12345,
    'operations', jsonb_build_array('resize', 'compress')
));

-- Read messages from the queue (30 second visibility timeout, 1 message)
SELECT * FROM pgmq.read('tasks', 30, 1);

-- Archive a processed message
-- SELECT pgmq.archive('tasks', <msg_id>);

-- Delete a message
-- SELECT pgmq.delete('tasks', <msg_id>);

-- Get queue metrics
SELECT * FROM pgmq.metrics('tasks');

-- ============================================================================
-- HTTP - External API Calls
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS http;

-- Make a GET request
SELECT content::json
FROM http_get('https://api.github.com/repos/cloudnative-pg/cloudnative-pg');

-- Make a POST request (example structure)
-- SELECT content
-- FROM http_post(
--     'https://api.example.com/webhook',
--     '{"event": "user_registered", "user_id": 123}'::text,
--     'application/json'
-- );

-- ============================================================================
-- PG_JSONSCHEMA - JSON Schema Validation
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_jsonschema;

-- Create a table with JSON schema validation
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    profile JSONB,
    CONSTRAINT valid_profile CHECK (
        json_matches_schema(
            '{
                "type": "object",
                "required": ["name", "email"],
                "properties": {
                    "name": {"type": "string", "minLength": 1},
                    "email": {"type": "string", "format": "email"},
                    "age": {"type": "number", "minimum": 0}
                }
            }',
            profile
        )
    )
);

-- Valid insert
INSERT INTO users (profile) VALUES
    ('{"name": "John Doe", "email": "john@example.com", "age": 30}');

-- This would fail validation:
-- INSERT INTO users (profile) VALUES ('{"name": "Jane"}');

-- ============================================================================
-- HSTORE - Key-Value Storage
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS hstore;

-- Create a table with hstore
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT,
    attributes hstore
);

-- Insert products with dynamic attributes
INSERT INTO products (name, attributes) VALUES
    ('Laptop', 'brand=>Dell, ram=>16GB, storage=>512GB SSD, color=>silver'),
    ('Phone', 'brand=>Apple, model=>iPhone 14, storage=>256GB, color=>black'),
    ('Tablet', 'brand=>Samsung, screen=>11", storage=>128GB');

-- Query by hstore key
SELECT name, attributes->'brand' as brand, attributes->'storage' as storage
FROM products
WHERE attributes->'brand' = 'Dell';

-- Check if key exists
SELECT name FROM products WHERE attributes ? 'screen';

-- ============================================================================
-- LTREE - Hierarchical Data
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS ltree;

-- Create a hierarchical category structure
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name TEXT,
    path ltree
);

-- Create an index for efficient queries
CREATE INDEX categories_path_idx ON categories USING GIST (path);

-- Insert hierarchical data
INSERT INTO categories (name, path) VALUES
    ('Electronics', 'electronics'),
    ('Computers', 'electronics.computers'),
    ('Laptops', 'electronics.computers.laptops'),
    ('Desktops', 'electronics.computers.desktops'),
    ('Phones', 'electronics.phones'),
    ('Smartphones', 'electronics.phones.smartphones');

-- Find all descendants of 'computers'
SELECT name, path
FROM categories
WHERE path <@ 'electronics.computers';

-- Find all ancestors of 'laptops'
SELECT name, path
FROM categories
WHERE path @> 'electronics.computers.laptops';

-- ============================================================================
-- PG_HASHIDS - Short Unique IDs
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_hashids;

-- Generate short IDs from integers
SELECT id_encode(12345, 'my-salt', 8) as short_id;
SELECT id_encode(67890, 'my-salt', 8) as short_id;

-- Decode back to integer
SELECT id_decode('R8elWVN9', 'my-salt', 8) as original_id;

-- Use in a table
CREATE TABLE short_urls (
    id SERIAL PRIMARY KEY,
    url TEXT,
    short_code TEXT GENERATED ALWAYS AS (id_encode(id, 'url-shortener', 8)) STORED
);

INSERT INTO short_urls (url) VALUES
    ('https://example.com/very/long/url/that/needs/shortening');

SELECT id, short_code, url FROM short_urls;

-- ============================================================================
-- PG_TRGM - Text Similarity Search
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create a table with text data
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    title TEXT,
    content TEXT
);

-- Create a GIN index for fast similarity search
CREATE INDEX articles_title_trgm_idx ON articles USING GIN (title gin_trgm_ops);
CREATE INDEX articles_content_trgm_idx ON articles USING GIN (content gin_trgm_ops);

-- Insert sample data
INSERT INTO articles (title, content) VALUES
    ('PostgreSQL Performance Tuning', 'Learn how to optimize PostgreSQL for better performance...'),
    ('Database Scaling Strategies', 'Explore different approaches to scaling databases...'),
    ('Introduction to PostGIS', 'Getting started with spatial data in PostgreSQL...');

-- Fuzzy search with similarity threshold
SELECT title, similarity(title, 'postgres performance') as score
FROM articles
WHERE title % 'postgres performance'
ORDER BY score DESC;

-- ============================================================================
-- PGCRYPTO - Encryption
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Hash a password
SELECT crypt('my-password', gen_salt('bf'));

-- Verify a password
SELECT crypt('my-password', '$2a$06$...') = '$2a$06$...';

-- Generate UUID
SELECT gen_random_uuid();

-- Encrypt/Decrypt data
SELECT pgp_sym_encrypt('sensitive data', 'encryption-key');
SELECT pgp_sym_decrypt(
    pgp_sym_encrypt('sensitive data', 'encryption-key'),
    'encryption-key'
);

-- ============================================================================
-- Cleanup (uncomment to run)
-- ============================================================================

-- DROP TABLE IF EXISTS locations;
-- DROP TABLE IF EXISTS documents;
-- DROP TABLE IF EXISTS metrics;
-- DROP TABLE IF EXISTS users;
-- DROP TABLE IF EXISTS products;
-- DROP TABLE IF EXISTS categories;
-- DROP TABLE IF EXISTS short_urls;
-- DROP TABLE IF EXISTS articles;

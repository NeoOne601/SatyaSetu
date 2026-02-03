-- ==========================================================================
-- FILE: backend/db/init.sql
-- VERSION: 1.0.0
-- PHASE: Phase 14 (Backend Microservices)
-- DESCRIPTION: PostgreSQL database initialization for Satya Setu
-- ==========================================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "vector";

-- ==========================================================================
-- VENDORS TABLE: GST-verified marketplace sellers
-- ==========================================================================
CREATE TABLE IF NOT EXISTS vendors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    did TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    gstin TEXT UNIQUE,  -- GST Identification Number
    pan TEXT,
    trust_score FLOAT DEFAULT 0.5,
    total_sales INTEGER DEFAULT 0,
    total_reviews INTEGER DEFAULT 0,
    average_rating FLOAT DEFAULT 0.0,
    location GEOGRAPHY(POINT, 4326),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    is_verified BOOLEAN DEFAULT FALSE,
    verification_date TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_vendors_did ON vendors(did);
CREATE INDEX IF NOT EXISTS idx_vendors_gstin ON vendors(gstin);
CREATE INDEX IF NOT EXISTS idx_vendors_location ON vendors USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_vendors_trust ON vendors(trust_score DESC);

-- ==========================================================================
-- PRODUCTS TABLE: Marketplace listings
-- ==========================================================================
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vendor_id UUID REFERENCES vendors(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    price_inr INTEGER NOT NULL,
    category TEXT,
    tags TEXT[],
    image_urls TEXT[],
    embedding VECTOR(384),  -- For semantic search
    is_active BOOLEAN DEFAULT TRUE,
    stock_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_vendor ON products(vendor_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price_inr);
CREATE INDEX IF NOT EXISTS idx_products_embedding ON products USING ivfflat (embedding vector_cosine_ops);

-- ==========================================================================
-- ADS TABLE: Promoted listings with bids
-- ==========================================================================
CREATE TABLE IF NOT EXISTS ads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vendor_id UUID REFERENCES vendors(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    bid_amount INTEGER NOT NULL,  -- In paise (1/100 INR)
    daily_budget INTEGER NOT NULL,
    spent_today INTEGER DEFAULT 0,
    target_keywords TEXT[],
    target_categories TEXT[],
    target_location GEOGRAPHY(POLYGON, 4326),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ads_vendor ON ads(vendor_id);
CREATE INDEX IF NOT EXISTS idx_ads_active ON ads(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_ads_bid ON ads(bid_amount DESC);

-- ==========================================================================
-- VERIFICATIONS TABLE: User verification records
-- ==========================================================================
CREATE TABLE IF NOT EXISTS verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id TEXT NOT NULL,
    entity_label TEXT NOT NULL,
    verifier_did TEXT NOT NULL,
    verification_type TEXT NOT NULL,  -- 'PHOTO', 'RATING', 'REPORT'
    rating INTEGER,  -- 1-5 stars
    comment TEXT,
    nostr_event_id TEXT,
    location GEOGRAPHY(POINT, 4326),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_verifications_entity ON verifications(entity_id);
CREATE INDEX IF NOT EXISTS idx_verifications_verifier ON verifications(verifier_did);
CREATE INDEX IF NOT EXISTS idx_verifications_type ON verifications(verification_type);

-- ==========================================================================
-- BOUNTIES TABLE: Verification rewards
-- ==========================================================================
CREATE TABLE IF NOT EXISTS bounties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_label TEXT NOT NULL,
    entity_id TEXT,
    reward_inr INTEGER NOT NULL,
    requirement TEXT NOT NULL,
    verifications_needed INTEGER DEFAULT 10,
    current_verifications INTEGER DEFAULT 0,
    sponsor_vendor_id UUID REFERENCES vendors(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_bounties_active ON bounties(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_bounties_entity ON bounties(entity_label);

-- ==========================================================================
-- SEARCH CACHE TABLE: For fast lookups
-- ==========================================================================
CREATE TABLE IF NOT EXISTS search_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    query_hash TEXT UNIQUE NOT NULL,
    results JSONB NOT NULL,
    result_count INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_search_cache_hash ON search_cache(query_hash);
CREATE INDEX IF NOT EXISTS idx_search_cache_expires ON search_cache(expires_at);

-- ==========================================================================
-- FUNCTIONS: Sovereign Ad Logic ranking
-- ==========================================================================
CREATE OR REPLACE FUNCTION calculate_product_rank(
    bid_amount FLOAT,
    vendor_trust FLOAT,
    organic_relevance FLOAT,
    social_proximity FLOAT
) RETURNS FLOAT AS $$
BEGIN
    -- Sovereign Ad Logic: Score = (Bid * AdvertiserTrust) + (OrganicRelevance * SocialProximity)
    RETURN (COALESCE(bid_amount, 0) * vendor_trust) + (organic_relevance * social_proximity);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ==========================================================================
-- FUNCTIONS: Clean up expired cache
-- ==========================================================================
CREATE OR REPLACE FUNCTION cleanup_expired_cache() RETURNS void AS $$
BEGIN
    DELETE FROM search_cache WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Schedule cache cleanup (requires pg_cron extension in production)
-- SELECT cron.schedule('cleanup_cache', '0 * * * *', 'SELECT cleanup_expired_cache()');

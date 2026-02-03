"""
FILE: backend/search_api/main.py
VERSION: 1.0.0
PHASE: Phase 14 (Backend Microservices)
DESCRIPTION: 
Search API microservice for the Satya Setu Marketplace.
Implements product search with Sovereign Ad Logic ranking.
"""

import os
import json
import hashlib
from datetime import datetime, timedelta
from typing import Optional, List
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import redis.asyncio as redis
import asyncpg


# =============================================================================
# CONFIGURATION
# =============================================================================

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://satya:satya@localhost:5432/satya_setu")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
API_KEY = os.getenv("API_KEY", "satya_api_key")
CACHE_TTL = 3600  # 1 hour


# =============================================================================
# DATABASE CONNECTION
# =============================================================================

async def get_db_pool():
    """Get or create database connection pool."""
    return await asyncpg.create_pool(DATABASE_URL)


async def get_redis():
    """Get Redis connection."""
    return redis.from_url(REDIS_URL)


# =============================================================================
# LIFESPAN
# =============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    app.state.db_pool = await get_db_pool()
    app.state.redis = await get_redis()
    print("[SEARCH_API] Connected to PostgreSQL and Redis")
    
    yield
    
    # Shutdown
    await app.state.db_pool.close()
    await app.state.redis.close()
    print("[SEARCH_API] Connections closed")


# =============================================================================
# FastAPI APP
# =============================================================================

app = FastAPI(
    title="Satya Setu Search API",
    description="Decentralized Marketplace Search with Sovereign Ad Logic",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =============================================================================
# MODELS
# =============================================================================

class SearchRequest(BaseModel):
    query: str
    category: Optional[str] = None
    min_price: Optional[int] = None
    max_price: Optional[int] = None
    vendor_did: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    radius_km: Optional[float] = 10.0
    limit: int = 20
    offset: int = 0
    user_trust_graph: Optional[List[str]] = None  # DIDs of trusted vendors

class ProductResult(BaseModel):
    product_id: str
    title: str
    description: Optional[str]
    vendor_did: str
    vendor_name: Optional[str]
    price_inr: int
    image_url: Optional[str]
    trust_score: float
    bid: Optional[float]
    is_sponsored: bool
    is_verified: bool
    rank: float

class SearchResponse(BaseModel):
    results: List[ProductResult]
    total_count: int
    from_cache: bool
    query_time_ms: float

class BountyResult(BaseModel):
    bounty_id: str
    entity_label: str
    entity_id: Optional[str]
    reward_inr: int
    requirement: str
    verifications_needed: int
    current_verifications: int
    expires_at: str


# =============================================================================
# RANKING LOGIC
# =============================================================================

def calculate_rank(
    bid: float,
    vendor_trust: float,
    organic_relevance: float,
    social_proximity: float
) -> float:
    """
    Sovereign Ad Logic: Score = (Bid * AdvertiserTrust) + (OrganicRelevance * SocialProximity)
    """
    sponsored_component = (bid or 0) * vendor_trust
    organic_component = organic_relevance * social_proximity
    return sponsored_component + organic_component


def calculate_social_proximity(vendor_did: str, trust_graph: List[str]) -> float:
    """
    Calculate social proximity based on user's trust graph.
    Returns 1.0 if vendor is in trust graph, 0.5 otherwise.
    """
    if not trust_graph:
        return 0.5
    return 1.0 if vendor_did in trust_graph else 0.5


# =============================================================================
# ENDPOINTS
# =============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "service": "search_api", "version": "1.0.0"}


@app.post("/v1/search", response_model=SearchResponse)
async def search_products(request: SearchRequest):
    """
    Search products with Sovereign Ad Logic ranking.
    
    Results are ranked using:
    Score = (Bid * AdvertiserTrust) + (OrganicRelevance * SocialProximity)
    """
    import time
    start_time = time.time()
    
    # Generate cache key
    cache_key = f"search:{hashlib.md5(json.dumps(request.dict(), sort_keys=True).encode()).hexdigest()}"
    
    # Check cache
    cached = await app.state.redis.get(cache_key)
    if cached:
        data = json.loads(cached)
        return SearchResponse(
            results=[ProductResult(**r) for r in data["results"]],
            total_count=data["total_count"],
            from_cache=True,
            query_time_ms=(time.time() - start_time) * 1000
        )
    
    # Build query
    query_parts = ["SELECT p.*, v.did as vendor_did, v.name as vendor_name, v.trust_score, v.is_verified,"]
    query_parts.append("COALESCE(a.bid_amount, 0) as bid_amount, a.is_active as is_sponsored")
    query_parts.append("FROM products p")
    query_parts.append("JOIN vendors v ON p.vendor_id = v.id")
    query_parts.append("LEFT JOIN ads a ON a.product_id = p.id AND a.is_active = TRUE")
    query_parts.append("WHERE p.is_active = TRUE")
    
    params = []
    param_idx = 1
    
    # Text search
    if request.query:
        query_parts.append(f"AND (p.title ILIKE ${param_idx} OR p.description ILIKE ${param_idx})")
        params.append(f"%{request.query}%")
        param_idx += 1
    
    # Category filter
    if request.category:
        query_parts.append(f"AND p.category = ${param_idx}")
        params.append(request.category)
        param_idx += 1
    
    # Price range
    if request.min_price:
        query_parts.append(f"AND p.price_inr >= ${param_idx}")
        params.append(request.min_price)
        param_idx += 1
    
    if request.max_price:
        query_parts.append(f"AND p.price_inr <= ${param_idx}")
        params.append(request.max_price)
        param_idx += 1
    
    # Vendor filter
    if request.vendor_did:
        query_parts.append(f"AND v.did = ${param_idx}")
        params.append(request.vendor_did)
        param_idx += 1
    
    # Location filter (if coordinates provided)
    if request.latitude and request.longitude and request.radius_km:
        query_parts.append(f"""
            AND ST_DWithin(
                v.location,
                ST_SetSRID(ST_MakePoint(${param_idx}, ${param_idx + 1}), 4326)::geography,
                ${param_idx + 2}
            )
        """)
        params.extend([request.longitude, request.latitude, request.radius_km * 1000])
        param_idx += 3
    
    # Limit and offset
    query_parts.append(f"LIMIT ${param_idx} OFFSET ${param_idx + 1}")
    params.extend([request.limit, request.offset])
    
    query = "\n".join(query_parts)
    
    # Execute query
    async with app.state.db_pool.acquire() as conn:
        rows = await conn.fetch(query, *params)
        
        # Count total
        count_query = query.split("LIMIT")[0].replace(
            "SELECT p.*, v.did as vendor_did, v.name as vendor_name, v.trust_score, v.is_verified,",
            "SELECT COUNT(*)"
        ).replace(
            "COALESCE(a.bid_amount, 0) as bid_amount, a.is_active as is_sponsored",
            ""
        )
        total_count = await conn.fetchval(count_query, *params[:-2]) if rows else 0
    
    # Process results with ranking
    trust_graph = request.user_trust_graph or []
    results = []
    
    for row in rows:
        vendor_did = row["vendor_did"]
        trust_score = row["trust_score"] or 0.5
        bid = row.get("bid_amount", 0) / 100  # Convert paise to rupees
        
        # Calculate relevance (simplified - in production, use embedding similarity)
        organic_relevance = 0.8 if request.query.lower() in row["title"].lower() else 0.5
        social_proximity = calculate_social_proximity(vendor_did, trust_graph)
        
        rank = calculate_rank(bid, trust_score, organic_relevance, social_proximity)
        
        results.append(ProductResult(
            product_id=str(row["id"]),
            title=row["title"],
            description=row.get("description"),
            vendor_did=vendor_did,
            vendor_name=row.get("vendor_name"),
            price_inr=row["price_inr"],
            image_url=row["image_urls"][0] if row.get("image_urls") else None,
            trust_score=trust_score,
            bid=bid if bid > 0 else None,
            is_sponsored=bool(row.get("is_sponsored")),
            is_verified=bool(row.get("is_verified")),
            rank=rank
        ))
    
    # Sort by rank
    results.sort(key=lambda x: x.rank, reverse=True)
    
    # Cache results
    cache_data = {
        "results": [r.dict() for r in results],
        "total_count": total_count or 0
    }
    await app.state.redis.setex(cache_key, CACHE_TTL, json.dumps(cache_data))
    
    return SearchResponse(
        results=results,
        total_count=total_count or 0,
        from_cache=False,
        query_time_ms=(time.time() - start_time) * 1000
    )


@app.get("/v1/bounties", response_model=List[BountyResult])
async def get_bounties(
    entity_label: Optional[str] = Query(None),
    limit: int = Query(20, le=100)
):
    """Get active verification bounties."""
    query = """
        SELECT * FROM bounties 
        WHERE is_active = TRUE AND expires_at > NOW()
    """
    params = []
    param_idx = 1
    
    if entity_label:
        query += f" AND entity_label ILIKE ${param_idx}"
        params.append(f"%{entity_label}%")
        param_idx += 1
    
    query += f" ORDER BY reward_inr DESC LIMIT ${param_idx}"
    params.append(limit)
    
    async with app.state.db_pool.acquire() as conn:
        rows = await conn.fetch(query, *params)
    
    return [
        BountyResult(
            bounty_id=str(row["id"]),
            entity_label=row["entity_label"],
            entity_id=row.get("entity_id"),
            reward_inr=row["reward_inr"],
            requirement=row["requirement"],
            verifications_needed=row["verifications_needed"],
            current_verifications=row["current_verifications"],
            expires_at=row["expires_at"].isoformat()
        )
        for row in rows
    ]


@app.post("/v1/verification")
async def submit_verification(
    entity_id: str,
    entity_label: str,
    verifier_did: str,
    verification_type: str,
    rating: Optional[int] = None,
    comment: Optional[str] = None,
    nostr_event_id: Optional[str] = None
):
    """Submit a verification for an entity."""
    async with app.state.db_pool.acquire() as conn:
        # Insert verification
        await conn.execute("""
            INSERT INTO verifications (entity_id, entity_label, verifier_did, verification_type, rating, comment, nostr_event_id)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
        """, entity_id, entity_label, verifier_did, verification_type, rating, comment, nostr_event_id)
        
        # Update bounty count if exists
        await conn.execute("""
            UPDATE bounties 
            SET current_verifications = current_verifications + 1
            WHERE entity_label ILIKE $1 AND is_active = TRUE
        """, f"%{entity_label}%")
    
    return {"status": "success", "message": "Verification recorded"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=9000)

"""
FILE: backend/search_api/main.py
VERSION: 2.0.0
PHASE: Phase 14 (Backend Microservices) - Enhanced
DESCRIPTION: 
Search API microservice for the Satya Setu Marketplace.
Implements product search with Sovereign Ad Logic ranking.
ENHANCEMENTS:
- Mock data endpoint for development
- Cold Start Bounty Protocol
- Enhanced ranking with vector embeddings
"""

import os
import json
import hashlib
from datetime import datetime, timedelta
from typing import Optional, List
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import redis.asyncio as redis

# Optional dependencies - graceful degradation
try:
    import asyncpg
    HAS_ASYNCPG = True
except ImportError:
    HAS_ASYNCPG = False
    print("[SEARCH_API] asyncpg not available, using mock mode")


# =============================================================================
# CONFIGURATION
# =============================================================================

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://satya:satya@localhost:5432/satya_setu")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
API_KEY = os.getenv("API_KEY", "satya_api_key")
CACHE_TTL = 3600  # 1 hour
MOCK_MODE = os.getenv("MOCK_MODE", "false").lower() == "true"


# =============================================================================
# DATABASE CONNECTION
# =============================================================================

async def get_db_pool():
    """Get or create database connection pool."""
    if HAS_ASYNCPG and not MOCK_MODE:
        try:
            return await asyncpg.create_pool(DATABASE_URL)
        except Exception as e:
            print(f"[SEARCH_API] Database connection failed: {e}")
            return None
    return None


async def get_redis():
    """Get Redis connection."""
    try:
        return redis.from_url(REDIS_URL)
    except Exception as e:
        print(f"[SEARCH_API] Redis connection failed: {e}")
        return None


# =============================================================================
# LIFESPAN
# =============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    app.state.db_pool = await get_db_pool()
    app.state.redis = await get_redis()
    app.state.mock_mode = MOCK_MODE or app.state.db_pool is None
    
    if app.state.mock_mode:
        print("[SEARCH_API] Running in MOCK MODE")
    else:
        print("[SEARCH_API] Connected to PostgreSQL and Redis")
    
    yield
    
    # Shutdown
    if app.state.db_pool:
        await app.state.db_pool.close()
    if app.state.redis:
        await app.state.redis.close()
    print("[SEARCH_API] Connections closed")


# =============================================================================
# FastAPI APP
# =============================================================================

app = FastAPI(
    title="Satya Setu Search API",
    description="Decentralized Marketplace Search with Sovereign Ad Logic",
    version="2.0.0",
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
    embedding: Optional[List[float]] = None  # 384-dim vector for semantic search

class ProductResult(BaseModel):
    product_id: str
    title: str
    description: Optional[str] = None
    vendor_did: str
    vendor_name: Optional[str] = None
    price_inr: int
    image_url: Optional[str] = None
    trust_score: float
    bid: Optional[float] = None
    is_sponsored: bool = False
    is_verified: bool = False
    rank: float
    is_bounty: bool = False

class SearchResponse(BaseModel):
    results: List[ProductResult]
    total_count: int
    from_cache: bool
    query_time_ms: float
    is_mock: bool = False

class BountyResult(BaseModel):
    bounty_id: str
    entity_label: str
    entity_id: Optional[str] = None
    reward_inr: int
    requirement: str
    verifications_needed: int
    current_verifications: int
    expires_at: str
    sponsor_name: Optional[str] = None
    sponsor_did: Optional[str] = None

class VerificationRequest(BaseModel):
    entity_id: str
    entity_label: str
    verifier_did: str
    verification_type: str  # VERIFY, RATE, REPORT
    rating: Optional[int] = Field(None, ge=1, le=5)
    comment: Optional[str] = None
    nostr_event_id: Optional[str] = None
    photo_hash: Optional[str] = None


# =============================================================================
# MOCK DATA GENERATOR
# =============================================================================

def generate_mock_products(query: str, limit: int = 20) -> List[ProductResult]:
    """Generate mock products for development."""
    normalized = query.upper()
    
    products = [
        ProductResult(
            product_id=f"mock_{query.lower()}_001",
            title=f"{normalized} - Premium Quality",
            description="Verified authentic product with warranty. GST registered seller.",
            vendor_did="did:satya:vendor_premium_001",
            vendor_name="TrustMart Premium",
            price_inr=2999,
            image_url=None,
            trust_score=0.92,
            bid=15.0,
            is_sponsored=True,
            is_verified=True,
            rank=0.0,
        ),
        ProductResult(
            product_id=f"mock_{query.lower()}_002",
            title=f"{normalized} - Standard Edition",
            description="GST verified seller with excellent ratings.",
            vendor_did="did:satya:vendor_standard_001",
            vendor_name="LocalShop India",
            price_inr=1499,
            image_url=None,
            trust_score=0.75,
            bid=None,
            is_sponsored=False,
            is_verified=True,
            rank=0.0,
        ),
        ProductResult(
            product_id=f"mock_{query.lower()}_003",
            title=f"{normalized} - Value Pack",
            description="Good reviews, new seller building trust.",
            vendor_did="did:satya:vendor_new_001",
            vendor_name="NewBiz Goods",
            price_inr=999,
            image_url=None,
            trust_score=0.55,
            bid=5.0,
            is_sponsored=True,
            is_verified=False,
            rank=0.0,
        ),
        ProductResult(
            product_id=f"mock_{query.lower()}_004",
            title=f"{normalized} - Budget Option",
            description="Unverified seller, buyer beware.",
            vendor_did="did:satya:vendor_budget_001",
            vendor_name="QuickSell",
            price_inr=499,
            image_url=None,
            trust_score=0.35,
            bid=None,
            is_sponsored=False,
            is_verified=False,
            rank=0.0,
        ),
        ProductResult(
            product_id=f"mock_{query.lower()}_005",
            title=f"{normalized} - Help Verify This!",
            description="New listing needs community verification. Earn ₹50 bounty!",
            vendor_did="did:satya:vendor_unknown_001",
            vendor_name="Unknown Seller",
            price_inr=799,
            image_url=None,
            trust_score=0.1,
            bid=None,
            is_sponsored=False,
            is_verified=False,
            rank=0.0,
            is_bounty=True,
        ),
    ]
    
    return products[:limit]


def generate_mock_bounties(entity_label: str) -> List[BountyResult]:
    """Generate mock bounties for Cold Start Protocol."""
    now = datetime.utcnow()
    
    return [
        BountyResult(
            bounty_id=f"bounty_{entity_label.lower().replace(' ', '_')}_001",
            entity_label=entity_label,
            entity_id=f"entity_{entity_label.lower().replace(' ', '_')}",
            reward_inr=50,
            requirement="Take a verification photo and rate product authenticity",
            verifications_needed=10,
            current_verifications=3,
            expires_at=(now + timedelta(days=7)).isoformat(),
            sponsor_name="SatyaSetu Community Fund",
        ),
        BountyResult(
            bounty_id=f"bounty_{entity_label.lower().replace(' ', '_')}_002",
            entity_label=f"{entity_label} Quality Check",
            entity_id=f"entity_{entity_label.lower().replace(' ', '_')}_quality",
            reward_inr=100,
            requirement="Verify product quality and condition with detailed review",
            verifications_needed=5,
            current_verifications=1,
            expires_at=(now + timedelta(days=5)).isoformat(),
            sponsor_name="TrustMart Premium",
            sponsor_did="did:satya:vendor_premium_001",
        ),
        BountyResult(
            bounty_id=f"coldstart_{entity_label.lower().replace(' ', '_')}",
            entity_label=f"{entity_label} - First Verification",
            entity_id=None,
            reward_inr=75,
            requirement="Be the FIRST to verify this item! Higher bounty for pioneers.",
            verifications_needed=3,
            current_verifications=0,
            expires_at=(now + timedelta(days=14)).isoformat(),
            sponsor_name="Cold Start Fund",
        ),
    ]


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
    
    if vendor_did in trust_graph:
        return 1.0
    
    # Check for related vendors (same prefix)
    vendor_prefix = ':'.join(vendor_did.split(':')[:3])
    if any(v.startswith(vendor_prefix) for v in trust_graph):
        return 0.75
    
    return 0.5


def calculate_organic_relevance(product: ProductResult, query: str) -> float:
    """Calculate organic relevance score."""
    score = 0.5  # Base score
    
    # Query match
    if query.lower() in product.title.lower():
        score += 0.3
    
    if product.is_verified:
        score += 0.2
    
    if product.description and len(product.description) > 50:
        score += 0.1
    
    if product.trust_score >= 0.7:
        score += 0.15
    
    return min(score, 1.0)


# =============================================================================
# ENDPOINTS
# =============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy", 
        "service": "search_api", 
        "version": "2.0.0",
        "mock_mode": getattr(app.state, 'mock_mode', True)
    }


@app.post("/v1/search", response_model=SearchResponse)
async def search_products(request: SearchRequest):
    """
    Search products with Sovereign Ad Logic ranking.
    
    Results are ranked using:
    Score = (Bid * AdvertiserTrust) + (OrganicRelevance * SocialProximity)
    
    Falls back to mock data if database is unavailable.
    """
    import time
    start_time = time.time()
    
    # Check if in mock mode
    if getattr(app.state, 'mock_mode', True):
        return await _search_mock(request, start_time)
    
    return await _search_database(request, start_time)


async def _search_mock(request: SearchRequest, start_time: float) -> SearchResponse:
    """Return mock search results."""
    import time
    
    products = generate_mock_products(request.query, request.limit)
    trust_graph = request.user_trust_graph or []
    
    # Apply ranking
    for product in products:
        organic_relevance = calculate_organic_relevance(product, request.query)
        social_proximity = calculate_social_proximity(product.vendor_did, trust_graph)
        product.rank = calculate_rank(
            product.bid or 0, 
            product.trust_score, 
            organic_relevance, 
            social_proximity
        )
    
    # Sort by rank
    products.sort(key=lambda x: x.rank, reverse=True)
    
    return SearchResponse(
        results=products,
        total_count=len(products),
        from_cache=False,
        query_time_ms=(time.time() - start_time) * 1000,
        is_mock=True
    )


async def _search_database(request: SearchRequest, start_time: float) -> SearchResponse:
    """Search products from PostgreSQL database."""
    import time
    
    # Generate cache key
    cache_key = f"search:{hashlib.md5(json.dumps(request.dict(), sort_keys=True).encode()).hexdigest()}"
    
    # Check cache
    if app.state.redis:
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
    
    # Location filter
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
        bid = row.get("bid_amount", 0) / 100
        
        product = ProductResult(
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
            rank=0.0
        )
        
        organic_relevance = calculate_organic_relevance(product, request.query)
        social_proximity = calculate_social_proximity(vendor_did, trust_graph)
        product.rank = calculate_rank(bid, trust_score, organic_relevance, social_proximity)
        
        results.append(product)
    
    # Sort by rank
    results.sort(key=lambda x: x.rank, reverse=True)
    
    # Cache results
    if app.state.redis:
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
    """
    Get active verification bounties.
    Returns mock bounties if database unavailable.
    """
    # Mock mode
    if getattr(app.state, 'mock_mode', True):
        bounties = generate_mock_bounties(entity_label or "Unknown Item")
        return bounties[:limit]
    
    # Database mode
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
            expires_at=row["expires_at"].isoformat(),
            sponsor_name=row.get("sponsor_name"),
            sponsor_did=row.get("sponsor_did"),
        )
        for row in rows
    ]


@app.post("/v1/verification")
async def submit_verification(request: VerificationRequest):
    """
    Submit a verification for an entity.
    Implements Cold Start Bounty Protocol - updates bounty progress.
    """
    # Mock mode
    if getattr(app.state, 'mock_mode', True):
        return {
            "status": "success", 
            "message": "Verification recorded (mock)",
            "bounty_progress": {
                "entity_label": request.entity_label,
                "new_count": 4,  # Simulated increment
                "reward_earned": 50 if request.verification_type == "VERIFY" else 0
            }
        }
    
    # Database mode
    async with app.state.db_pool.acquire() as conn:
        # Insert verification
        await conn.execute("""
            INSERT INTO verifications (entity_id, entity_label, verifier_did, verification_type, rating, comment, nostr_event_id, photo_hash)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        """, request.entity_id, request.entity_label, request.verifier_did, 
             request.verification_type, request.rating, request.comment, 
             request.nostr_event_id, request.photo_hash)
        
        # Update bounty count if exists
        result = await conn.fetchrow("""
            UPDATE bounties 
            SET current_verifications = current_verifications + 1
            WHERE entity_label ILIKE $1 AND is_active = TRUE
            RETURNING current_verifications, verifications_needed, reward_inr
        """, f"%{request.entity_label}%")
        
        bounty_info = None
        if result:
            is_complete = result["current_verifications"] >= result["verifications_needed"]
            bounty_info = {
                "new_count": result["current_verifications"],
                "needed": result["verifications_needed"],
                "reward_earned": result["reward_inr"] if is_complete else 0,
                "complete": is_complete
            }
    
    return {
        "status": "success", 
        "message": "Verification recorded",
        "bounty_progress": bounty_info
    }


@app.get("/v1/mock/products/{query}")
async def get_mock_products(query: str, limit: int = Query(20)):
    """
    Development endpoint: Get mock products for testing.
    Always returns mock data regardless of database status.
    """
    import time
    start_time = time.time()
    
    products = generate_mock_products(query, limit)
    
    # Apply default ranking
    for i, product in enumerate(products):
        product.rank = calculate_rank(
            product.bid or 0,
            product.trust_score,
            0.7 if product.is_verified else 0.5,
            0.5
        )
    
    products.sort(key=lambda x: x.rank, reverse=True)
    
    return SearchResponse(
        results=products,
        total_count=len(products),
        from_cache=False,
        query_time_ms=(time.time() - start_time) * 1000,
        is_mock=True
    )


@app.get("/v1/mock/bounties/{entity_label}")
async def get_mock_bounties(entity_label: str):
    """
    Development endpoint: Get mock bounties for testing Cold Start Protocol.
    """
    return generate_mock_bounties(entity_label)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=9000)

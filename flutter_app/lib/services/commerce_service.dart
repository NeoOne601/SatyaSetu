/**
 * FILE: flutter_app/lib/services/commerce_service.dart
 * VERSION: 2.0.0
 * PHASE: Phase 12 (Sovereign Commerce) - Enhanced
 * DESCRIPTION: 
 * Marketplace logic with local-first strategy and Cold Start Bounty Protocol.
 * Implements Sovereign Ad Logic: Score = (Bid * AdvertiserTrust) + (OrganicRelevance * SocialProximity)
 * ENHANCEMENTS:
 * - Mock data for development mode
 * - Cold Start Bounty Protocol for unindexed entities
 * - Social proximity from trust graph
 */

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'database_service.dart';
import 'event_bus.dart';

/// Product from marketplace search results
class MarketplaceProduct {
  final String productId;
  final String title;
  final String? description;
  final String vendorDid;
  final String? vendorName;
  final int priceInr;
  final String? imageUrl;
  final double trustScore;        // Vendor trust (0.0-1.0)
  final double? bid;              // Advertising bid amount
  final bool isSponsored;         // Is a paid promotion
  final bool isVerified;          // Vendor is GST verified
  final double rank;              // Calculated rank score
  final bool isBounty;            // Cold Start Bounty item
  
  MarketplaceProduct({
    required this.productId,
    required this.title,
    this.description,
    required this.vendorDid,
    this.vendorName,
    required this.priceInr,
    this.imageUrl,
    required this.trustScore,
    this.bid,
    this.isSponsored = false,
    this.isVerified = false,
    required this.rank,
    this.isBounty = false,
  });
  
  /// Format price in INR with symbol
  String get formattedPrice => '₹${priceInr.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  )}';
  
  /// Get trust badge text
  String get trustBadge {
    if (trustScore >= 0.9) return 'Platinum';
    if (trustScore >= 0.7) return 'Gold';
    if (trustScore >= 0.5) return 'Silver';
    return 'New';
  }
  
  factory MarketplaceProduct.fromJson(Map<String, dynamic> json) {
    return MarketplaceProduct(
      productId: json['product_id'] ?? json['id'] ?? '',
      title: json['title'] ?? json['name'] ?? 'Unknown Product',
      description: json['description'],
      vendorDid: json['vendor_did'] ?? '',
      vendorName: json['vendor_name'],
      priceInr: json['price_inr'] ?? json['price'] ?? 0,
      imageUrl: json['image_url'],
      trustScore: (json['trust_score'] ?? 0.5).toDouble(),
      bid: json['bid']?.toDouble(),
      isSponsored: json['is_sponsored'] ?? false,
      isVerified: json['is_verified'] ?? false,
      rank: (json['rank'] ?? 0.0).toDouble(),
      isBounty: json['is_bounty'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'title': title,
    'description': description,
    'vendor_did': vendorDid,
    'vendor_name': vendorName,
    'price_inr': priceInr,
    'image_url': imageUrl,
    'trust_score': trustScore,
    'bid': bid,
    'is_sponsored': isSponsored,
    'is_verified': isVerified,
    'rank': rank,
    'is_bounty': isBounty,
  };
}

/// Bounty for unverified entities (Cold Start Protocol)
class VerificationBounty {
  final String entityLabel;
  final String entityId;
  final int rewardInr;
  final String requirement;
  final DateTime expiresAt;
  final int verificationsNeeded;
  final int currentVerifications;
  final String? sponsorName;           // Vendor sponsoring the bounty
  final String? sponsorDid;
  
  VerificationBounty({
    required this.entityLabel,
    required this.entityId,
    required this.rewardInr,
    required this.requirement,
    required this.expiresAt,
    required this.verificationsNeeded,
    required this.currentVerifications,
    this.sponsorName,
    this.sponsorDid,
  });
  
  String get formattedReward => '₹$rewardInr';
  double get progress => currentVerifications / verificationsNeeded;
  bool get isComplete => currentVerifications >= verificationsNeeded;
  bool get isHighValue => rewardInr >= 100;
  
  factory VerificationBounty.fromJson(Map<String, dynamic> json) {
    return VerificationBounty(
      entityLabel: json['entity_label'] ?? '',
      entityId: json['entity_id'] ?? '',
      rewardInr: json['reward_inr'] ?? 0,
      requirement: json['requirement'] ?? 'Take a verification photo',
      expiresAt: DateTime.tryParse(json['expires_at'] ?? '') ?? 
                 DateTime.now().add(const Duration(days: 7)),
      verificationsNeeded: json['verifications_needed'] ?? 10,
      currentVerifications: json['current_verifications'] ?? 0,
      sponsorName: json['sponsor_name'],
      sponsorDid: json['sponsor_did'],
    );
  }
}

/// Result of product fetch operation
class ProductFetchResult {
  final List<MarketplaceProduct> verified;   // Trusted vendors
  final List<MarketplaceProduct> global;     // All results
  final List<VerificationBounty> bounties;   // Available bounties
  final bool fromCache;
  final String? error;
  final bool isColdStart;                    // No results, bounty opportunity
  
  ProductFetchResult({
    required this.verified,
    required this.global,
    required this.bounties,
    this.fromCache = false,
    this.error,
    this.isColdStart = false,
  });
  
  bool get hasError => error != null;
  int get totalCount => verified.length + global.length;
}

/// Commerce Service for marketplace operations
class CommerceService {
  static final CommerceService _instance = CommerceService._internal();
  factory CommerceService() => _instance;
  CommerceService._internal();
  
  final DatabaseService _db = DatabaseService();
  final EventBus _eventBus = EventBus();
  
  // Backend API endpoint (Phase 14)
  static const String _searchEndpoint = 'http://localhost:9000/v1/search';
  static const String _bountyEndpoint = 'http://localhost:9000/v1/bounties';
  
  // Use mock data when backend is unavailable
  bool _useMockData = false;
  
  // Cache duration (1 hour)
  static const Duration _cacheDuration = Duration(hours: 1);
  
  // Trust graph cache
  List<String> _trustedVendors = [];
  
  StreamSubscription<SatyaEvent>? _objectSelectedSubscription;
  
  /// Current products stream
  final _productsController = StreamController<ProductFetchResult>.broadcast();
  Stream<ProductFetchResult> get productsStream => _productsController.stream;
  
  /// Enable mock data mode for development
  void enableMockData() {
    _useMockData = true;
    debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Mock data mode enabled');
  }
  
  /// Initialize the commerce service
  Future<void> initialize() async {
    debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Initializing service...');
    
    // Load trust graph from database
    await _loadTrustGraph();
    
    // Listen to object selection events
    _objectSelectedSubscription = _eventBus.on(SatyaEventType.objectSelected).listen((event) {
      final payload = event.getPayload<ObjectSelectedPayload>();
      if (payload != null) {
        fetchProducts(payload.candidate.objectLabel);
      }
    });
    
    // Check backend health
    try {
      await http.get(Uri.parse('http://localhost:9000/health'))
          .timeout(const Duration(seconds: 2));
      debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Backend connected');
    } catch (e) {
      debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Backend unavailable, using mock data');
      _useMockData = true;
    }
    
    debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Service initialized');
  }
  
  /// Load trusted vendors from local database
  Future<void> _loadTrustGraph() async {
    final entities = await _db.getTrustGraph(limit: 100);
    _trustedVendors = entities
        .where((e) => e.trustScore >= 0.7)
        .map((e) => e.id)
        .toList();
    debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Loaded ${_trustedVendors.length} trusted vendors');
  }
  
  /// Fetch products for a detected object label
  /// Implements local-first strategy with Cold Start Bounty Protocol
  Future<ProductFetchResult> fetchProducts(String label) async {
    debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Fetching products for: $label');
    
    try {
      // Step 1: Check local cache first (offline-first)
      final cachedProducts = await _db.getCachedProducts(label);
      
      if (cachedProducts.isNotEmpty) {
        debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Found ${cachedProducts.length} cached products');
        
        final result = _processProducts(cachedProducts, label, fromCache: true);
        _productsController.add(result);
        
        // Refresh in background
        _refreshInBackground(label);
        
        return result;
      }
      
      // Step 2: Use mock data if enabled
      if (_useMockData) {
        return await _fetchMockProducts(label);
      }
      
      // Step 3: Fetch from network
      return await _fetchFromNetwork(label);
      
    } catch (e) {
      debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Error: $e');
      
      // Cold Start Protocol: Return bounty opportunity
      final coldStartResult = _createColdStartResult(label);
      _productsController.add(coldStartResult);
      return coldStartResult;
    }
  }
  
  /// Process cached products into result format
  ProductFetchResult _processProducts(
    List<CachedProduct> cached, 
    String label, 
    {bool fromCache = false}
  ) {
    // Convert to MarketplaceProducts
    final products = cached.map((cp) => MarketplaceProduct(
      productId: cp.productId,
      title: cp.entityLabel,
      vendorDid: cp.vendorDid ?? '',
      priceInr: cp.priceInr ?? 0,
      imageUrl: cp.imageUrl,
      trustScore: 0.5,
      rank: cp.cachedRank ?? 0.0,
    )).toList();
    
    // Apply ranking algorithm
    final ranked = _rankProducts(products);
    
    // Split into verified (trust >= 0.7) and global
    final verified = ranked.where((p) => p.trustScore >= 0.7).toList();
    
    // Check if Cold Start applies
    final isColdStart = ranked.isEmpty;
    
    return ProductFetchResult(
      verified: verified,
      global: ranked,
      bounties: isColdStart ? [_createDefaultBounty(label)] : [],
      fromCache: fromCache,
      isColdStart: isColdStart,
    );
  }
  
  /// Fetch mock products for development
  Future<ProductFetchResult> _fetchMockProducts(String label) async {
    debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Generating mock products for: $label');
    
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    final mockProducts = _generateMockProducts(label);
    final ranked = _rankProducts(mockProducts);
    
    final verified = ranked.where((p) => p.isVerified || p.trustScore >= 0.7).toList();
    
    // Check for Cold Start condition
    final isColdStart = ranked.isEmpty || label.toLowerCase().contains('unknown');
    
    final result = ProductFetchResult(
      verified: verified,
      global: ranked,
      bounties: _generateMockBounties(label),
      fromCache: false,
      isColdStart: isColdStart,
    );
    
    _productsController.add(result);
    debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Mock: ${ranked.length} products, ${result.bounties.length} bounties');
    return result;
  }
  
  /// Generate mock product data
  List<MarketplaceProduct> _generateMockProducts(String label) {
    final normalizedLabel = label.toUpperCase();
    
    // Generate different products based on category
    return [
      // Sponsored product (high bid)
      MarketplaceProduct(
        productId: 'mock_${label}_001',
        title: '$normalizedLabel - Premium Quality',
        description: 'Verified authentic product with warranty',
        vendorDid: 'did:satya:vendor_premium_001',
        vendorName: 'TrustMart Premium',
        priceInr: 2999,
        imageUrl: null,
        trustScore: 0.92,
        bid: 15.0,
        isSponsored: true,
        isVerified: true,
        rank: 0.0,
      ),
      // Verified product
      MarketplaceProduct(
        productId: 'mock_${label}_002',
        title: '$normalizedLabel - Standard',
        description: 'GST verified seller',
        vendorDid: 'did:satya:vendor_standard_001',
        vendorName: 'LocalShop India',
        priceInr: 1499,
        imageUrl: null,
        trustScore: 0.75,
        bid: null,
        isSponsored: false,
        isVerified: true,
        rank: 0.0,
      ),
      // Mid-tier product
      MarketplaceProduct(
        productId: 'mock_${label}_003',
        title: '$normalizedLabel - Value Pack',
        description: 'Good reviews, new seller',
        vendorDid: 'did:satya:vendor_new_001',
        vendorName: 'NewBiz Goods',
        priceInr: 999,
        imageUrl: null,
        trustScore: 0.55,
        bid: 5.0,
        isSponsored: true,
        isVerified: false,
        rank: 0.0,
      ),
      // Low trust product
      MarketplaceProduct(
        productId: 'mock_${label}_004',
        title: '$normalizedLabel - Budget Option',
        description: 'Unverified seller',
        vendorDid: 'did:satya:vendor_budget_001',
        vendorName: 'QuickSell',
        priceInr: 499,
        imageUrl: null,
        trustScore: 0.35,
        bid: null,
        isSponsored: false,
        isVerified: false,
        rank: 0.0,
      ),
      // Cold Start bounty product
      MarketplaceProduct(
        productId: 'mock_${label}_005',
        title: '$normalizedLabel - Help Verify!',
        description: 'New listing needs verification',
        vendorDid: 'did:satya:vendor_new_002',
        vendorName: 'Unknown Seller',
        priceInr: 799,
        imageUrl: null,
        trustScore: 0.1,
        bid: null,
        isSponsored: false,
        isVerified: false,
        rank: 0.0,
        isBounty: true,
      ),
    ];
  }
  
  /// Generate mock bounties (Cold Start Protocol)
  List<VerificationBounty> _generateMockBounties(String label) {
    return [
      VerificationBounty(
        entityLabel: label,
        entityId: 'bounty_${label.toLowerCase().replaceAll(' ', '_')}',
        rewardInr: 50,
        requirement: 'Take a photo and rate authenticity',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        verificationsNeeded: 10,
        currentVerifications: 3,
        sponsorName: 'SatyaSetu Community',
      ),
      VerificationBounty(
        entityLabel: '$label Quality Check',
        entityId: 'bounty_${label.toLowerCase()}_quality',
        rewardInr: 100,
        requirement: 'Verify product quality and condition',
        expiresAt: DateTime.now().add(const Duration(days: 5)),
        verificationsNeeded: 5,
        currentVerifications: 1,
        sponsorName: 'TrustMart Premium',
        sponsorDid: 'did:satya:vendor_premium_001',
      ),
    ];
  }
  
  /// Create Cold Start result with bounty opportunity
  ProductFetchResult _createColdStartResult(String label) {
    return ProductFetchResult(
      verified: [],
      global: [],
      bounties: [
        VerificationBounty(
          entityLabel: label,
          entityId: 'coldstart_${DateTime.now().millisecondsSinceEpoch}',
          rewardInr: 75,  // Higher reward for cold start
          requirement: 'Be the first to verify this item! Take photos and confirm authenticity.',
          expiresAt: DateTime.now().add(const Duration(days: 14)),
          verificationsNeeded: 5,
          currentVerifications: 0,
          sponsorName: 'SatyaSetu Cold Start Fund',
        ),
      ],
      isColdStart: true,
    );
  }
  
  /// Fetch products from the backend API
  Future<ProductFetchResult> _fetchFromNetwork(String label) async {
    debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Fetching from network...');
    
    try {
      final response = await http.post(
        Uri.parse(_searchEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': label,
          'limit': 20,
          'user_trust_graph': _trustedVendors,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Parse products from response
        final List<dynamic> results = data['results'] ?? [];
        final products = results.map((json) => 
            MarketplaceProduct.fromJson(json)).toList();
        
        // Apply ranking
        final ranked = _rankProducts(products);
        
        // Cache results
        await _cacheProducts(label, ranked);
        
        // Fetch bounties
        final bounties = await _fetchBounties(label);
        
        // Split into categories
        final verified = ranked.where((p) => p.trustScore >= 0.7).toList();
        
        final result = ProductFetchResult(
          verified: verified,
          global: ranked,
          bounties: ranked.isEmpty ? bounties : [],
          isColdStart: ranked.isEmpty,
        );
        
        _productsController.add(result);
        debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Fetched ${ranked.length} products from network');
        return result;
      } else {
        throw Exception('Network error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Network fetch failed: $e');
      
      // Fall back to mock data
      if (!_useMockData) {
        _useMockData = true;
        return await _fetchMockProducts(label);
      }
      
      return _createColdStartResult(label);
    }
  }
  
  /// Fetch bounties from backend
  Future<List<VerificationBounty>> _fetchBounties(String label) async {
    try {
      final response = await http.get(
        Uri.parse('$_bountyEndpoint?entity_label=$label'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => VerificationBounty.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Bounty fetch failed: $e');
    }
    
    return [_createDefaultBounty(label)];
  }
  
  /// Refresh products in background (non-blocking)
  Future<void> _refreshInBackground(String label) async {
    await Future.delayed(const Duration(seconds: 2));
    if (_useMockData) {
      await _fetchMockProducts(label);
    } else {
      await _fetchFromNetwork(label);
    }
  }
  
  /// Cache products in local database
  Future<void> _cacheProducts(String label, List<MarketplaceProduct> products) async {
    final expiresAt = DateTime.now().add(_cacheDuration).millisecondsSinceEpoch;
    
    final cached = products.map((p) => CachedProduct(
      productId: p.productId,
      entityLabel: label,
      vendorDid: p.vendorDid,
      priceInr: p.priceInr,
      imageUrl: p.imageUrl,
      cachedRank: p.rank,
      expiresAt: expiresAt,
    )).toList();
    
    await _db.cacheProducts(cached);
  }
  
  /// Apply Sovereign Ad Logic ranking algorithm
  /// Score = (Bid * AdvertiserTrust) + (OrganicRelevance * SocialProximity)
  List<MarketplaceProduct> _rankProducts(List<MarketplaceProduct> products) {
    return products.map((p) {
      // Calculate rank score
      final bidComponent = (p.bid ?? 0.0) * p.trustScore;
      final organicRelevance = _calculateOrganicRelevance(p);
      final socialProximity = _getSocialProximity(p.vendorDid);
      final organicComponent = organicRelevance * socialProximity;
      
      final totalScore = bidComponent + organicComponent;
      
      return MarketplaceProduct(
        productId: p.productId,
        title: p.title,
        description: p.description,
        vendorDid: p.vendorDid,
        vendorName: p.vendorName,
        priceInr: p.priceInr,
        imageUrl: p.imageUrl,
        trustScore: p.trustScore,
        bid: p.bid,
        isSponsored: p.isSponsored,
        isVerified: p.isVerified,
        rank: totalScore,
        isBounty: p.isBounty,
      );
    }).toList()
      ..sort((a, b) => b.rank.compareTo(a.rank));
  }
  
  /// Calculate organic relevance based on product attributes
  double _calculateOrganicRelevance(MarketplaceProduct p) {
    double score = 0.5; // Base score
    
    if (p.isVerified) score += 0.25;
    if (p.imageUrl != null) score += 0.1;
    if (p.description != null && p.description!.length > 50) score += 0.1;
    if (p.trustScore >= 0.7) score += 0.15;
    
    return score.clamp(0.0, 1.0);
  }
  
  /// Get social proximity (how close vendor is to user's trust network)
  double _getSocialProximity(String vendorDid) {
    // Check if vendor is in user's trusted list
    if (_trustedVendors.contains(vendorDid)) {
      return 1.0;  // Full proximity
    }
    
    // Check for partial matches (same vendor prefix)
    final vendorPrefix = vendorDid.split(':').take(3).join(':');
    if (_trustedVendors.any((v) => v.startsWith(vendorPrefix))) {
      return 0.75;  // Related vendor
    }
    
    return 0.5;  // Unknown vendor
  }
  
  /// Create a default bounty for a new/unknown entity (Cold Start)
  VerificationBounty _createDefaultBounty(String label) {
    return VerificationBounty(
      entityLabel: label,
      entityId: 'bounty_${label.toLowerCase().replaceAll(' ', '_')}',
      rewardInr: 50,
      requirement: 'Help build the trust network! Verify this item with photos and ratings.',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      verificationsNeeded: 10,
      currentVerifications: 0,
      sponsorName: 'SatyaSetu Community Fund',
    );
  }
  
  /// Dispose the service
  void dispose() {
    _objectSelectedSubscription?.cancel();
    _productsController.close();
  }
}

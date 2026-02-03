/**
 * FILE: flutter_app/lib/services/commerce_service.dart
 * VERSION: 1.0.0
 * PHASE: Phase 12 (Sovereign Commerce)
 * DESCRIPTION: 
 * Marketplace logic with local-first strategy.
 * Listens to EventBus for object selection and fetches ranked products.
 * Implements Sovereign Ad Logic: Score = (Bid * AdvertiserTrust) + (OrganicRelevance * SocialProximity)
 */

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'database_service.dart';
import 'event_bus.dart';
import 'vision_service.dart';

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
  };
}

/// Bounty for unverified entities (users can earn by verifying)
class VerificationBounty {
  final String entityLabel;
  final String entityId;
  final int rewardInr;
  final String requirement;
  final DateTime expiresAt;
  final int verificationsNeeded;
  final int currentVerifications;
  
  VerificationBounty({
    required this.entityLabel,
    required this.entityId,
    required this.rewardInr,
    required this.requirement,
    required this.expiresAt,
    required this.verificationsNeeded,
    required this.currentVerifications,
  });
  
  String get formattedReward => '₹$rewardInr';
  double get progress => currentVerifications / verificationsNeeded;
  bool get isComplete => currentVerifications >= verificationsNeeded;
  
  factory VerificationBounty.fromJson(Map<String, dynamic> json) {
    return VerificationBounty(
      entityLabel: json['entity_label'] ?? '',
      entityId: json['entity_id'] ?? '',
      rewardInr: json['reward_inr'] ?? 0,
      requirement: json['requirement'] ?? 'Take a photo of this item',
      expiresAt: DateTime.tryParse(json['expires_at'] ?? '') ?? DateTime.now().add(const Duration(days: 7)),
      verificationsNeeded: json['verifications_needed'] ?? 10,
      currentVerifications: json['current_verifications'] ?? 0,
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
  
  ProductFetchResult({
    required this.verified,
    required this.global,
    required this.bounties,
    this.fromCache = false,
    this.error,
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
  
  // Cache duration (1 hour)
  static const Duration _cacheDuration = Duration(hours: 1);
  
  StreamSubscription<SatyaEvent>? _objectSelectedSubscription;
  
  /// Current products stream
  final _productsController = StreamController<ProductFetchResult>.broadcast();
  Stream<ProductFetchResult> get productsStream => _productsController.stream;
  
  /// Initialize the commerce service
  void initialize() {
    debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Initializing service...');
    
    // Listen to object selection events
    _objectSelectedSubscription = _eventBus.on(SatyaEventType.objectSelected).listen((event) {
      final payload = event.getPayload<ObjectSelectedPayload>();
      if (payload != null) {
        fetchProducts(payload.candidate.objectLabel);
      }
    });
    
    debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Service initialized');
  }
  
  /// Fetch products for a detected object label
  /// Implements local-first strategy: check cache first, then fetch from network
  Future<ProductFetchResult> fetchProducts(String label) async {
    debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Fetching products for: $label');
    
    try {
      // Step 1: Check local cache first (offline-first)
      final cachedProducts = await _db.getCachedProducts(label);
      
      if (cachedProducts.isNotEmpty) {
        debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Found ${cachedProducts.length} cached products');
        
        final result = _processProducts(cachedProducts, label, fromCache: true);
        _productsController.add(result);
        
        // Refresh in background if cache is getting stale
        _refreshInBackground(label);
        
        return result;
      }
      
      // Step 2: Fetch from network
      return await _fetchFromNetwork(label);
      
    } catch (e) {
      debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Error: $e');
      
      final errorResult = ProductFetchResult(
        verified: [],
        global: [],
        bounties: [_createDefaultBounty(label)],
        error: e.toString(),
      );
      _productsController.add(errorResult);
      return errorResult;
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
    final global = ranked;
    
    return ProductFetchResult(
      verified: verified,
      global: global,
      bounties: [_createDefaultBounty(label)],
      fromCache: fromCache,
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
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // Parse products
        final products = data.map((json) => MarketplaceProduct.fromJson(json)).toList();
        
        // Apply ranking
        final ranked = _rankProducts(products);
        
        // Cache results
        await _cacheProducts(label, ranked);
        
        // Split into categories
        final verified = ranked.where((p) => p.trustScore >= 0.7).toList();
        
        final result = ProductFetchResult(
          verified: verified,
          global: ranked,
          bounties: ranked.isEmpty ? [_createDefaultBounty(label)] : [],
        );
        
        _productsController.add(result);
        debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Fetched ${ranked.length} products from network');
        return result;
      } else {
        throw Exception('Network error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('flutter: SATYA_DEBUG: [COMMERCE] Network fetch failed: $e');
      
      // Return empty results with bounty opportunity
      final result = ProductFetchResult(
        verified: [],
        global: [],
        bounties: [_createDefaultBounty(label)],
        error: e.toString(),
      );
      
      _productsController.add(result);
      return result;
    }
  }
  
  /// Refresh products in background (non-blocking)
  Future<void> _refreshInBackground(String label) async {
    // Delay to avoid hitting API immediately after cache hit
    await Future.delayed(const Duration(seconds: 2));
    await _fetchFromNetwork(label);
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
      final organicComponent = _calculateOrganicRelevance(p) * _getSocialProximity(p.vendorDid);
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
      );
    }).toList()
      ..sort((a, b) => b.rank.compareTo(a.rank));
  }
  
  /// Calculate organic relevance based on product attributes
  double _calculateOrganicRelevance(MarketplaceProduct p) {
    double score = 0.5; // Base score
    
    if (p.isVerified) score += 0.2;
    if (p.imageUrl != null) score += 0.1;
    if (p.description != null && p.description!.length > 50) score += 0.1;
    
    return score.clamp(0.0, 1.0);
  }
  
  /// Get social proximity (how close is this vendor to user's trust network)
  /// TODO: Implement based on actual trust graph in Phase 13
  double _getSocialProximity(String vendorDid) {
    // Placeholder - in full implementation, query trust graph for connections
    return 0.5;
  }
  
  /// Create a default bounty for a new/unknown entity
  VerificationBounty _createDefaultBounty(String label) {
    return VerificationBounty(
      entityLabel: label,
      entityId: 'bounty_${label.toLowerCase().replaceAll(' ', '_')}',
      rewardInr: 50, // ₹50 reward for verification
      requirement: 'Help verify this item by taking photos and rating authenticity',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      verificationsNeeded: 10,
      currentVerifications: 0,
    );
  }
  
  /// Dispose the service
  void dispose() {
    _objectSelectedSubscription?.cancel();
    _productsController.close();
  }
}

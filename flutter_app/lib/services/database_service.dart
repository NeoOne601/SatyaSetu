/**
 * FILE: flutter_app/lib/services/database_service.dart
 * VERSION: 1.0.0
 * PHASE: Phase 11 (The Cortex - Local Persistence)
 * DESCRIPTION: 
 * Singleton service for local SQLite "Cortex" database.
 * Stores Trust Graph (entities + interactions) and offline product cache.
 * Implements offline-first strategy for the Sovereign Spatial Marketplace.
 */

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Represents an entity in the Trust Graph
class TrustEntity {
  final String id;
  final String label;
  final double trustScore;
  final String? geohash;
  final int lastSeen;

  TrustEntity({
    required this.id,
    required this.label,
    required this.trustScore,
    this.geohash,
    required this.lastSeen,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'trust_score': trustScore,
    'geohash': geohash,
    'last_seen': lastSeen,
  };

  factory TrustEntity.fromMap(Map<String, dynamic> map) => TrustEntity(
    id: map['id'] as String,
    label: map['label'] as String,
    trustScore: (map['trust_score'] as num).toDouble(),
    geohash: map['geohash'] as String?,
    lastSeen: map['last_seen'] as int,
  );
}

/// Represents an interaction record (signed proof of action)
class InteractionRecord {
  final int? id;
  final String entityId;
  final String actionType;
  final int? rating;
  final String? signature;
  final int timestamp;

  InteractionRecord({
    this.id,
    required this.entityId,
    required this.actionType,
    this.rating,
    this.signature,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'entity_id': entityId,
    'action_type': actionType,
    'rating': rating,
    'signature': signature,
    'timestamp': timestamp,
  };

  factory InteractionRecord.fromMap(Map<String, dynamic> map) => InteractionRecord(
    id: map['id'] as int?,
    entityId: map['entity_id'] as String,
    actionType: map['action_type'] as String,
    rating: map['rating'] as int?,
    signature: map['signature'] as String?,
    timestamp: map['timestamp'] as int,
  );
}

/// Cached product from marketplace search
class CachedProduct {
  final String productId;
  final String entityLabel;
  final String? vendorDid;
  final int? priceInr;
  final String? imageUrl;
  final double? cachedRank;
  final int expiresAt;

  CachedProduct({
    required this.productId,
    required this.entityLabel,
    this.vendorDid,
    this.priceInr,
    this.imageUrl,
    this.cachedRank,
    required this.expiresAt,
  });

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'entity_label': entityLabel,
    'vendor_did': vendorDid,
    'price_inr': priceInr,
    'image_url': imageUrl,
    'cached_rank': cachedRank,
    'expires_at': expiresAt,
  };

  factory CachedProduct.fromMap(Map<String, dynamic> map) => CachedProduct(
    productId: map['product_id'] as String,
    entityLabel: map['entity_label'] as String,
    vendorDid: map['vendor_did'] as String?,
    priceInr: map['price_inr'] as int?,
    imageUrl: map['image_url'] as String?,
    cachedRank: map['cached_rank'] != null ? (map['cached_rank'] as num).toDouble() : null,
    expiresAt: map['expires_at'] as int,
  );

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;
}

/// Singleton Database Service for the Local Cortex
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static const String _dbName = 'satya_cortex.db';
  static const int _dbVersion = 1;
  static const _uuid = Uuid();

  /// Get or initialize the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the SQLite database with Trust Graph schema
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    
    debugPrint('flutter: SATYA_DEBUG: [CORTEX] Initializing database at: $path');
    
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database schema
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('flutter: SATYA_DEBUG: [CORTEX] Creating Trust Graph schema v$version');
    
    // ENTITIES: Physical objects seen by the camera
    await db.execute('''
      CREATE TABLE entities (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        trust_score REAL DEFAULT 0.5,
        geohash TEXT,
        last_seen INTEGER NOT NULL
      )
    ''');
    
    // Create index for geohash spatial lookups
    await db.execute('CREATE INDEX idx_entities_geohash ON entities(geohash)');
    await db.execute('CREATE INDEX idx_entities_label ON entities(label)');
    
    // INTERACTIONS: User actions on entities
    await db.execute('''
      CREATE TABLE interactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_id TEXT NOT NULL,
        action_type TEXT NOT NULL,
        rating INTEGER,
        signature TEXT,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (entity_id) REFERENCES entities(id)
      )
    ''');
    
    await db.execute('CREATE INDEX idx_interactions_entity ON interactions(entity_id)');
    await db.execute('CREATE INDEX idx_interactions_timestamp ON interactions(timestamp DESC)');
    
    // PRODUCTS_CACHE: Cached marketplace results
    await db.execute('''
      CREATE TABLE products_cache (
        product_id TEXT PRIMARY KEY,
        entity_label TEXT NOT NULL,
        vendor_did TEXT,
        price_inr INTEGER,
        image_url TEXT,
        cached_rank REAL,
        expires_at INTEGER NOT NULL
      )
    ''');
    
    await db.execute('CREATE INDEX idx_products_label ON products_cache(entity_label)');
    await db.execute('CREATE INDEX idx_products_expires ON products_cache(expires_at)');
    
    debugPrint('flutter: SATYA_DEBUG: [CORTEX] Schema created successfully');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('flutter: SATYA_DEBUG: [CORTEX] Upgrading from v$oldVersion to v$newVersion');
    // Future migrations go here
  }

  // ============================================================
  // ENTITY OPERATIONS
  // ============================================================

  /// Generate a deterministic entity ID from label and geohash
  String _generateEntityId(String label, String? geohash) {
    final input = '${label.toLowerCase().trim()}|${geohash ?? 'unknown'}';
    // Simple hash - in production, use a proper hash function
    final hashCode = input.hashCode.abs().toRadixString(16);
    return 'entity_$hashCode';
  }

  /// Remember an entity (insert or update on detection)
  Future<TrustEntity> rememberEntity(String label, {String? geohash}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final entityId = _generateEntityId(label, geohash);
    
    // Check if entity exists
    final existing = await db.query(
      'entities',
      where: 'id = ?',
      whereArgs: [entityId],
      limit: 1,
    );
    
    if (existing.isNotEmpty) {
      // Update last_seen timestamp
      await db.update(
        'entities',
        {'last_seen': now},
        where: 'id = ?',
        whereArgs: [entityId],
      );
      
      final updated = TrustEntity.fromMap(existing.first).copyWith(lastSeen: now);
      debugPrint('flutter: SATYA_DEBUG: [CORTEX] Updated entity: ${updated.label} (trust: ${updated.trustScore})');
      return updated;
    } else {
      // Insert new entity with neutral trust score
      final entity = TrustEntity(
        id: entityId,
        label: label,
        trustScore: 0.5, // Neutral starting trust
        geohash: geohash,
        lastSeen: now,
      );
      
      await db.insert('entities', entity.toMap());
      debugPrint('flutter: SATYA_DEBUG: [CORTEX] Remembered new entity: ${entity.label}');
      return entity;
    }
  }

  /// Get trust score for an entity (returns null if not found)
  Future<double?> getTrustScore(String entityId) async {
    final db = await database;
    final results = await db.query(
      'entities',
      columns: ['trust_score'],
      where: 'id = ?',
      whereArgs: [entityId],
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    return (results.first['trust_score'] as num).toDouble();
  }

  /// Get trust score by label (for quick lookups)
  Future<double> getTrustScoreByLabel(String label, {String? geohash}) async {
    final entityId = _generateEntityId(label, geohash);
    return await getTrustScore(entityId) ?? 0.5; // Default neutral
  }

  /// Get entity by ID
  Future<TrustEntity?> getEntity(String entityId) async {
    final db = await database;
    final results = await db.query(
      'entities',
      where: 'id = ?',
      whereArgs: [entityId],
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    return TrustEntity.fromMap(results.first);
  }

  // ============================================================
  // INTERACTION OPERATIONS
  // ============================================================

  /// Record an interaction (signed proof of action)
  Future<InteractionRecord> recordInteraction({
    required String entityId,
    required String actionType,
    int? rating,
    String? signature,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final record = InteractionRecord(
      entityId: entityId,
      actionType: actionType,
      rating: rating,
      signature: signature,
      timestamp: now,
    );
    
    final id = await db.insert('interactions', record.toMap());
    
    // Update entity trust score based on interaction
    await _updateTrustScore(entityId, actionType, rating);
    
    debugPrint('flutter: SATYA_DEBUG: [CORTEX] Recorded interaction: $actionType on $entityId');
    return InteractionRecord(
      id: id,
      entityId: entityId,
      actionType: actionType,
      rating: rating,
      signature: signature,
      timestamp: now,
    );
  }

  /// Update trust score based on interaction type and rating
  Future<void> _updateTrustScore(String entityId, String actionType, int? rating) async {
    final db = await database;
    final entity = await getEntity(entityId);
    if (entity == null) return;
    
    double delta = 0.0;
    
    switch (actionType.toUpperCase()) {
      case 'VERIFY':
        delta = 0.1; // Verification increases trust
        break;
      case 'RATE':
        if (rating != null) {
          // Rating affects trust: 5 stars = +0.1, 1 star = -0.1
          delta = (rating - 3) * 0.05;
        }
        break;
      case 'BUY':
        delta = 0.05; // Purchase indicates trust
        break;
      case 'REPORT':
        delta = -0.15; // Report decreases trust
        break;
    }
    
    // Clamp trust score between 0.0 and 1.0
    final newScore = (entity.trustScore + delta).clamp(0.0, 1.0);
    
    await db.update(
      'entities',
      {'trust_score': newScore},
      where: 'id = ?',
      whereArgs: [entityId],
    );
    
    debugPrint('flutter: SATYA_DEBUG: [CORTEX] Trust updated: ${entity.label} ${entity.trustScore.toStringAsFixed(2)} → ${newScore.toStringAsFixed(2)}');
  }

  /// Get interaction history for an entity
  Future<List<InteractionRecord>> getInteractionHistory(String entityId, {int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'interactions',
      where: 'entity_id = ?',
      whereArgs: [entityId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return results.map((m) => InteractionRecord.fromMap(m)).toList();
  }

  // ============================================================
  // PRODUCTS CACHE OPERATIONS
  // ============================================================

  /// Cache a product from marketplace search
  Future<void> cacheProduct(CachedProduct product) async {
    final db = await database;
    await db.insert(
      'products_cache',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Cache multiple products at once
  Future<void> cacheProducts(List<CachedProduct> products) async {
    final db = await database;
    final batch = db.batch();
    
    for (final product in products) {
      batch.insert(
        'products_cache',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    debugPrint('flutter: SATYA_DEBUG: [CORTEX] Cached ${products.length} products');
  }

  /// Get cached products for an entity label
  Future<List<CachedProduct>> getCachedProducts(String entityLabel, {bool includeFresh = true}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    String whereClause = 'entity_label = ?';
    List<Object?> whereArgs = [entityLabel];
    
    if (includeFresh) {
      whereClause += ' AND expires_at > ?';
      whereArgs.add(now);
    }
    
    final results = await db.query(
      'products_cache',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'cached_rank DESC',
    );
    
    return results.map((m) => CachedProduct.fromMap(m)).toList();
  }

  /// Clear expired product cache entries
  Future<int> clearExpiredCache() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final deleted = await db.delete(
      'products_cache',
      where: 'expires_at < ?',
      whereArgs: [now],
    );
    
    if (deleted > 0) {
      debugPrint('flutter: SATYA_DEBUG: [CORTEX] Cleared $deleted expired cache entries');
    }
    return deleted;
  }

  // ============================================================
  // TRUST GRAPH OPERATIONS
  // ============================================================

  /// Get the complete Trust Graph (all entities with trust scores)
  Future<List<TrustEntity>> getTrustGraph({int limit = 100}) async {
    final db = await database;
    final results = await db.query(
      'entities',
      orderBy: 'trust_score DESC, last_seen DESC',
      limit: limit,
    );
    
    return results.map((m) => TrustEntity.fromMap(m)).toList();
  }

  /// Get entities by geohash prefix (spatial query)
  Future<List<TrustEntity>> getEntitiesNear(String geohashPrefix) async {
    final db = await database;
    final results = await db.query(
      'entities',
      where: 'geohash LIKE ?',
      whereArgs: ['$geohashPrefix%'],
      orderBy: 'trust_score DESC',
    );
    
    return results.map((m) => TrustEntity.fromMap(m)).toList();
  }

  /// Get recently seen entities
  Future<List<TrustEntity>> getRecentEntities({int limit = 20}) async {
    final db = await database;
    final results = await db.query(
      'entities',
      orderBy: 'last_seen DESC',
      limit: limit,
    );
    
    return results.map((m) => TrustEntity.fromMap(m)).toList();
  }

  /// Get high-trust entities (for "Verified" tab)
  Future<List<TrustEntity>> getTrustedEntities({double minTrust = 0.7, int limit = 20}) async {
    final db = await database;
    final results = await db.query(
      'entities',
      where: 'trust_score >= ?',
      whereArgs: [minTrust],
      orderBy: 'trust_score DESC',
      limit: limit,
    );
    
    return results.map((m) => TrustEntity.fromMap(m)).toList();
  }

  // ============================================================
  // DIAGNOSTICS & MAINTENANCE
  // ============================================================

  /// Get database statistics
  Future<Map<String, int>> getStats() async {
    final db = await database;
    
    final entities = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM entities')) ?? 0;
    final interactions = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM interactions')) ?? 0;
    final cached = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products_cache')) ?? 0;
    
    return {
      'entities': entities,
      'interactions': interactions,
      'cached_products': cached,
    };
  }

  /// Close the database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

/// Extension for TrustEntity copyWith
extension TrustEntityCopyWith on TrustEntity {
  TrustEntity copyWith({
    String? id,
    String? label,
    double? trustScore,
    String? geohash,
    int? lastSeen,
  }) {
    return TrustEntity(
      id: id ?? this.id,
      label: label ?? this.label,
      trustScore: trustScore ?? this.trustScore,
      geohash: geohash ?? this.geohash,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

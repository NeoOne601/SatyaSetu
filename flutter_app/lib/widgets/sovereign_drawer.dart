/**
 * FILE: flutter_app/lib/widgets/sovereign_drawer.dart
 * VERSION: 1.0.0
 * PHASE: Phase 12 (Sovereign Commerce)
 * DESCRIPTION: 
 * The "Reactive Drawer" - DraggableScrollableSheet overlay for commerce discovery.
 * State 1 (Peek 40%): Object title, trust badge, quick actions
 * State 2 (Market 90%): Tabbed ListView with Verified, Global, Bounties tabs
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/event_bus.dart';
import '../services/commerce_service.dart';
import '../services/database_service.dart';
import '../services/vision_service.dart';

/// Trust color palette from the Master Blueprint
class TrustColors {
  static const Color trusted = Color(0xFF00FFC8);      // Neon Teal - Trusted/Safe
  static const Color promoted = Color(0xFFFFD700);     // Gold - Promoted/Sponsored
  static const Color untrusted = Color(0xFFFF0055);    // Red - Malicious/Untrusted
  static const Color bounty = Color(0xFF0088FF);       // Blue - Bounty Active
  static const Color neutral = Color(0xFF888888);      // Gray - Unknown/Neutral
  
  /// Get color based on trust score
  static Color forScore(double score) {
    if (score >= 0.8) return trusted;
    if (score >= 0.6) return trusted.withOpacity(0.7);
    if (score >= 0.4) return neutral;
    if (score >= 0.2) return untrusted.withOpacity(0.7);
    return untrusted;
  }
  
  /// Get color for product based on attributes
  static Color forProduct(MarketplaceProduct product) {
    if (product.isSponsored) return promoted;
    if (product.isVerified) return trusted;
    return forScore(product.trustScore);
  }
}

/// The Sovereign Drawer widget - main commerce interface
class SovereignDrawer extends StatefulWidget {
  final DetectionCandidate candidate;
  final VoidCallback onClose;
  final VisionService visionService;
  
  const SovereignDrawer({
    super.key,
    required this.candidate,
    required this.onClose,
    required this.visionService,
  });

  @override
  State<SovereignDrawer> createState() => _SovereignDrawerState();
}

class _SovereignDrawerState extends State<SovereignDrawer> 
    with SingleTickerProviderStateMixin {
  
  final DraggableScrollableController _draggableController = DraggableScrollableController();
  final CommerceService _commerce = CommerceService();
  final EventBus _eventBus = EventBus();
  
  ProductFetchResult? _products;
  bool _isLoading = true;
  String? _error;
  int _selectedTabIndex = 0;
  
  // Drawer extent thresholds
  static const double _peekExtent = 0.4;
  static const double _marketExtent = 0.9;
  static const double _minExtent = 0.15;
  
  StreamSubscription<ProductFetchResult>? _productsSub;
  
  @override
  void initState() {
    super.initState();
    
    // Pause camera when drawer opens
    widget.visionService.pause();
    _eventBus.emit(SatyaEventType.drawerOpened, widget.candidate.objectLabel);
    
    // Listen to products stream
    _productsSub = _commerce.productsStream.listen((result) {
      if (mounted) {
        setState(() {
          _products = result;
          _isLoading = false;
          _error = result.error;
        });
      }
    });
    
    // Fetch products for this object
    _fetchProducts();
    
    // Listen to drawer extent changes
    _draggableController.addListener(_onExtentChanged);
  }
  
  void _onExtentChanged() {
    final extent = _draggableController.size;
    if (extent >= 0.7) {
      _eventBus.emitDrawerState(
        SatyaEventType.drawerExpanded, 
        extent, 
        objectLabel: widget.candidate.objectLabel,
      );
    } else if (extent <= 0.5) {
      _eventBus.emitDrawerState(
        SatyaEventType.drawerCollapsed, 
        extent, 
        objectLabel: widget.candidate.objectLabel,
      );
    }
  }
  
  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    await _commerce.fetchProducts(widget.candidate.objectLabel);
  }
  
  void _handleClose() {
    widget.visionService.resume();
    _eventBus.emit(SatyaEventType.drawerClosed);
    widget.onClose();
  }
  
  Future<void> _handleVerify() async {
    final db = DatabaseService();
    await db.recordInteraction(
      entityId: widget.candidate.id,
      actionType: 'VERIFY',
    );
    _eventBus.emit(SatyaEventType.verifyAction, widget.candidate);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(LucideIcons.check, color: Colors.black, size: 18),
            const SizedBox(width: 8),
            Text('Verified ${widget.candidate.objectLabel}'),
          ]),
          backgroundColor: TrustColors.trusted,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  Future<void> _handleReport() async {
    final db = DatabaseService();
    await db.recordInteraction(
      entityId: widget.candidate.id,
      actionType: 'REPORT',
    );
    _eventBus.emit(SatyaEventType.reportAction, widget.candidate);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(LucideIcons.alertTriangle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Report submitted'),
          ]),
          backgroundColor: TrustColors.untrusted,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _productsSub?.cancel();
    _draggableController.removeListener(_onExtentChanged);
    _draggableController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _draggableController,
      initialChildSize: _peekExtent,
      minChildSize: _minExtent,
      maxChildSize: _marketExtent,
      snap: true,
      snapSizes: const [_peekExtent, _marketExtent],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: TrustColors.forScore(widget.candidate.trustScore).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              _buildDragHandle(),
              
              // Header (always visible)
              _buildHeader(),
              
              // Expandable Content
              Expanded(
                child: AnimatedBuilder(
                  animation: _draggableController,
                  builder: (context, child) {
                    final extent = _draggableController.isAttached 
                        ? _draggableController.size 
                        : _peekExtent;
                    
                    // Show peek view or full market view based on extent
                    if (extent < 0.6) {
                      return _buildPeekView(scrollController);
                    } else {
                      return _buildMarketView(scrollController);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildDragHandle() {
    return GestureDetector(
      onTap: _handleClose,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    final trustColor = TrustColors.forScore(widget.candidate.trustScore);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          // Trust Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: trustColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: trustColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.candidate.isTrusted ? LucideIcons.shieldCheck : LucideIcons.shield,
                  color: trustColor,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.candidate.trustPercentage}%',
                  style: TextStyle(
                    color: trustColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Object Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.candidate.objectLabel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.candidate.trustLevel,
                  style: TextStyle(
                    fontSize: 10,
                    color: trustColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Close Button
          IconButton(
            onPressed: _handleClose,
            icon: const Icon(LucideIcons.x, color: Colors.white54),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPeekView(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        // Quick Actions
        _buildQuickActions(),
        
        const SizedBox(height: 16),
        
        // Loading State
        if (_isLoading)
          _buildLoadingIndicator()
        else if (_error != null)
          _buildErrorState()
        else
          _buildPeekProducts(),
      ],
    );
  }
  
  Widget _buildQuickActions() {
    return Row(
      children: [
        // Verify Button
        Expanded(
          child: _QuickActionButton(
            icon: LucideIcons.check,
            label: 'VERIFY',
            color: TrustColors.trusted,
            onTap: _handleVerify,
          ),
        ),
        const SizedBox(width: 12),
        // Report Button
        Expanded(
          child: _QuickActionButton(
            icon: LucideIcons.alertTriangle,
            label: 'REPORT',
            color: TrustColors.untrusted,
            onTap: _handleReport,
          ),
        ),
      ],
    );
  }
  
  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        const SizedBox(height: 32),
        CircularProgressIndicator(
          color: TrustColors.forScore(widget.candidate.trustScore),
          strokeWidth: 2,
        ),
        const SizedBox(height: 16),
        const Text(
          'Searching Decentralized Graph...',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildErrorState() {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Icon(LucideIcons.wifiOff, color: Colors.white24, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Network unavailable',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _fetchProducts,
          child: const Text('Retry'),
        ),
      ],
    );
  }
  
  Widget _buildPeekProducts() {
    final products = _products?.global ?? [];
    if (products.isEmpty && (_products?.bounties.isNotEmpty ?? false)) {
      return _buildBountyCard(_products!.bounties.first);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${products.length} results found',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 12),
        ...products.take(3).map((p) => _ProductCard(product: p)),
        if (products.length > 3)
          Center(
            child: TextButton.icon(
              onPressed: () {
                _draggableController.animateTo(
                  _marketExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              icon: const Icon(LucideIcons.chevronUp, size: 16),
              label: Text('View all ${products.length} results'),
            ),
          ),
      ],
    );
  }
  
  Widget _buildBountyCard(VerificationBounty bounty) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TrustColors.bounty.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TrustColors.bounty.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TrustColors.bounty.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.gift, color: TrustColors.bounty, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VERIFICATION BOUNTY',
                      style: TextStyle(
                        color: TrustColors.bounty,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Earn ${bounty.formattedReward}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bounty.requirement,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: bounty.progress,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(TrustColors.bounty),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${bounty.currentVerifications}/${bounty.verificationsNeeded} verifications',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMarketView(ScrollController scrollController) {
    return Column(
      children: [
        // Tab Bar
        _buildTabBar(),
        
        const Divider(height: 1, color: Colors.white10),
        
        // Tab Content
        Expanded(
          child: IndexedStack(
            index: _selectedTabIndex,
            children: [
              _buildProductList(scrollController, _products?.verified ?? []),
              _buildProductList(scrollController, _products?.global ?? []),
              _buildBountyList(scrollController, _products?.bounties ?? []),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _TabButton(
            label: 'Verified',
            count: _products?.verified.length ?? 0,
            isSelected: _selectedTabIndex == 0,
            color: TrustColors.trusted,
            onTap: () => setState(() => _selectedTabIndex = 0),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: 'Global',
            count: _products?.global.length ?? 0,
            isSelected: _selectedTabIndex == 1,
            color: Colors.white,
            onTap: () => setState(() => _selectedTabIndex = 1),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: 'Bounties',
            count: _products?.bounties.length ?? 0,
            isSelected: _selectedTabIndex == 2,
            color: TrustColors.bounty,
            onTap: () => setState(() => _selectedTabIndex = 2),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProductList(ScrollController controller, List<MarketplaceProduct> products) {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'No products found',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
    
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) => _ProductCard(product: products[index]),
    );
  }
  
  Widget _buildBountyList(ScrollController controller, List<VerificationBounty> bounties) {
    if (bounties.isEmpty) {
      return const Center(
        child: Text(
          'No bounties available',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
    
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: bounties.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildBountyCard(bounties[index]),
      ),
    );
  }
}

// ============================================================
// HELPER WIDGETS
// ============================================================

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  
  const _TabButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? color : Colors.white54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                if (count > 0)
                  Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? color : Colors.white24,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final MarketplaceProduct product;
  
  const _ProductCard({required this.product});
  
  @override
  Widget build(BuildContext context) {
    final borderColor = TrustColors.forProduct(product);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Product Image Placeholder
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
              image: product.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(product.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: product.imageUrl == null
                ? const Icon(LucideIcons.package, color: Colors.white24, size: 24)
                : null,
          ),
          
          const SizedBox(width: 12),
          
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (product.isSponsored)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: TrustColors.promoted.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PROMOTED',
                          style: TextStyle(
                            color: TrustColors.promoted,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (product.isVerified)
                      const Icon(LucideIcons.badgeCheck, color: TrustColors.trusted, size: 14),
                  ],
                ),
                Text(
                  product.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      product.formattedPrice,
                      style: const TextStyle(
                        color: TrustColors.trusted,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    // Trust score
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.trustBadge,
                        style: TextStyle(
                          color: borderColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Action arrow
          const Icon(LucideIcons.chevronRight, color: Colors.white24, size: 20),
        ],
      ),
    );
  }
}

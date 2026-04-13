import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pawgo/config/env.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/services/walker_service.dart';
import 'package:pawgo/services/geocoding_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AdvancedFilters {
  final double? maxDistanceKm;
  final double? minRate;
  final double? maxRate;
  final int? minExperience;
  final bool? backgroundChecked;

  const AdvancedFilters({
    this.maxDistanceKm,
    this.minRate,
    this.maxRate,
    this.minExperience,
    this.backgroundChecked,
  });

  int get activeCount {
    int count = 0;
    if (maxDistanceKm != null) count++;
    if (minRate != null || maxRate != null) count++;
    if (minExperience != null) count++;
    if (backgroundChecked == true) count++;
    return count;
  }

  bool get hasActiveFilters => activeCount > 0;
}

class FindScreen extends StatefulWidget {
  const FindScreen({super.key});

  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  String _selectedFilter = 'all';
  List<Walker> _walkers = [];
  bool _isLoading = true;
  String? _error;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<GeocodingSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  GeocodingSuggestion? _selectedLocation;
  Timer? _debounceTimer;

  // Advanced filters
  AdvancedFilters _advancedFilters = const AdvancedFilters();

  late final GeocodingService _geocodingService;

  @override
  void initState() {
    super.initState();
    _geocodingService = GeocodingService(
      accessToken: Env.current.mapboxAccessToken,
    );
    _loadWalkers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWalkers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final walkers = await WalkerService.fetchWalkers(
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
      );
      if (mounted) {
        setState(() {
          _walkers = walkers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load walkers. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _geocodingService.autocomplete(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
        });
      }
    });
  }

  void _onSuggestionSelected(GeocodingSuggestion suggestion) {
    setState(() {
      _selectedLocation = suggestion;
      _searchController.text = suggestion.placeName;
      _suggestions = [];
      _showSuggestions = false;
    });
    _searchFocusNode.unfocus();
    _loadWalkers();
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _selectedLocation = null;
      _suggestions = [];
      _showSuggestions = false;
    });
    _loadWalkers();
  }

  List<Walker> get _filteredWalkers {
    List<Walker> result;
    switch (_selectedFilter) {
      case 'available':
        result = _walkers.where((w) => w.isEnabled).toList();
      case 'top-rated':
        result = _walkers.where((w) => w.rating >= 4.5).toList();
        result.sort((a, b) => b.rating.compareTo(a.rating));
      default:
        result = List.of(_walkers);
    }
    return _applyAdvancedFilters(result);
  }

  List<Walker> _applyAdvancedFilters(List<Walker> walkers) {
    if (!_advancedFilters.hasActiveFilters) return walkers;
    var result = walkers;
    if (_advancedFilters.minRate != null) {
      result = result
          .where((w) => w.hourlyRateMxn >= _advancedFilters.minRate!)
          .toList();
    }
    if (_advancedFilters.maxRate != null) {
      result = result
          .where((w) => w.hourlyRateMxn <= _advancedFilters.maxRate!)
          .toList();
    }
    if (_advancedFilters.minExperience != null) {
      result = result
          .where((w) => w.experienceYears >= _advancedFilters.minExperience!)
          .toList();
    }
    if (_advancedFilters.backgroundChecked == true) {
      result = result.where((w) => w.backgroundChecked).toList();
    }
    return result;
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AdvancedFiltersSheet(
        current: _advancedFilters,
        onApply: (filters) {
          setState(() => _advancedFilters = filters);
          Navigator.pop(context);
        },
        onReset: () {
          setState(() => _advancedFilters = const AdvancedFilters());
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Find a Walker',
                      style: GoogleFonts.nunito(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/illustrations/corgi_wagging.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search Bar
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor ??
                      AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                        size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search by address or zip code',
                          hintStyle: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: _clearSearch,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(PhosphorIcons.x(),
                              size: 18, color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Filters
              Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 12),
                  _FilterChip(
                    label: 'Available',
                    isSelected: _selectedFilter == 'available',
                    onTap: () => setState(() => _selectedFilter = 'available'),
                  ),
                  const SizedBox(width: 12),
                  _FilterChip(
                    label: 'Top Rated',
                    isSelected: _selectedFilter == 'top-rated',
                    onTap: () => setState(() => _selectedFilter = 'top-rated'),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showAdvancedFilters,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(PhosphorIcons.sliders(),
                              size: 18, color: AppColors.textSecondary),
                        ),
                        if (_advancedFilters.hasActiveFilters)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: AppColors.orange500,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${_advancedFilters.activeCount}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Autocomplete suggestions overlay
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _suggestions.map((suggestion) {
                return InkWell(
                  onTap: () => _onSuggestionSelected(suggestion),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.mapPin(),
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            suggestion.placeName,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        // Results Count
        if (!_isLoading && _error == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              '${_filteredWalkers.length} walker${_filteredWalkers.length != 1 ? 's' : ''} nearby',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        // Content area: loading / error / empty / list
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orange500),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.wifiSlash(),
                  size: 48, color: AppColors.gray400),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _loadWalkers,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.orange500,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredWalkers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.pawPrint(),
                  size: 56, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 14),
              Text(
                'No walkers found nearby',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters or check back later',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: _filteredWalkers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        final walker = _filteredWalkers[index];
        return _WalkerCard(walker: walker);
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orange500 : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _WalkerCard extends StatelessWidget {
  final Walker walker;

  const _WalkerCard({required this.walker});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/walker', arguments: walker.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.orange400, AppColors.orange500],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: walker.avatarUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                walker.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text('\u{1F6B6}',
                                      style: TextStyle(fontSize: 30)),
                                ),
                              ),
                            )
                          : const Center(
                              child: Text('\u{1F6B6}',
                                  style: TextStyle(fontSize: 30)),
                            ),
                    ),
                    if (walker.backgroundChecked)
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.blue500,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                              PhosphorIcons.shield(PhosphorIconsStyle.fill),
                              color: Colors.white,
                              size: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              walker.name,
                              style: GoogleFonts.nunito(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (walker.backgroundChecked) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.green100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      PhosphorIcons.shield(
                                          PhosphorIconsStyle.fill),
                                      size: 10,
                                      color: AppColors.green600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.green700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                              size: 14, color: AppColors.orange500),
                          const SizedBox(width: 4),
                          Text(
                            walker.displayRating,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${walker.totalWalks} walks',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      walker.displayPrice,
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'per walk',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats Row
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.borderLight),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.purple100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('\u{1F6B6}', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${walker.totalWalks}',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    ' walks',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.blue100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('\u{26A1}', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    walker.displayExperience,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Bio preview & availability
            Row(
              children: [
                if (walker.bio != null && walker.bio!.isNotEmpty)
                  Expanded(
                    child: Text(
                      walker.bio!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: walker.isEnabled
                            ? AppColors.green500
                            : AppColors.gray400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      walker.isEnabled ? 'Available' : 'Unavailable',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: walker.isEnabled
                            ? AppColors.green600
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedFiltersSheet extends StatefulWidget {
  final AdvancedFilters current;
  final ValueChanged<AdvancedFilters> onApply;
  final VoidCallback onReset;

  const _AdvancedFiltersSheet({
    required this.current,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_AdvancedFiltersSheet> createState() => _AdvancedFiltersSheetState();
}

class _AdvancedFiltersSheetState extends State<_AdvancedFiltersSheet> {
  late double _distanceKm;
  late RangeValues _priceRange;
  late int _minExperience;
  late bool _bgChecked;
  late bool _distanceEnabled;

  @override
  void initState() {
    super.initState();
    _distanceKm = widget.current.maxDistanceKm ?? 10;
    _distanceEnabled = widget.current.maxDistanceKm != null;
    _priceRange = RangeValues(
      widget.current.minRate ?? 50,
      widget.current.maxRate ?? 500,
    );
    _minExperience = widget.current.minExperience ?? 0;
    _bgChecked = widget.current.backgroundChecked ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Advanced Filters',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Distance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distance Radius',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _distanceEnabled ? '${_distanceKm.round()} km' : 'Any',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Slider(
              value: _distanceKm,
              min: 1,
              max: 50,
              divisions: 49,
              activeColor: AppColors.orange500,
              onChanged: (v) => setState(() {
                _distanceKm = v;
                _distanceEnabled = true;
              }),
            ),
            const SizedBox(height: 12),

            // Price Range
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Price Range',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '\$${_priceRange.start.round()} - \$${_priceRange.end.round()}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            RangeSlider(
              values: _priceRange,
              min: 50,
              max: 500,
              divisions: 45,
              activeColor: AppColors.orange500,
              onChanged: (v) => setState(() => _priceRange = v),
            ),
            const SizedBox(height: 12),

            // Experience
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Minimum Experience',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                DropdownButton<int>(
                  value: _minExperience,
                  underline: const SizedBox(),
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  items: List.generate(11, (i) => i).map((yr) {
                    return DropdownMenuItem(
                      value: yr,
                      child: Text(yr == 0 ? 'Any' : '$yr+ years'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _minExperience = v ?? 0),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Background Checked
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Background Checked',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Switch(
                  value: _bgChecked,
                  activeColor: AppColors.orange500,
                  onChanged: (v) => setState(() => _bgChecked = v),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onReset,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gray400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Reset',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      widget.onApply(AdvancedFilters(
                        maxDistanceKm:
                            _distanceEnabled ? _distanceKm : null,
                        minRate: _priceRange.start > 50
                            ? _priceRange.start
                            : null,
                        maxRate: _priceRange.end < 500
                            ? _priceRange.end
                            : null,
                        minExperience:
                            _minExperience > 0 ? _minExperience : null,
                        backgroundChecked: _bgChecked ? true : null,
                      ));
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.orange500,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Apply',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

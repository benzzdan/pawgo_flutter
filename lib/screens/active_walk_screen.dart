import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/services/tracking_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ActiveWalkScreen extends StatefulWidget {
  const ActiveWalkScreen({super.key, this.trackingService});

  /// Optional injected service for testing.
  final TrackingService? trackingService;

  @override
  State<ActiveWalkScreen> createState() => _ActiveWalkScreenState();
}

class _ActiveWalkScreenState extends State<ActiveWalkScreen> {
  int _elapsedTime = 0;
  String _activeTab = 'updates';
  Timer? _timer;

  late TrackingService _trackingService;
  StreamSubscription<WalkLocation>? _locationSub;
  StreamSubscription<TrackingConnectionState>? _connectionSub;

  final List<WalkLocation> _locations = [];
  WalkLocation? _latestLocation;
  TrackingConnectionState _connectionState =
      TrackingConnectionState.disconnected;
  bool _isLoading = true;
  String? _error;
  String? _bookingId;

  // Booking info from route args
  String _walkerName = 'Walker';
  String _dogName = 'your dog';

  static void _log(String msg) =>
      developer.log(msg, name: 'ActiveWalkScreen');

  @override
  void initState() {
    super.initState();
    _trackingService = widget.trackingService ?? TrackingService();

    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _elapsedTime++);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bookingId != null) return; // Already initialized

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _bookingId = args['booking_id'] as String?;
      _walkerName = args['walker_name'] as String? ?? 'Walker';
      _dogName = args['dog_name'] as String? ?? 'your dog';
    } else if (args is String) {
      _bookingId = args;
    }

    if (_bookingId != null) {
      _initTracking(_bookingId!);
    } else {
      setState(() {
        _isLoading = false;
        _error = 'No booking ID provided';
      });
    }
  }

  Future<void> _initTracking(String bookingId) async {
    // Listen for connection state changes
    _connectionSub =
        _trackingService.connectionStream.listen((state) {
      if (mounted) setState(() => _connectionState = state);
    });

    // Listen for new GPS locations
    _locationSub = _trackingService.locationStream.listen((location) {
      if (mounted) {
        setState(() {
          _locations.add(location);
          _latestLocation = location;
        });
      }
    });

    // Fetch existing locations
    try {
      final existing = await _trackingService.fetchLocations(bookingId);
      if (mounted) {
        setState(() {
          _locations.addAll(existing);
          if (existing.isNotEmpty) _latestLocation = existing.last;
          _isLoading = false;
        });
      }
    } catch (e) {
      _log('Error fetching locations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load tracking data';
        });
      }
    }

    // Subscribe to live updates
    _trackingService.subscribe(bookingId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSub?.cancel();
    _connectionSub?.cancel();
    _trackingService.dispose();
    super.dispose();
  }

  double get _totalDistanceKm {
    if (_locations.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < _locations.length; i++) {
      total += _haversineDistance(
        _locations[i - 1].latitude,
        _locations[i - 1].longitude,
        _locations[i].latitude,
        _locations[i].longitude,
      );
    }
    return total;
  }

  /// Haversine distance in km between two lat/lng points.
  static double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double deg) => deg * 3.141592653589793 / 180;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Connection status banner
            if (_connectionState == TrackingConnectionState.error ||
                _connectionState == TrackingConnectionState.disconnected &&
                    _bookingId != null &&
                    !_isLoading)
              _buildConnectionBanner(),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Walk',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live tracking',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('\u{2715}', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _locations.isEmpty
                      ? _buildErrorState()
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildMapArea(),
                              const SizedBox(height: 16),
                              _buildWalkerInfo(),
                              const SizedBox(height: 16),
                              _buildStatsGrid(),
                              const SizedBox(height: 16),
                              _buildTabNav(),
                              const SizedBox(height: 16),
                              _buildTabContent(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFEF3C7),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: Color(0xFF92400E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Live connection lost. Using periodic updates.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_bookingId != null) {
                _trackingService.dispose();
                _trackingService = TrackingService();
                _connectionSub?.cancel();
                _locationSub?.cancel();
                _initTracking(_bookingId!);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF92400E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_bookingId != null)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _initTracking(_bookingId!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFDCFCE7),
              Color(0xFFECFDF5),
              Color(0xFFDBEAFE),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Grid pattern
            CustomPaint(
              size: const Size(double.infinity, 280),
              painter: _GridPainter(),
            ),
            // Streets
            Positioned(
              top: 280 * 0.3,
              left: 0,
              right: 0,
              child: Container(height: 4, color: Colors.white60),
            ),
            Positioned(
              top: 280 * 0.6,
              left: 0,
              right: 0,
              child: Container(height: 6, color: Colors.white70),
            ),
            // Route path from GPS data
            if (_locations.length >= 2)
              CustomPaint(
                size: const Size(double.infinity, 280),
                painter: _GpsRoutePainter(locations: _locations),
              )
            else
              CustomPaint(
                size: const Size(double.infinity, 280),
                painter: _RoutePainter(),
              ),
            // Start point (first GPS location)
            if (_locations.isNotEmpty)
              Positioned(
                bottom: 30,
                left: 30,
                child: _PulsingDot(color: AppColors.green500, size: 12),
              ),
            // Current walker location
            if (_latestLocation != null)
              Positioned(
                top: _locations.length > 1
                    ? _mapLatToY(_latestLocation!.latitude)
                    : 90,
                right: _locations.length > 1
                    ? _mapLngToX(_latestLocation!.longitude)
                    : 150,
                child: _WalkerLocation(),
              )
            else
              Positioned(
                top: 90,
                right: 150,
                child: _WalkerLocation(),
              ),
            // LIVE Badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _connectionState ==
                                TrackingConnectionState.connected
                            ? AppColors.green500
                            : _connectionState ==
                                    TrackingConnectionState.error
                                ? AppColors.red500
                                : AppColors.amber500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _connectionState == TrackingConnectionState.connected
                          ? 'LIVE'
                          : _connectionState ==
                                  TrackingConnectionState.connecting
                              ? 'CONNECTING'
                              : 'OFFLINE',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // GPS coordinate display
            if (_latestLocation != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_latestLocation!.latitude.toStringAsFixed(4)}, ${_latestLocation!.longitude.toStringAsFixed(4)}',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            // Location count badge
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.location_on,
                    size: 16, color: AppColors.orange500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Map latitude to Y position within the 280px map area.
  double _mapLatToY(double lat) {
    if (_locations.length < 2) return 90;
    final lats = _locations.map((l) => l.latitude);
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final range = maxLat - minLat;
    if (range == 0) return 140;
    // Invert Y: higher lat = lower Y value (top of screen)
    final normalized = 1.0 - (lat - minLat) / range;
    return 30 + normalized * 220; // 30px margin top/bottom
  }

  /// Map longitude to X position (from right) within the map area.
  double _mapLngToX(double lng) {
    if (_locations.length < 2) return 150;
    final lngs = _locations.map((l) => l.longitude);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    final range = maxLng - minLng;
    if (range == 0) return 150;
    // Right-aligned: higher lng = lower right value
    final normalized = (lng - minLng) / range;
    return 30 + (1.0 - normalized) * 280;
  }

  Widget _buildWalkerInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.orange400, AppColors.orange500],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('\u{1F469}', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _walkerName,
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Walking $_dogName',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.green50,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.phone, size: 18, color: AppColors.green600),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_bookingId != null) {
                  Navigator.pushNamed(context, '/chat', arguments: {
                    'booking_id': _bookingId,
                    'other_party_name': _walkerName,
                  });
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chat_bubble,
                    size: 18, color: AppColors.blue600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final distance = _totalDistanceKm;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _WalkStat(
            icon: Icons.access_time,
            iconColor: AppColors.blue500,
            bgGradient: const [AppColors.blue50, Color(0x80DBEAFE)],
            value: '$_elapsedTime',
            label: 'minutes',
          ),
          const SizedBox(width: 12),
          _WalkStat(
            icon: Icons.trending_up,
            iconColor: AppColors.orange500,
            bgGradient: const [AppColors.orange50, Color(0x80FFEDD5)],
            value: distance.toStringAsFixed(2),
            label: 'km',
          ),
          const SizedBox(width: 12),
          _WalkStat(
            icon: Icons.location_on,
            iconColor: AppColors.purple500,
            bgGradient: const [AppColors.purple50, Color(0x80F3E8FF)],
            value: '${_locations.length}',
            label: 'GPS points',
          ),
        ],
      ),
    );
  }

  Widget _buildTabNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _TabButton(
              label: '\u{1F4CD} Updates',
              isSelected: _activeTab == 'updates',
              onTap: () => setState(() => _activeTab = 'updates'),
            ),
            const SizedBox(width: 6),
            _TabButton(
              label: '\u{1F4F7} Photos',
              isSelected: _activeTab == 'photos',
              onTap: () => setState(() => _activeTab = 'photos'),
            ),
            const SizedBox(width: 6),
            _TabButton(
              label: '\u{1F4CD} GPS Log',
              isSelected: _activeTab == 'gps',
              onTap: () => setState(() => _activeTab = 'gps'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _activeTab == 'updates'
            ? _buildUpdatesTab()
            : _activeTab == 'photos'
                ? _buildPhotosTab()
                : _buildGpsLogTab(),
      ),
    );
  }

  Widget _buildUpdatesTab() {
    if (_locations.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.location_searching,
              size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'Waiting for GPS updates...',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    // Show last 5 GPS updates as timeline
    final recentLocations = _locations.reversed.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Updates',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...recentLocations.map((loc) {
          final timeAgo = DateTime.now().difference(loc.recordedAt);
          final timeStr = timeAgo.inMinutes < 1
              ? 'Just now'
              : '${timeAgo.inMinutes} min ago';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.orange500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GPS: ${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeStr,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPhotosTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Walk Photos',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Icon(Icons.photo_camera_outlined,
                  size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                'Photos from the walk will appear here',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGpsLogTab() {
    if (_locations.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 24),
          Text(
            'No GPS data yet',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    final displayLocations = _locations.reversed.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'GPS Log',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${_locations.length} points',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...displayLocations.map((loc) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: AppColors.orange500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${loc.recordedAt.hour}:${loc.recordedAt.minute.toString().padLeft(2, '0')}:${loc.recordedAt.second.toString().padLeft(2, '0')}',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

class _WalkStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final List<Color> bgGradient;
  final String value;
  final String label;

  const _WalkStat({
    required this.icon,
    required this.iconColor,
    required this.bgGradient,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgGradient,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.orange500 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.orange500.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingDot({required this.color, required this.size});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: widget.size * 2,
              height: widget.size * 2,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.2 * (1 - _controller.value)),
                shape: BoxShape.circle,
              ),
            );
          },
        ),
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ],
    );
  }
}

class _WalkerLocation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.orange500, AppColors.orange400],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Center(
            child: Text('\u{1F469}', style: TextStyle(fontSize: 18)),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.blue500,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.navigation,
                size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.2)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.orange500.withValues(alpha: 0.8)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(30, size.height - 40)
      ..quadraticBezierTo(60, size.height - 60, 80, size.height - 90)
      ..quadraticBezierTo(100, size.height - 120, 120, size.height - 130)
      ..quadraticBezierTo(160, size.height - 150, 180, size.height - 160)
      ..quadraticBezierTo(200, size.height - 180, 220, size.height - 190);

    const dashWidth = 8.0;
    const dashSpace = 4.0;
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        final extractPath = metric.extractPath(distance, end);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints the GPS route from actual walk location data.
class _GpsRoutePainter extends CustomPainter {
  final List<WalkLocation> locations;

  _GpsRoutePainter({required this.locations});

  @override
  void paint(Canvas canvas, Size size) {
    if (locations.length < 2) return;

    final paint = Paint()
      ..color = AppColors.orange500.withValues(alpha: 0.8)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Calculate bounds
    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final loc in locations) {
      if (loc.latitude < minLat) minLat = loc.latitude;
      if (loc.latitude > maxLat) maxLat = loc.latitude;
      if (loc.longitude < minLng) minLng = loc.longitude;
      if (loc.longitude > maxLng) maxLng = loc.longitude;
    }

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;

    // Add padding
    const padding = 30.0;
    final drawWidth = size.width - 2 * padding;
    final drawHeight = size.height - 2 * padding;

    Offset toScreen(WalkLocation loc) {
      final x = lngRange == 0
          ? size.width / 2
          : padding + (loc.longitude - minLng) / lngRange * drawWidth;
      // Invert Y axis (lat increases upward)
      final y = latRange == 0
          ? size.height / 2
          : padding + (1.0 - (loc.latitude - minLat) / latRange) * drawHeight;
      return Offset(x, y);
    }

    final path = Path();
    final first = toScreen(locations.first);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < locations.length; i++) {
      final pt = toScreen(locations[i]);
      path.lineTo(pt.dx, pt.dy);
    }

    canvas.drawPath(path, paint);

    // Draw dots at each point
    final dotPaint = Paint()
      ..color = AppColors.orange500
      ..style = PaintingStyle.fill;

    for (final loc in locations) {
      final pt = toScreen(loc);
      canvas.drawCircle(pt, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GpsRoutePainter oldDelegate) =>
      locations.length != oldDelegate.locations.length;
}

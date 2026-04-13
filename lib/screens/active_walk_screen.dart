import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/services/tracking_service.dart';
import 'package:pawgo/services/booking_status_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/services/gps_broadcast_service.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ActiveWalkScreen extends StatefulWidget {
  const ActiveWalkScreen({
    super.key,
    this.trackingService,
    this.bookingStatusService,
  });

  /// Optional injected service for testing.
  final TrackingService? trackingService;
  final BookingStatusService? bookingStatusService;

  @override
  State<ActiveWalkScreen> createState() => _ActiveWalkScreenState();
}

class _ActiveWalkScreenState extends State<ActiveWalkScreen>
    with SingleTickerProviderStateMixin {
  // Map state
  GoogleMapController? _mapController;
  final List<LatLng> _routePoints = [];
  LatLng? _currentPosition;
  // Booking data
  String? _bookingId;
  String? _walkerName;
  String? _dogName;
  String? _ownerName;

  // Walk stats
  int _elapsedMinutes = 0;
  Timer? _elapsedTimer;

  // Realtime subscriptions
  RealtimeChannel? _locationChannel;
  RealtimeChannel? _bookingChannel;
  String? _walkerId;

  // GPS signal state
  bool _gpsSignalLost = false;
  Timer? _gpsTimeoutTimer;
  static const _gpsTimeoutDuration = Duration(seconds: 30);

  // Walker GPS broadcast
  bool _isWalker = false;
  final GpsBroadcastService _gpsBroadcast = GpsBroadcastService.instance;

  // End walk state
  bool _endingWalk = false;

  // Unread chat message count
  int _unreadChatCount = 0;
  RealtimeChannel? _chatChannel;

  // GPS broadcast pulse animation
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Tab state
  String _activeTab = 'updates';

  // Status updates from realtime
  final List<Map<String, dynamic>> _liveUpdates = [];

  late TrackingService _trackingService;
  StreamSubscription<WalkLocation>? _locationSub;
  StreamSubscription<TrackingConnectionState>? _connectionSub;

  late BookingStatusService _bookingStatusService;
  StreamSubscription<BookingStatusUpdate>? _bookingStatusSub;
  String _bookingStatus = 'walk_started';

  final List<WalkLocation> _locations = [];
  WalkLocation? _latestLocation;
  TrackingConnectionState _connectionState =
      TrackingConnectionState.disconnected;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _trackingService = widget.trackingService ?? TrackingService();
    _bookingStatusService =
        widget.bookingStatusService ?? BookingStatusService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bookingId != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _bookingId = args['booking_id'] as String?;
      _walkerName = args['walker_name'] as String?;
      _dogName = args['dog_name'] as String?;
    } else if (args is String) {
      _bookingId = args;
    }

    if (_bookingId != null) {
      _loadBookingData();
      _loadExistingLocations();
      _subscribeToLocations();
      _initTrackingService(_bookingId!);
      _subscribeToChatMessages();
    } else {
      setState(() {
        _isLoading = false;
        _error = 'No booking ID provided';
      });
    }
  }

  Future<void> _initTrackingService(String bookingId) async {
    // Listen for connection state changes
    _connectionSub =
        _trackingService.connectionStream.listen((state) {
      if (mounted) setState(() => _connectionState = state);
    });

    // Listen for new GPS locations from TrackingService
    _locationSub = _trackingService.locationStream.listen((location) {
      if (mounted) {
        setState(() {
          _locations.add(location);
          _latestLocation = location;
        });
      }
    });

    // Fetch existing locations via TrackingService
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
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load tracking data';
        });
      }
    }

    // Subscribe to live updates via TrackingService
    _trackingService.subscribe(bookingId);

    // Subscribe to booking status changes
    _bookingStatusSub =
        _bookingStatusService.statusStream.listen((update) {
      if (mounted) {
        setState(() => _bookingStatus = update.newStatus);
        if (update.newStatus == 'walk_completed' && !_isWalker) {
          // Owner: redirect to bookings after walk ends
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/home', (route) => false,
                  arguments: {'tab': 2});
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Walk completed!')),
          );
        }
      }
    });
    _bookingStatusService.subscribeToBooking(bookingId);
  }

  void _subscribeToChatMessages() {
    if (_bookingId == null) return;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    _chatChannel = Supabase.instance.client
        .channel('active_walk_chat:$_bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: _bookingId!,
          ),
          callback: (payload) {
            final senderId = payload.newRecord['sender_id']?.toString();
            if (senderId != currentUserId && mounted) {
              setState(() => _unreadChatCount++);
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _elapsedTimer?.cancel();
    _gpsTimeoutTimer?.cancel();
    _locationChannel?.unsubscribe();
    _bookingChannel?.unsubscribe();
    _chatChannel?.unsubscribe();
    _mapController?.dispose();
    _locationSub?.cancel();
    _connectionSub?.cancel();
    _bookingStatusSub?.cancel();
    _trackingService.dispose();
    _bookingStatusService.dispose();
    // Note: GPS broadcast is NOT stopped here intentionally.
    // The service is a singleton that continues in the background
    // so GPS keeps broadcasting even if the user navigates away.
    // It is stopped when the walk ends (via end-walk Edge Function).
    super.dispose();
  }

  Future<void> _loadBookingData() async {
    if (_bookingId == null) return;
    try {
      final data = await withRetry(() => Supabase.instance.client
          .from('bookings')
          .select('*, walkers(id, user_id, users(full_name, avatar_url)), dogs(name), users!bookings_owner_id_fkey(full_name)')
          .eq('id', _bookingId!)
          .single());
      if (!mounted) return;

      // Check if current user is the walker for this booking
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      final walkerUserId = data['walkers']?['user_id'] as String?;
      final isWalker = currentUserId == walkerUserId;

      _walkerId = data['walkers']?['id'] as String?;

      setState(() {
        _walkerName ??= data['walkers']?['users']?['full_name'] as String? ?? 'Walker';
        _dogName ??= data['dogs']?['name'] as String? ?? 'Your dog';
        _ownerName = data['users']?['full_name'] as String? ?? 'Owner';
        _isWalker = isWalker;
        // Calculate elapsed time from started_at
        final startedAt = data['started_at'] as String?;
        if (startedAt != null) {
          final start = DateTime.parse(startedAt);
          _elapsedMinutes = DateTime.now().difference(start).inMinutes;
          _startElapsedTimer();
        }
      });

      // Subscribe to booking status changes (for review prompt on completion)
      if (!isWalker) {
        _subscribeToBookingStatus();
      }

      // If the current user is the walker and walk is active, start GPS broadcast
      final status = data['status'] as String?;
      if (isWalker && status == 'walk_started') {
        _startGpsBroadcast();
      }
    } catch (e) {
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      if (mounted) {
        ErrorHandler.instance.handleError(context, e, screen: 'active_walk');
      }
    }
  }

  Future<void> _startGpsBroadcast() async {
    if (_bookingId == null) return;
    final started = await _gpsBroadcast.startBroadcasting(_bookingId!);
    if (!started && mounted) {
      final message = _gpsBroadcast.lastPermissionError ??
          'Could not access GPS. Please enable location services.';
      ErrorHandler.instance.showRecoverableError(context, message);
    }
  }

  void _subscribeToBookingStatus() {
    if (_bookingId == null) return;
    _bookingChannel?.unsubscribe();

    _bookingChannel = Supabase.instance.client
        .channel('booking_status_$_bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _bookingId!,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (status == 'walk_completed' && mounted) {
              Navigator.pushReplacementNamed(context, '/review', arguments: {
                'booking_id': _bookingId,
                'walker_id': _walkerId,
                'walker_name': _walkerName,
              });
            }
          },
        )
        .subscribe();
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedMinutes++);
    });
  }

  Future<void> _loadExistingLocations() async {
    if (_bookingId == null) return;
    try {
      final data = await withRetry(() => Supabase.instance.client
          .from('walk_locations')
          .select('lat, lng, recorded_at')
          .eq('booking_id', _bookingId!)
          .order('recorded_at', ascending: true));

      if (!mounted) return;
      if (data.isNotEmpty) {
        setState(() {
          for (final point in data) {
            final lat = (point['lat'] as num).toDouble();
            final lng = (point['lng'] as num).toDouble();
            _routePoints.add(LatLng(lat, lng));
          }
          _currentPosition = _routePoints.last;
          _resetGpsTimeout();
        });
        _animateToCurrentPosition();
      }
    } catch (e) {
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      debugPrint('Error loading locations: $e');
    }
  }

  void _subscribeToLocations() {
    if (_bookingId == null) return;

    _locationChannel = Supabase.instance.client
        .channel('walk_locations_$_bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'walk_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: _bookingId!,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final lat = (newRecord['lat'] as num).toDouble();
            final lng = (newRecord['lng'] as num).toDouble();
            final newPoint = LatLng(lat, lng);

            if (!mounted) return;
            setState(() {
              _routePoints.add(newPoint);
              _currentPosition = newPoint;
              _gpsSignalLost = false;
              _resetGpsTimeout();
            });
            _animateToCurrentPosition();
          },
        )
        .subscribe();
  }

  void _resetGpsTimeout() {
    _gpsTimeoutTimer?.cancel();
    _gpsTimeoutTimer = Timer(_gpsTimeoutDuration, () {
      if (!mounted) return;
      setState(() => _gpsSignalLost = true);
    });
  }

  void _animateToCurrentPosition() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_currentPosition!),
      );
    }
  }

  double _calculateDistanceKm() {
    if (_routePoints.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < _routePoints.length; i++) {
      total += _haversineDistance(_routePoints[i - 1], _routePoints[i]);
    }
    return total;
  }

  double _haversineDistance(LatLng a, LatLng b) {
    const r = 6371.0; // Earth radius in km
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final sinDLat = sin(dLat / 2);
    final sinDLng = sin(dLng / 2);
    final h = sinDLat * sinDLat +
        cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * sinDLng * sinDLng;
    return 2 * r * asin(sqrt(h));
  }

  double _toRad(double deg) => deg * (3.14159265358979323846 / 180);

  Future<void> _endWalk() async {
    if (_bookingId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('End Walk?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to end this walk?',
            style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange500),
            child: Text('End Walk',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _endingWalk = true);

    try {
      final res = await withRetry(() =>
          Supabase.instance.client.functions.invoke(
            'end-walk',
            body: {'booking_id': _bookingId},
          ));

      if (!mounted) return;

      if (res.status != 200) {
        setState(() => _endingWalk = false);
        ErrorHandler.instance.handleFunctionError(
          context,
          res,
          screen: 'active_walk',
          fallbackMessage: 'Failed to end walk',
        );
      } else {
        AnalyticsService.instance.walkCompleted(bookingId: _bookingId!);
        GpsBroadcastService.instance.stopBroadcasting();
        if (!mounted) return;
        ErrorHandler.instance.showRecoverableError(context, 'Walk completed!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _endingWalk = false);
      ErrorHandler.instance.handleError(
        context,
        e,
        screen: 'active_walk',
        fallbackMessage: 'Failed to end walk. Please try again.',
      );
    }
  }

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
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _routePoints.isEmpty && _locations.isEmpty
                      ? _buildErrorState()
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildMapArea(),
                              const SizedBox(height: 16),
                              _buildWalkerInfo(),
                              const SizedBox(height: 16),
                              _buildStatsGrid(),
                              if (_isWalker) ...[
                                const SizedBox(height: 16),
                                _buildEndWalkButton(),
                              ],
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
          Icon(PhosphorIcons.wifiSlash(), size: 18, color: Color(0xFF92400E)),
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
                _initTrackingService(_bookingId!);
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
            Icon(PhosphorIcons.mapPinLine(), size: 64, color: AppColors.textTertiary),
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
                  _initTrackingService(_bookingId!);
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

  Widget _buildHeader() {
    return Padding(
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
                _bookingStatus == 'walk_completed'
                    ? 'Walk completed'
                    : 'Live tracking',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _bookingStatus == 'walk_completed'
                      ? AppColors.green600
                      : AppColors.textSecondary,
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
    );
  }

  Widget _buildMapArea() {
    // Default center (Mexico City) when no GPS points yet
    final center = _currentPosition ?? const LatLng(19.4326, -99.1332);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: center,
                zoom: 16,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (_currentPosition != null) {
                  _animateToCurrentPosition();
                }
              },
              polylines: {
                if (_routePoints.length >= 2)
                  Polyline(
                    polylineId: const PolylineId('walk_route'),
                    points: _routePoints,
                    color: AppColors.blue500, // Sky Blue #3B82F6
                    width: 5,
                  ),
              },
              markers: {
                if (_currentPosition != null)
                  Marker(
                    markerId: const MarkerId('walker'),
                    position: _currentPosition!,
                    infoWindow: InfoWindow(title: _walkerName ?? 'Walker'),
                  ),
                if (_routePoints.isNotEmpty)
                  Marker(
                    markerId: const MarkerId('start'),
                    position: _routePoints.first,
                    infoWindow: const InfoWindow(title: 'Start'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                  ),
              },
              myLocationEnabled: _isWalker,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
            // LIVE Badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        color: _gpsSignalLost
                            ? AppColors.amber500
                            : _connectionState == TrackingConnectionState.connected
                                ? AppColors.green500
                                : _connectionState == TrackingConnectionState.error
                                    ? AppColors.red500
                                    : AppColors.amber500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _gpsSignalLost
                          ? 'SIGNAL LOST'
                          : _connectionState == TrackingConnectionState.connected
                              ? 'LIVE'
                              : _connectionState == TrackingConnectionState.connecting
                                  ? 'CONNECTING'
                                  : 'OFFLINE',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _gpsSignalLost
                            ? AppColors.amber500
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Walker GPS Broadcasting indicator
            if (_isWalker)
              Positioned(
                bottom: 12,
                left: 12,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _gpsBroadcast.broadcastingNotifier,
                  builder: (context, isBroadcasting, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
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
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isBroadcasting
                                      ? AppColors.green500
                                          .withValues(alpha: _pulseAnimation.value)
                                      : AppColors.red500,
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isBroadcasting ? 'Broadcasting GPS' : 'GPS Off',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isBroadcasting
                                  ? AppColors.green600
                                  : AppColors.red500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            // GPS coordinate display (when not walker and has location)
            if (!_isWalker && _latestLocation != null)
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
            // GPS Signal Lost Banner
            if (_gpsSignalLost)
              Positioned(
                bottom: 50,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.amber50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.amber500),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.wifiSlash(), size: 16, color: AppColors.amber500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'GPS signal lost. Last position shown.',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.amber500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Recenter button
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: _animateToCurrentPosition,
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
                  child: Icon(PhosphorIcons.crosshairSimple(),
                      size: 16, color: AppColors.orange500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                    _walkerName ?? 'Walker',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Walking ${_dogName ?? 'your dog'}',
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
              child: Icon(PhosphorIcons.phone(), size: 18, color: AppColors.green600),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() => _unreadChatCount = 0);
                Navigator.pushNamed(context, '/chat',
                    arguments: _bookingId != null
                        ? {
                            'booking_id': _bookingId,
                            'other_party_name': _isWalker ? _ownerName : _walkerName,
                          }
                        : null);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(PhosphorIcons.chatCircle(PhosphorIconsStyle.fill),
                        size: 18, color: AppColors.blue600),
                  ),
                  if (_unreadChatCount > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.red500,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            _unreadChatCount > 9 ? '9+' : '$_unreadChatCount',
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
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
      ),
    );
  }

  Widget _buildStatsGrid() {
    final distanceKm = _calculateDistanceKm();
    final distanceStr = distanceKm < 1
        ? '${(distanceKm * 1000).toInt()}m'
        : '${distanceKm.toStringAsFixed(1)}km';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _WalkStat(
            icon: PhosphorIcons.clock(),
            iconColor: AppColors.blue500,
            bgGradient: const [AppColors.blue50, Color(0x80DBEAFE)],
            value: '$_elapsedMinutes',
            label: 'minutes',
          ),
          const SizedBox(width: 12),
          _WalkStat(
            icon: PhosphorIcons.trendUp(),
            iconColor: AppColors.orange500,
            bgGradient: const [AppColors.orange50, Color(0x80FFEDD5)],
            value: distanceStr,
            label: 'distance',
          ),
          const SizedBox(width: 12),
          _WalkStat(
            icon: PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
            iconColor: AppColors.purple500,
            bgGradient: const [AppColors.purple50, Color(0x80F3E8FF)],
            value: '${_routePoints.length}',
            label: 'GPS points',
          ),
        ],
      ),
    );
  }

  Widget _buildEndWalkButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _endingWalk ? null : _endWalk,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red500,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.red500.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _endingWalk
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIcons.stopCircle(PhosphorIconsStyle.fill), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'End Walk',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
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
    if (_liveUpdates.isEmpty && _routePoints.isEmpty && _locations.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 24),
          Icon(PhosphorIcons.crosshair(),
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

    if (_liveUpdates.isEmpty) {
      // Show default status based on walk state
      final updates = <Map<String, dynamic>>[];
      if (_gpsSignalLost) {
        updates.add({
          'color': AppColors.amber500,
          'text': 'GPS signal lost - waiting for reconnection',
          'time': 'now',
        });
      }
      if (_routePoints.isNotEmpty) {
        updates.add({
          'color': AppColors.green500,
          'text': 'Walk is in progress - tracking ${_routePoints.length} GPS points',
          'time': '$_elapsedMinutes minutes ago',
        });
      }
      if (updates.isEmpty) {
        updates.add({
          'color': AppColors.blue500,
          'text': 'Waiting for walk to begin...',
          'time': 'now',
        });
      }

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
          ...updates.map((u) => _buildUpdateItem(u)),
        ],
      );
    }

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
        ..._liveUpdates.map((u) => _buildUpdateItem(u)),
      ],
    );
  }

  Widget _buildUpdateItem(Map<String, dynamic> u) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: u['color'] as Color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u['text'] as String,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  u['time'] as String,
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
              Icon(PhosphorIcons.camera(),
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
    if (_routePoints.isEmpty && _locations.isEmpty) {
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

    // Show GPS log from locations if available, otherwise from routePoints
    if (_locations.isNotEmpty) {
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
                      Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
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

    // Fallback: show route points count
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GPS Log',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_routePoints.length} GPS points recorded',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
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

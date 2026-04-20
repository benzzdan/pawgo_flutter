import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/tracking_service.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

/// Displays a map with two pins — the walker's live GPS position and the
/// owner's default home address — while the booking is in `confirmed` or
/// `walker_en_route` status. Auto-zooms to keep both pins visible.
class WalkerEnRouteMap extends StatefulWidget {
  const WalkerEnRouteMap({
    super.key,
    required this.bookingId,
    this.trackingService,
    this.supabaseClient,
  });

  final String bookingId;

  /// Optional injected service for testing.
  final TrackingService? trackingService;
  final SupabaseClient? supabaseClient;

  @override
  State<WalkerEnRouteMap> createState() => _WalkerEnRouteMapState();
}

class _WalkerEnRouteMapState extends State<WalkerEnRouteMap> {
  GoogleMapController? _mapController;
  late final TrackingService _trackingService;
  late final SupabaseClient _supabase;

  StreamSubscription<WalkLocation>? _locationSub;
  StreamSubscription<TrackingConnectionState>? _connectionSub;

  LatLng? _walkerPosition;
  LatLng? _homePosition;
  TrackingConnectionState _connectionState =
      TrackingConnectionState.disconnected;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _trackingService = widget.trackingService ?? TrackingService(client: _supabase);
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      _fetchHomeAddress(),
      _fetchLatestWalkerLocation(),
    ]);
    _subscribeToWalkerLocation();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Fetches the owner's default home address from saved_addresses.
  Future<void> _fetchHomeAddress() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('saved_addresses')
          .select('latitude, longitude')
          .eq('user_id', userId)
          .eq('is_default', true)
          .limit(1)
          .maybeSingle();

      if (data != null && mounted) {
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          setState(() => _homePosition = LatLng(lat, lng));
        }
      }
    } catch (e) {
      debugPrint('WalkerEnRouteMap: failed to fetch home address: $e');
    }
  }

  /// Fetches the most recent walker GPS point for this booking.
  Future<void> _fetchLatestWalkerLocation() async {
    try {
      final locations = await _trackingService.fetchLocations(widget.bookingId);
      if (locations.isNotEmpty && mounted) {
        final latest = locations.last;
        setState(() {
          _walkerPosition = LatLng(latest.latitude, latest.longitude);
        });
      }
    } catch (e) {
      debugPrint('WalkerEnRouteMap: failed to fetch walker location: $e');
    }
  }

  /// Subscribes to live GPS updates for the walker.
  void _subscribeToWalkerLocation() {
    _connectionSub = _trackingService.connectionStream.listen((state) {
      if (mounted) setState(() => _connectionState = state);
    });

    _locationSub = _trackingService.locationStream.listen((location) {
      if (mounted) {
        setState(() {
          _walkerPosition = LatLng(location.latitude, location.longitude);
        });
        _fitBothPins();
      }
    });

    _trackingService.subscribe(widget.bookingId);
  }

  /// Animates the camera to show both walker and home pins with padding.
  void _fitBothPins() {
    if (_mapController == null) return;

    if (_walkerPosition != null && _homePosition != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _walkerPosition!.latitude < _homePosition!.latitude
              ? _walkerPosition!.latitude
              : _homePosition!.latitude,
          _walkerPosition!.longitude < _homePosition!.longitude
              ? _walkerPosition!.longitude
              : _homePosition!.longitude,
        ),
        northeast: LatLng(
          _walkerPosition!.latitude > _homePosition!.latitude
              ? _walkerPosition!.latitude
              : _homePosition!.latitude,
          _walkerPosition!.longitude > _homePosition!.longitude
              ? _walkerPosition!.longitude
              : _homePosition!.longitude,
        ),
      );
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 60),
      );
    } else if (_walkerPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_walkerPosition!, 15),
      );
    } else if (_homePosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_homePosition!, 15),
      );
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _connectionSub?.cancel();
    _trackingService.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(child: PawProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Text(
            _error!,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    // Default center: Mexico City — overridden once pins load
    final center = _walkerPosition ??
        _homePosition ??
        const LatLng(19.4326, -99.1332);

    return Container(
      height: 220,
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
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // Fit both pins once the map is ready
              _fitBothPins();
            },
            markers: _buildMarkers(),
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          // Status badge
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            child: _buildStatusBadge(),
          ),
          // "Locating walker..." overlay when no GPS data yet
          if (_walkerPosition == null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: PawProgressIndicator(size: 16, strokeWidth: 2),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Locating walker...',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_walkerPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('walker_enroute'),
          position: _walkerPosition!,
          infoWindow: const InfoWindow(title: 'Walker'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }

    if (_homePosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('home'),
          position: _homePosition!,
          infoWindow: const InfoWindow(title: 'Home'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildStatusBadge() {
    final bool isConnected =
        _connectionState == TrackingConnectionState.connected;
    final Color dotColor = _walkerPosition == null
        ? AppColors.amber500
        : isConnected
            ? AppColors.green500
            : AppColors.amber500;
    final String label = _walkerPosition == null
        ? 'LOCATING'
        : isConnected
            ? 'LIVE'
            : 'CONNECTING';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
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
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

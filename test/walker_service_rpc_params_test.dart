import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/screens/find_screen.dart' show AdvancedFilters;
import 'package:pawgo/services/walker_service.dart';

void main() {
  group('WalkerService.buildNearbyWalkersParams', () {
    test('only lat/lng when no filters are set', () {
      final params = WalkerService.buildNearbyWalkersParams(
        latitude: 19.43,
        longitude: -99.13,
        filters: const AdvancedFilters(),
      );

      expect(params['search_lat'], 19.43);
      expect(params['search_lng'], -99.13);
      // No range params when filters are empty — the RPC defaults the new
      // four params to NULL so existing 2-arg behavior is preserved.
      expect(params.containsKey('min_distance_km'), isFalse);
      expect(params.containsKey('max_distance_km'), isFalse);
      expect(params.containsKey('min_price_mxn'), isFalse);
      expect(params.containsKey('max_price_mxn'), isFalse);
    });

    test('forwards min/max distance to the RPC', () {
      final params = WalkerService.buildNearbyWalkersParams(
        latitude: 19.43,
        longitude: -99.13,
        filters: const AdvancedFilters(
          minDistanceKm: 1,
          maxDistanceKm: 5,
        ),
      );

      expect(params['min_distance_km'], 1.0);
      expect(params['max_distance_km'], 5.0);
    });

    test('forwards min/max price to the RPC', () {
      final params = WalkerService.buildNearbyWalkersParams(
        latitude: 19.43,
        longitude: -99.13,
        filters: const AdvancedFilters(
          minRate: 80,
          maxRate: 200,
        ),
      );

      expect(params['min_price_mxn'], 80.0);
      expect(params['max_price_mxn'], 200.0);
    });

    test('omits param when only one side of a range is set', () {
      final params = WalkerService.buildNearbyWalkersParams(
        latitude: 19.43,
        longitude: -99.13,
        filters: const AdvancedFilters(maxDistanceKm: 10),
      );

      expect(params['max_distance_km'], 10.0);
      expect(params.containsKey('min_distance_km'), isFalse);
    });

    test('does NOT forward minExperience / backgroundChecked / onlyShowInRange', () {
      // Those are still applied client-side (or not yet supported on the
      // RPC). Forwarding them to the RPC would 400 the request.
      final params = WalkerService.buildNearbyWalkersParams(
        latitude: 19.43,
        longitude: -99.13,
        filters: const AdvancedFilters(
          minExperience: 3,
          backgroundChecked: true,
          onlyShowInRange: true,
          maxDistanceKm: 7,
        ),
      );

      expect(params['max_distance_km'], 7.0);
      expect(params.containsKey('min_experience'), isFalse);
      expect(params.containsKey('background_checked'), isFalse);
      expect(params.containsKey('only_show_in_range'), isFalse);
    });
  });
}

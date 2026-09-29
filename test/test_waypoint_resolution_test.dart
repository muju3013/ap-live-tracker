// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:ap_live_tracker/services/apsrtc_place_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Resolve real waypoints for CHITTOOR -> PILER (27092026_CT24_4_PILER)', () async {
    final repo = ApsrtcPlaceRepository();
    await repo.loadPlaces();

    const rawWaypoints =
        '2821,227284,1668649828715,12281,1663562995920,227380,1457681389736,3081,236386,224342,221471,230556,11821';
    final ids = rawWaypoints.split(',');

    print(
      '\nResolving waypoints for 27092026_CT24_4_PILER (CHITTOOR -> PILER):',
    );
    for (int i = 0; i < ids.length; i++) {
      final id = ids[i].trim();
      final place = repo.getPlaceById(id);
      if (place != null) {
        print(
          '  [$i] ID: $id -> ${place.placeName} (${place.mandalName}, PIN: ${place.pinCode})',
        );
      } else {
        print('  [$i] ID: $id -> UNKNOWN PLACE');
      }
    }
  });
}

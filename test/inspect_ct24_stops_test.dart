// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:ap_live_tracker/services/apsrtc_place_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Check BANDA PALLI, RANGAMPET, PATURU in ApsrtcPlaceRepository', () async {
    final repo = ApsrtcPlaceRepository();
    await repo.loadPlaces();

    print('Looking up IDs:');
    print(
      '  1668649828715 -> ${repo.getPlaceById("1668649828715")?.placeName}',
    );
    print(
      '  1663562995920 -> ${repo.getPlaceById("1663562995920")?.placeName}',
    );
    print(
      '  1457681389736 -> ${repo.getPlaceById("1457681389736")?.placeName}',
    );

    print('\nSearching by name:');
    print(
      '  BANDA PALLI -> ${repo.searchPlaces("BANDA PALLI").map((p) => "${p.placeName} (${p.placeId})").toList()}',
    );
    print(
      '  RANGAMPET -> ${repo.searchPlaces("RANGAMPET").map((p) => "${p.placeName} (${p.placeId})").toList()}',
    );
    print(
      '  PATURU -> ${repo.searchPlaces("PATURU").map((p) => "${p.placeName} (${p.placeId})").toList()}',
    );
  });
}

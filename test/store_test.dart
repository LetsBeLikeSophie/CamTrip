import 'package:camtrip/models.dart';
import 'package:camtrip/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 1);

  Trip trip(List<String> langs) => Trip(
        id: 't1',
        country: '일본',
        city: '도쿄',
        langs: langs,
        startAt: start,
        lastAt: start,
      );

  test('old saved trips with a single lang still load', () {
    final t = Trip.fromJson({
      'id': 't1',
      'country': '일본',
      'city': '',
      'lang': 'ja',
      'startAt': start.toIso8601String(),
      'lastAt': start.toIso8601String(),
    });
    expect(t.langs, ['ja']);
  });

  test('a language kept on the current trip is not asked again', () {
    final store = AppStore()..trips.add(trip(['ja']));
    final now = start.add(const Duration(hours: 1));
    expect(store.needsNewTrip('en', now), isTrue);
    store.trips.first.langs.add('en');
    expect(store.needsNewTrip('en', now), isFalse);
    expect(store.needsNewTrip('ja', now), isFalse);
  });

  test('more than 3 days away asks for a new trip', () {
    final store = AppStore()..trips.add(trip(['ja']));
    expect(store.needsNewTrip('ja', start.add(const Duration(days: 4))), isTrue);
  });
}

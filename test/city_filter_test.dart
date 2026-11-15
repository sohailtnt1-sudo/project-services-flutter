// Unit tests for the city filter (provider list, 16 Nov 2026).
// No Supabase needed — pure matching on Provider.city.
import 'package:flutter_test/flutter_test.dart';
import 'package:project_services/models.dart';
import 'package:project_services/repository.dart';

Provider _provider(String id, String? city) => Provider(
      id: id,
      userId: 'user-$id',
      name: 'Tech $id',
      city: city,
      experienceYears: 3,
      verificationStatus: 'approved',
      isAvailable: true,
      averageRating: 4.5,
    );

void main() {
  test('providerMatchesCity is case-insensitive and trims', () {
    expect(providerMatchesCity('Lahore', 'Lahore'), isTrue);
    expect(providerMatchesCity('lahore', 'Lahore'), isTrue);
    expect(providerMatchesCity('  LAHORE  ', 'lahore'), isTrue);
    expect(providerMatchesCity('Karachi', 'Lahore'), isFalse);
  });

  test('providers with no city set are shown for every city', () {
    expect(providerMatchesCity(null, 'Lahore'), isTrue);
    expect(providerMatchesCity('', 'Karachi'), isTrue);
    expect(providerMatchesCity('   ', 'Quetta'), isTrue);
  });

  test('empty selected city matches everything', () {
    expect(providerMatchesCity('Karachi', null), isTrue);
    expect(providerMatchesCity('Karachi', ''), isTrue);
    expect(providerMatchesCity('Karachi', '   '), isTrue);
  });

  test('filterProvidersByCity keeps same-city + no-city providers only', () {
    final list = [
      _provider('p1', 'Lahore'),
      _provider('p2', 'lahore'),
      _provider('p3', 'Karachi'),
      _provider('p4', null),
      _provider('p5', ''),
    ];
    final filtered = filterProvidersByCity(list, 'Lahore');
    expect(filtered.map((p) => p.id), ['p1', 'p2', 'p4', 'p5']);
  });

  test('filterProvidersByCity with no city returns the whole list', () {
    final list = [_provider('p1', 'Lahore'), _provider('p2', 'Karachi')];
    expect(filterProvidersByCity(list, null), hasLength(2));
    expect(filterProvidersByCity(list, ''), hasLength(2));
  });

  test('service cities list matches the website header selector', () {
    expect(kServiceCities,
        ['Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Quetta']);
    expect(kDefaultCity, 'Lahore');
  });
}

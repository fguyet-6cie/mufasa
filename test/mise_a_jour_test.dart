import 'package:flutter_test/flutter_test.dart';
import 'package:mufasa/mise_a_jour.dart';

void main() {
  test('numéro tiré du nom de version', () {
    expect(numeroDepuisTag('v0.2.7'), 7);
    expect(numeroDepuisTag('v0.2.12'), 12);
    expect(numeroDepuisTag('pas de numéro'), isNull);
  });
  test('compare avec la version installée', () {
    expect(estPlusRecente('v0.2.8', '7'), isTrue);
    expect(estPlusRecente('v0.2.7', '7'), isFalse);
    expect(estPlusRecente('v0.2.3', '7'), isFalse);
    expect(estPlusRecente('v0.2.8', ''), isFalse);
  });
}

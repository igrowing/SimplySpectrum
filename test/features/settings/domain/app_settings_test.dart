import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('documented defaults', () {
      const settings = AppSettings();

      expect(settings.detectColorPeaks, isTrue);
      expect(settings.spectrumUnit, SpectrumUnit.wavelengthNm);
      expect(settings.showExtremeLightSpots, isFalse);
      expect(settings.enhanceColors, isFalse);
    });

    test('copyWith overrides only the given fields', () {
      const settings = AppSettings();

      final updated = settings.copyWith(enhanceColors: true);

      expect(updated.enhanceColors, isTrue);
      expect(updated.detectColorPeaks, settings.detectColorPeaks);
      expect(updated.spectrumUnit, settings.spectrumUnit);
    });

    test('equality is structural', () {
      const a = AppSettings(enhanceColors: true);
      const b = AppSettings(enhanceColors: true);

      expect(a, b);
    });
  });
}

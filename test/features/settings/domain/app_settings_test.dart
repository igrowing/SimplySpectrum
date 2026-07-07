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
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.topLeftSector, SectorWidgetType.camera);
      expect(settings.topRightSector, SectorWidgetType.colorChart);
      expect(settings.bottomLeftSector, SectorWidgetType.luminosityChart);
      expect(settings.bottomRightSector, SectorWidgetType.controls);
    });

    test('copyWith overrides only the given fields', () {
      const settings = AppSettings();

      final updated = settings.copyWith(enhanceColors: true);

      expect(updated.enhanceColors, isTrue);
      expect(updated.detectColorPeaks, settings.detectColorPeaks);
      expect(updated.spectrumUnit, settings.spectrumUnit);
      expect(updated.themeMode, settings.themeMode);
    });

    test('copyWith overrides themeMode independently', () {
      const settings = AppSettings();

      final updated = settings.copyWith(themeMode: AppThemeMode.dark);

      expect(updated.themeMode, AppThemeMode.dark);
      expect(updated.enhanceColors, settings.enhanceColors);
    });

    test('equality is structural', () {
      const a = AppSettings(enhanceColors: true);
      const b = AppSettings(enhanceColors: true);

      expect(a, b);
    });

    group('sectorAt', () {
      test('returns the widget assigned to each position by default', () {
        const settings = AppSettings();

        expect(
          settings.sectorAt(SectorPosition.topLeft),
          SectorWidgetType.camera,
        );
        expect(
          settings.sectorAt(SectorPosition.topRight),
          SectorWidgetType.colorChart,
        );
        expect(
          settings.sectorAt(SectorPosition.bottomLeft),
          SectorWidgetType.luminosityChart,
        );
        expect(
          settings.sectorAt(SectorPosition.bottomRight),
          SectorWidgetType.controls,
        );
      });
    });

    group('hasValidSectorLayout', () {
      test('the default arrangement is valid', () {
        expect(const AppSettings().hasValidSectorLayout, isTrue);
      });

      test('a layout with a duplicated widget is invalid', () {
        const settings = AppSettings(topRightSector: SectorWidgetType.camera);

        expect(settings.hasValidSectorLayout, isFalse);
      });
    });

    group('withSectorWidget', () {
      test('swaps the target position with wherever the widget was', () {
        const settings = AppSettings();

        // Controls (currently bottomRight) moves to topLeft; whatever
        // was at topLeft (camera) should end up wherever Controls used
        // to be.
        final updated = settings.withSectorWidget(
          SectorPosition.topLeft,
          SectorWidgetType.controls,
        );

        expect(updated.topLeftSector, SectorWidgetType.controls);
        expect(updated.bottomRightSector, SectorWidgetType.camera);
        // Untouched positions stay as they were.
        expect(updated.topRightSector, SectorWidgetType.colorChart);
        expect(updated.bottomLeftSector, SectorWidgetType.luminosityChart);
        expect(updated.hasValidSectorLayout, isTrue);
      });

      test('assigning the widget already at that position is a no-op', () {
        const settings = AppSettings();

        final updated = settings.withSectorWidget(
          SectorPosition.topLeft,
          SectorWidgetType.camera,
        );

        expect(updated, settings);
      });

      test('every result stays a valid permutation of all 4 widgets', () {
        const settings = AppSettings();

        for (final position in SectorPosition.values) {
          for (final widget in SectorWidgetType.values) {
            expect(
              settings.withSectorWidget(position, widget).hasValidSectorLayout,
              isTrue,
              reason: 'moving $widget to $position should stay valid',
            );
          }
        }
      });
    });
  });
}

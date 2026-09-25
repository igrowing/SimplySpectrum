import 'package:equatable/equatable.dart';

/// Which unit the combined chart's X axis and spectrum color labels use.
enum SpectrumUnit { wavelengthNm, frequencyHz }

/// The app's chosen color scheme. Kept as a plain domain enum (rather
/// than importing Flutter's `ThemeMode` here) so this layer stays
/// framework-agnostic; the presentation layer maps this to
/// `ThemeMode` when configuring `MaterialApp`.
enum AppThemeMode { system, light, dark }

/// User-configurable, persisted app settings (Settings screen).
class AppSettings extends Equatable {
  const AppSettings({
    this.detectColorPeaks = true,
    this.spectrumUnit = SpectrumUnit.wavelengthNm,
    this.showExtremeLightSpots = false,
    this.enhanceColors = false,
    this.themeMode = AppThemeMode.system,
    this.chartsAtTop = true,
  });

  /// Detect up to 5 prominent local peaks on the spectrum graph and label
  /// each with its wavelength/frequency. Default: enabled.
  final bool detectColorPeaks;

  /// Wavelength (nm) or frequency (Hz, ~7.5e14-4.3e14) display mode for
  /// the spectrum half of the combined chart. Default: wavelength.
  final SpectrumUnit spectrumUnit;

  /// Draw a black 2px-wide circle over the brightest, and a white 2px-wide
  /// circle over the darkest, >=20 sq. px area of the camera preview.
  /// Default: disabled.
  final bool showExtremeLightSpots;

  /// Boost saturation/contrast of captured video before spectrum and
  /// luminosity analysis. Default: disabled.
  final bool enhanceColors;

  /// Light/dark/system color scheme for the app's chrome. Default:
  /// follow the system setting. This applies to the whole app, with the
  /// sole exception of the live camera texture itself, which always
  /// stays untouched by the theme.
  final AppThemeMode themeMode;

  /// Whether the combined chart occupies the top half of the screen
  /// (vertical layout) or the left half (horizontal layout). When
  /// false, the charts move to the bottom (vertical) / right
  /// (horizontal) half, and the camera + controls take the other. In
  /// the horizontal layout, `false` also mirrors the Controls sector's
  /// internal layout (average-color band toward the charts, buttons
  /// toward the outer edge) so the whole arrangement reads as a true
  /// left/right mirror rather than a different composition. Default:
  /// true (charts on top).
  final bool chartsAtTop;

  AppSettings copyWith({
    bool? detectColorPeaks,
    SpectrumUnit? spectrumUnit,
    bool? showExtremeLightSpots,
    bool? enhanceColors,
    AppThemeMode? themeMode,
    bool? chartsAtTop,
  }) {
    return AppSettings(
      detectColorPeaks: detectColorPeaks ?? this.detectColorPeaks,
      spectrumUnit: spectrumUnit ?? this.spectrumUnit,
      showExtremeLightSpots:
          showExtremeLightSpots ?? this.showExtremeLightSpots,
      enhanceColors: enhanceColors ?? this.enhanceColors,
      themeMode: themeMode ?? this.themeMode,
      chartsAtTop: chartsAtTop ?? this.chartsAtTop,
    );
  }

  @override
  List<Object?> get props => [
    detectColorPeaks,
    spectrumUnit,
    showExtremeLightSpots,
    enhanceColors,
    themeMode,
    chartsAtTop,
  ];
}

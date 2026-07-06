import 'package:equatable/equatable.dart';

/// Which unit the Spectrum sector's X axis and color labels use.
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
  });

  /// Detect up to 5 prominent local peaks on the spectrum graph and label
  /// each with its wavelength/frequency. Default: enabled.
  final bool detectColorPeaks;

  /// Wavelength (nm) or frequency (Hz, ~7.5e14-4.3e14) display mode for the
  /// Spectrum sector. Default: wavelength.
  final SpectrumUnit spectrumUnit;

  /// Draw a black 2px-wide circle over the brightest, and a white 2px-wide
  /// circle over the darkest, >=20 sq. px area of the camera preview.
  /// Default: disabled.
  final bool showExtremeLightSpots;

  /// Boost saturation/contrast of captured video before spectrum and
  /// luminosity analysis. Default: disabled.
  final bool enhanceColors;

  /// Light/dark/system color scheme for the app's chrome (Settings and
  /// info screens). Default: follow the system setting. Note the
  /// camera/analysis viewfinder itself always stays dark regardless of
  /// this setting - it needs a consistent dark background to keep the
  /// spectrum/luminosity charts and sampled colors readable.
  final AppThemeMode themeMode;

  AppSettings copyWith({
    bool? detectColorPeaks,
    SpectrumUnit? spectrumUnit,
    bool? showExtremeLightSpots,
    bool? enhanceColors,
    AppThemeMode? themeMode,
  }) {
    return AppSettings(
      detectColorPeaks: detectColorPeaks ?? this.detectColorPeaks,
      spectrumUnit: spectrumUnit ?? this.spectrumUnit,
      showExtremeLightSpots:
          showExtremeLightSpots ?? this.showExtremeLightSpots,
      enhanceColors: enhanceColors ?? this.enhanceColors,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  List<Object?> get props => [
    detectColorPeaks,
    spectrumUnit,
    showExtremeLightSpots,
    enhanceColors,
    themeMode,
  ];
}

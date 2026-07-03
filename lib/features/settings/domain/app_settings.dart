import 'package:equatable/equatable.dart';

/// Which unit the Spectrum sector's X axis and color labels use.
enum SpectrumUnit { wavelengthNm, frequencyHz }

/// User-configurable, persisted app settings (Settings sector).
class AppSettings extends Equatable {
  const AppSettings({
    this.detectColorPeaks = true,
    this.spectrumUnit = SpectrumUnit.wavelengthNm,
    this.showBrightestPoint = false,
    this.showDarkestPoint = false,
    this.enhanceColors = false,
  });

  /// Detect up to 5 prominent local peaks on the spectrum graph and label
  /// each with its wavelength/frequency. Default: enabled.
  final bool detectColorPeaks;

  /// Wavelength (nm) or frequency (Hz, ~7.5e14-4.3e14) display mode for the
  /// Spectrum sector. Default: wavelength.
  final SpectrumUnit spectrumUnit;

  /// Draw a black 2px-wide circle over the brightest >=20 sq. px area of
  /// the camera preview. Default: disabled.
  final bool showBrightestPoint;

  /// Draw a white 2px-wide circle over the darkest >=20 sq. px area of the
  /// camera preview. Default: disabled.
  final bool showDarkestPoint;

  /// Boost saturation/contrast of captured video before spectrum and
  /// luminosity analysis. Default: disabled.
  final bool enhanceColors;

  AppSettings copyWith({
    bool? detectColorPeaks,
    SpectrumUnit? spectrumUnit,
    bool? showBrightestPoint,
    bool? showDarkestPoint,
    bool? enhanceColors,
  }) {
    return AppSettings(
      detectColorPeaks: detectColorPeaks ?? this.detectColorPeaks,
      spectrumUnit: spectrumUnit ?? this.spectrumUnit,
      showBrightestPoint: showBrightestPoint ?? this.showBrightestPoint,
      showDarkestPoint: showDarkestPoint ?? this.showDarkestPoint,
      enhanceColors: enhanceColors ?? this.enhanceColors,
    );
  }

  @override
  List<Object?> get props => [
    detectColorPeaks,
    spectrumUnit,
    showBrightestPoint,
    showDarkestPoint,
    enhanceColors,
  ];
}

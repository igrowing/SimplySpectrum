import 'package:equatable/equatable.dart';

/// Which unit the Spectrum sector's X axis and color labels use.
enum SpectrumUnit { wavelengthNm, frequencyHz }

/// The app's chosen color scheme. Kept as a plain domain enum (rather
/// than importing Flutter's `ThemeMode` here) so this layer stays
/// framework-agnostic; the presentation layer maps this to
/// `ThemeMode` when configuring `MaterialApp`.
enum AppThemeMode { system, light, dark }

/// One of the 4 quadrants of the main screen's 2x2 sector grid (see
/// `HomePage`), addressed independently of whatever functionality is
/// currently assigned to it.
enum SectorPosition { topLeft, topRight, bottomLeft, bottomRight }

/// One of the 4 pieces of functionality that can be assigned to any
/// [SectorPosition] via the Settings screen's "Main screen order"
/// section. Every position always holds exactly one of these, and each
/// of these is always assigned to exactly one position - see
/// [AppSettings.withSectorWidget].
enum SectorWidgetType { camera, colorChart, luminosityChart, controls }

/// The display name shown in the "Main screen order" dropdowns.
extension SectorWidgetTypeLabel on SectorWidgetType {
  String get label {
    switch (this) {
      case SectorWidgetType.camera:
        return 'Camera';
      case SectorWidgetType.colorChart:
        return 'Color chart';
      case SectorWidgetType.luminosityChart:
        return 'Luminosity chart';
      case SectorWidgetType.controls:
        return 'Controls';
    }
  }
}

/// User-configurable, persisted app settings (Settings screen).
class AppSettings extends Equatable {
  const AppSettings({
    this.detectColorPeaks = true,
    this.spectrumUnit = SpectrumUnit.wavelengthNm,
    this.showExtremeLightSpots = false,
    this.enhanceColors = false,
    this.themeMode = AppThemeMode.system,
    this.topLeftSector = SectorWidgetType.camera,
    this.topRightSector = SectorWidgetType.colorChart,
    this.bottomLeftSector = SectorWidgetType.luminosityChart,
    this.bottomRightSector = SectorWidgetType.controls,
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

  /// Light/dark/system color scheme for the app's chrome. Default:
  /// follow the system setting. This now applies to the whole app,
  /// including the main sector grid - see `HomePage` - with the sole
  /// exception of the live camera texture itself, which always stays
  /// untouched by the theme.
  final AppThemeMode themeMode;

  /// Which functionality currently occupies each quadrant of the main
  /// screen's 2x2 sector grid (see `HomePage`, and the Settings
  /// screen's "Main screen order" section). Defaults to the grid's
  /// original, fixed arrangement: Camera / Color chart on top,
  /// Luminosity chart / Controls on the bottom.
  ///
  /// These four are always a permutation of all of [SectorWidgetType]'s
  /// values - never construct/copy this directly to set them
  /// independently (that could produce a duplicate or missing widget);
  /// go through [withSectorWidget] instead, which preserves that
  /// invariant by swapping two positions at once.
  final SectorWidgetType topLeftSector;
  final SectorWidgetType topRightSector;
  final SectorWidgetType bottomLeftSector;
  final SectorWidgetType bottomRightSector;

  /// The widget currently assigned to [position].
  SectorWidgetType sectorAt(SectorPosition position) {
    switch (position) {
      case SectorPosition.topLeft:
        return topLeftSector;
      case SectorPosition.topRight:
        return topRightSector;
      case SectorPosition.bottomLeft:
        return bottomLeftSector;
      case SectorPosition.bottomRight:
        return bottomRightSector;
    }
  }

  /// Moves [widget] into [position], swapping it with whatever widget
  /// currently occupies that position: that displaced widget takes over
  /// wherever [widget] used to be. This is what the "Main screen order"
  /// dropdowns call on selection - it's the only way to change the
  /// layout, since it's the only way that can't produce a duplicate or
  /// a missing widget among the 4 positions.
  AppSettings withSectorWidget(
    SectorPosition position,
    SectorWidgetType widget,
  ) {
    final displaced = sectorAt(position);
    if (displaced == widget) return this;

    final sourcePosition = SectorPosition.values.firstWhere(
      (candidate) => sectorAt(candidate) == widget,
    );
    return _withSectorAt(
      position,
      widget,
    )._withSectorAt(sourcePosition, displaced);
  }

  /// Sets a single position's widget directly - only safe when used in
  /// pairs that keep all 4 positions a valid permutation (see
  /// [withSectorWidget], the one caller of this).
  AppSettings _withSectorAt(SectorPosition position, SectorWidgetType widget) {
    return copyWith(
      topLeftSector: position == SectorPosition.topLeft ? widget : null,
      topRightSector: position == SectorPosition.topRight ? widget : null,
      bottomLeftSector: position == SectorPosition.bottomLeft ? widget : null,
      bottomRightSector: position == SectorPosition.bottomRight ? widget : null,
    );
  }

  AppSettings copyWith({
    bool? detectColorPeaks,
    SpectrumUnit? spectrumUnit,
    bool? showExtremeLightSpots,
    bool? enhanceColors,
    AppThemeMode? themeMode,
    SectorWidgetType? topLeftSector,
    SectorWidgetType? topRightSector,
    SectorWidgetType? bottomLeftSector,
    SectorWidgetType? bottomRightSector,
  }) {
    return AppSettings(
      detectColorPeaks: detectColorPeaks ?? this.detectColorPeaks,
      spectrumUnit: spectrumUnit ?? this.spectrumUnit,
      showExtremeLightSpots:
          showExtremeLightSpots ?? this.showExtremeLightSpots,
      enhanceColors: enhanceColors ?? this.enhanceColors,
      themeMode: themeMode ?? this.themeMode,
      topLeftSector: topLeftSector ?? this.topLeftSector,
      topRightSector: topRightSector ?? this.topRightSector,
      bottomLeftSector: bottomLeftSector ?? this.bottomLeftSector,
      bottomRightSector: bottomRightSector ?? this.bottomRightSector,
    );
  }

  /// Whether [topLeftSector]/[topRightSector]/[bottomLeftSector]/
  /// [bottomRightSector] form a valid permutation of all 4
  /// [SectorWidgetType] values - i.e. every widget assigned to exactly
  /// one position. Used to reject corrupt persisted layouts (see
  /// `SettingsRepositoryImpl.load()`) rather than risk rendering a
  /// sector grid with a duplicated or missing widget.
  bool get hasValidSectorLayout => SectorWidgetType.values.every(
    (type) =>
        SectorPosition.values.where((p) => sectorAt(p) == type).length == 1,
  );

  @override
  List<Object?> get props => [
    detectColorPeaks,
    spectrumUnit,
    showExtremeLightSpots,
    enhanceColors,
    themeMode,
    topLeftSector,
    topRightSector,
    bottomLeftSector,
    bottomRightSector,
  ];
}

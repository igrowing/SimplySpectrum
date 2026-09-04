import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Link to the developer's "Buy me a coffee" page, shown at the bottom of
/// the Settings screen.
const String kBuyMeACoffeeUrl = 'https://www.buymeacoffee.com/igrowing';

/// Full-screen settings, reached via the Controls sector's gear button.
/// Holds every persisted app preference plus app identity info at the
/// bottom, so the small Controls sector itself only needs a handful of
/// large, frequently-used buttons.
///
/// Unlike the always-dark camera/analysis viewfinder, this screen (and
/// the info screens) follow the user's chosen theme, so it's built with
/// theme-derived colors throughout rather than hardcoded dark values.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Consumer<SettingsViewModel>(
        builder: (context, viewModel, _) {
          if (!viewModel.isLoaded) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final settings = viewModel.settings;
          return Scrollbar(
            thumbVisibility: true,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _SettingSwitch(
                  title: 'Detect color peaks',
                  value: settings.detectColorPeaks,
                  onChanged: viewModel.setDetectColorPeaks,
                ),
                _SettingSwitch(
                  title: 'Show color in wave frequency (Hz)',
                  subtitle: 'Off shows wavelength (nm) instead',
                  value: settings.spectrumUnit == SpectrumUnit.frequencyHz,
                  onChanged: (value) => viewModel.setSpectrumUnit(
                    value
                        ? SpectrumUnit.frequencyHz
                        : SpectrumUnit.wavelengthNm,
                  ),
                ),
                _SettingSwitch(
                  title: 'Show the extreme light spots',
                  subtitle:
                      'Black circle shows the brightest spot. White circle '
                      'shows the darkest spot',
                  value: settings.showExtremeLightSpots,
                  onChanged: viewModel.setShowExtremeLightSpots,
                ),
                _SettingSwitch(
                  title: 'Enhance colors',
                  value: settings.enhanceColors,
                  onChanged: viewModel.setEnhanceColors,
                ),
                _ThemeModeSetting(
                  value: settings.themeMode,
                  onChanged: viewModel.setThemeMode,
                ),
                _ChartsPlacementSetting(
                  value: settings.chartsAtTop,
                  onChanged: viewModel.setChartsAtTop,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 32, 16, 0),
                  child: Divider(),
                ),
                const _AboutFooter(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// The Theme setting: a 3-way system/light/dark picker, styled to sit
/// naturally among the switches above it.
class _ThemeModeSetting extends StatelessWidget {
  const _ThemeModeSetting({required this.value, required this.onChanged});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theme', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(
            'Applies throughout the app; the live camera feed itself '
            'always stays as-is',
            style: subtitleStyle,
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppThemeMode>(
            segments: const [
              ButtonSegment(
                value: AppThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: AppThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {value},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

/// The "Charts placement" setting: a Top/Bottom segmented toggle that
/// decides which half of the main screen the combined chart occupies
/// (top/bottom in the vertical layout, left/right in the horizontal
/// one); the camera + controls take the other half.
class _ChartsPlacementSetting extends StatelessWidget {
  const _ChartsPlacementSetting({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Charts placement',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Which half of the screen shows the charts. The camera and '
            'controls take the other half (left/right instead of '
            'top/bottom in landscape).',
            style: subtitleStyle,
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Top'),
                icon: Icon(Icons.vertical_align_top),
              ),
              ButtonSegment(
                value: false,
                label: Text('Bottom'),
                icon: Icon(Icons.vertical_align_bottom),
              ),
            ],
            selected: {value},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

/// App name/version plus a "Buy me a coffee" link, shown at the very
/// bottom of the Settings screen.
class _AboutFooter extends StatefulWidget {
  const _AboutFooter();

  @override
  State<_AboutFooter> createState() => _AboutFooterState();
}

class _AboutFooterState extends State<_AboutFooter> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPackageInfo());
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _packageInfo = info);
    } on Object catch (error) {
      const DeveloperAppLogger().warning(
        'Failed to load package info: $error',
      );
    }
  }

  Future<void> _openBuyMeACoffee() async {
    final uri = Uri.parse(kBuyMeACoffeeUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (error) {
      const DeveloperAppLogger().warning(
        'Failed to open $kBuyMeACoffeeUrl: $error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _packageInfo;
    final label = info == null
        ? 'SimplySpectrum'
        : '${info.appName} v${info.version}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _openBuyMeACoffee,
            icon: const Icon(Icons.coffee, color: Colors.amber),
            label: const Text(
              'Buy me a coffee',
              style: TextStyle(color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }
}

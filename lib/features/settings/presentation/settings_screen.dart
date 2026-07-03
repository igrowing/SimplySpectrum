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
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101014),
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 32, 16, 0),
                  child: Divider(color: Colors.white24),
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
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
      value: value,
      onChanged: onChanged,
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
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
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

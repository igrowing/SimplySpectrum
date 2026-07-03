import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_view_model.dart';

/// The Settings sector: a scrollable panel of switches, with a visible
/// scrollbar so it's clear more settings exist below the fold.
class SettingsSectorWidget extends StatelessWidget {
  const SettingsSectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF101014),
      // A Material ancestor is required here (rather than painting the
      // switches directly on the ColoredBox) so SwitchListTile/ListTile
      // ink splashes are still visible on top of the background color.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Consumer<SettingsViewModel>(
                builder: (context, viewModel, _) {
                  if (!viewModel.isLoaded) {
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final settings = viewModel.settings;
                  return Scrollbar(
                    thumbVisibility: true,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        _SettingSwitch(
                          title: 'Detect color peaks',
                          value: settings.detectColorPeaks,
                          onChanged: viewModel.setDetectColorPeaks,
                        ),
                        _SettingSwitch(
                          title: 'Show color in wave frequency (Hz)',
                          subtitle: 'Off shows wavelength (nm) instead',
                          value:
                              settings.spectrumUnit == SpectrumUnit.frequencyHz,
                          onChanged: (value) => viewModel.setSpectrumUnit(
                            value
                                ? SpectrumUnit.frequencyHz
                                : SpectrumUnit.wavelengthNm,
                          ),
                        ),
                        _SettingSwitch(
                          title: 'Show the most luminous point',
                          value: settings.showBrightestPoint,
                          onChanged: viewModel.setShowBrightestPoint,
                        ),
                        _SettingSwitch(
                          title: 'Show the darkest point',
                          value: settings.showDarkestPoint,
                          onChanged: viewModel.setShowDarkestPoint,
                        ),
                        _SettingSwitch(
                          title: 'Enhance colors',
                          value: settings.enhanceColors,
                          onChanged: viewModel.setEnhanceColors,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
      dense: true,
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
      value: value,
      onChanged: onChanged,
    );
  }
}

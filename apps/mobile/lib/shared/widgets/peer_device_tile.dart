import 'package:flutter/material.dart';

import '../../shared/models/peer_device.dart';
import '../../core/theme/app_theme.dart';

/// Displays a single peer device in the discovery list.
class PeerDeviceTile extends StatelessWidget {
  const PeerDeviceTile({
    super.key,
    required this.peer,
    this.onTap,
  });

  final PeerDevice peer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingMd,
          ),
          child: Row(
            children: [
              // Platform icon
              _PlatformIcon(platform: peer.platform, colorScheme: cs),
              const SizedBox(width: AppTheme.spacingMd),

              // Name and source
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(peer.name, style: tt.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      peer.source.label,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Signal strength
              if (peer.signalStrength != null)
                _SignalIndicator(
                  strength: peer.signalStrengthNormalized ?? 0,
                  colorScheme: cs,
                ),

              const SizedBox(width: AppTheme.spacingSm),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformIcon extends StatelessWidget {
  const _PlatformIcon({
    required this.platform,
    required this.colorScheme,
  });

  final PeerPlatform platform;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final icon = switch (platform) {
      PeerPlatform.android => Icons.android_rounded,
      PeerPlatform.ios => Icons.phone_iphone_rounded,
      PeerPlatform.macos => Icons.laptop_mac_rounded,
      PeerPlatform.windows => Icons.desktop_windows_rounded,
      PeerPlatform.linux => Icons.terminal_rounded,
      PeerPlatform.unknown => Icons.devices_rounded,
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Icon(icon, size: 22, color: colorScheme.onSecondaryContainer),
    );
  }
}

class _SignalIndicator extends StatelessWidget {
  const _SignalIndicator({
    required this.strength,
    required this.colorScheme,
  });

  final double strength; // 0.0 – 1.0
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final bars = (strength * 3).ceil().clamp(0, 3);
    final color = strength > 0.6
        ? colorScheme.primary
        : strength > 0.3
            ? colorScheme.tertiary
            : colorScheme.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 2,
      children: List.generate(3, (i) {
        final height = 8.0 + (i * 4);
        return Container(
          width: 4,
          height: height,
          decoration: BoxDecoration(
            color: i < bars ? color : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

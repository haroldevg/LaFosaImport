import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Small "vX.Y.Z" label meant to sit in a screen corner — lets staff eyeball
/// which build a user (or a bug report) is on without digging through
/// settings, and gives a quick sanity check against `config/settings.
/// minAppVersion` when something isn't behaving as expected.
class AppVersionBadge extends StatelessWidget {
  const AppVersionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final version = snap.data?.version;
        if (version == null) return const SizedBox.shrink();
        return Text(
          'v$version',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        );
      },
    );
  }
}

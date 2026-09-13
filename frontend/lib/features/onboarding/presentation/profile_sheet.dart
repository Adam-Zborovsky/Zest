import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_inline_error.dart';
import '../../../core/widgets/zest_sheet.dart';
import '../application/session_controller.dart';
import '../application/session_providers.dart';
import '../data/session_stores.dart';

/// The top-bar entry to the on-device profile sheet. Never watches or reads
/// a session provider during build — only inside [onPressed] — so any
/// screen that renders this button in a test pumped without session
/// overrides is unaffected.
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: const ValueKey('open-profile'),
    tooltip: 'Your profile',
    icon: const Icon(Icons.person_outline_rounded),
    onPressed: () => _open(context, ref),
  );

  void _open(BuildContext context, WidgetRef ref) {
    final controller = ref.read(sessionControllerProvider);
    showZestSheet(
      context: context,
      title: controller.profile?.displayName ?? 'On this device',
      child: ProfileSheetBody(controller: controller),
    );
  }
}

/// The sheet body: since-date, the honest sign-out note, and Sign out.
///
/// Sign-out is attempted while the sheet is still open; the sheet closes
/// only once it succeeds. On [SessionStorageException] the sheet stays open
/// and states the failure inline instead, matching how the collection
/// screens surface storage failures.
class ProfileSheetBody extends StatefulWidget {
  const ProfileSheetBody({super.key, required this.controller});

  final SessionController controller;

  @override
  State<ProfileSheetBody> createState() => _ProfileSheetBodyState();
}

class _ProfileSheetBodyState extends State<ProfileSheetBody> {
  bool _busy = false;
  String? _error;

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.signOut();
      if (mounted) Navigator.of(context).pop();
    } on SessionStorageException {
      if (mounted) {
        setState(() {
          _error = "Couldn't sign out on this device. Try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.controller.profile;
    final since = profile == null
        ? null
        : MaterialLocalizations.of(context).formatFullDate(profile.createdAt);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (since != null) ...[
          Text('Kept on this device since $since'),
          const SizedBox(height: ZestSpace.md),
        ],
        Text(
          'Signing out keeps your saves and photos on this device.',
          style: textTheme.bodyMedium?.copyWith(
            color: ZestPalette.secondaryInk,
          ),
        ),
        const SizedBox(height: ZestSpace.lg),
        ZestButton(
          key: const ValueKey('profile-sign-out'),
          label: _busy ? 'Signing out…' : 'Sign out',
          kind: ZestButtonKind.danger,
          onPressed: _busy ? null : _signOut,
        ),
        if (_error != null) ...[
          const SizedBox(height: ZestSpace.md),
          ZestInlineError(_error!),
        ],
      ],
    );
  }
}

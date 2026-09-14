import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_inline_error.dart';
import '../../../core/widgets/zest_sheet.dart';
import '../../account/domain/account.dart';
import '../../collection/sync/sync_contract.dart';
import '../../collection/sync/sync_providers.dart';
import '../application/session_controller.dart';
import '../application/session_providers.dart';

/// The top-bar entry to the account profile sheet. Never watches or reads
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
      title: controller.account?.email ?? 'Your account',
      child: ProfileSheetBody(controller: controller, account: controller.account),
    );
  }
}

/// The sheet body: account email and creation date, live sync status,
/// "Sync now", and sign out. See `docs/ACCOUNTS.md` for the sync rules and
/// ownership behavior sign-out relies on.
///
/// Sign-out is attempted while the sheet is still open; the sheet closes
/// only once it succeeds. On failure the sheet stays open and states it
/// inline instead, matching how the collection screens surface storage
/// failures.
class ProfileSheetBody extends ConsumerStatefulWidget {
  const ProfileSheetBody({super.key, required this.controller, this.account});

  final SessionController controller;

  /// Read once when the sheet opens; the email and join date do not change
  /// for the life of a session.
  final Account? account;

  @override
  ConsumerState<ProfileSheetBody> createState() => _ProfileSheetBodyState();
}

class _ProfileSheetBodyState extends ConsumerState<ProfileSheetBody> {
  bool _signingOut = false;
  String? _signOutError;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
      _signOutError = null;
    });
    try {
      await widget.controller.signOut();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _signOutError = "Couldn't sign out. Try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final textTheme = Theme.of(context).textTheme;
    final statusAsync = ref.watch(syncStatusProvider);
    final syncing = statusAsync.value?.phase == SyncPhase.syncing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (account != null) ...[
          Text(
            'Signed in since ${_joinDate(context, account.createdAt)}',
            style: textTheme.bodyMedium?.copyWith(
              color: ZestPalette.secondaryInk,
            ),
          ),
          const SizedBox(height: ZestSpace.lg),
        ],
        _SyncStatusLine(status: statusAsync),
        const SizedBox(height: ZestSpace.md),
        ZestButton(
          key: const ValueKey('profile-sync-now'),
          label: 'Sync now',
          kind: ZestButtonKind.secondary,
          onPressed: syncing
              ? null
              : () => ref.read(collectionSyncProvider).syncNow(),
        ),
        const SizedBox(height: ZestSpace.lg),
        ZestButton(
          key: const ValueKey('profile-sign-out'),
          label: _signingOut ? 'Signing out…' : 'Sign out',
          kind: ZestButtonKind.danger,
          onPressed: _signingOut ? null : _signOut,
        ),
        const SizedBox(height: ZestSpace.xs),
        Text(
          'Signing out keeps this device\'s copy until someone else signs in.',
          style: textTheme.bodySmall?.copyWith(color: ZestPalette.secondaryInk),
        ),
        if (_signOutError != null) ...[
          const SizedBox(height: ZestSpace.md),
          ZestInlineError(_signOutError!),
        ],
      ],
    );
  }

  static String _joinDate(BuildContext context, DateTime createdAt) =>
      MaterialLocalizations.of(context).formatMediumDate(createdAt.toLocal());
}

/// The live sync status line: idle/synced, syncing, offline, or failed. A
/// live region so a screen reader hears status changes without moving
/// focus.
class _SyncStatusLine extends StatefulWidget {
  const _SyncStatusLine({required this.status});

  final AsyncValue<SyncStatus> status;

  @override
  State<_SyncStatusLine> createState() => _SyncStatusLineState();
}

class _SyncStatusLineState extends State<_SyncStatusLine>
    with SingleTickerProviderStateMixin {
  AnimationController? _pop;
  SyncPhase? _lastPhase;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePop();
  }

  @override
  void didUpdateWidget(covariant _SyncStatusLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybePop();
  }

  void _maybePop() {
    final phase = widget.status.value?.phase;
    final enteredSyncing = phase == SyncPhase.syncing && _lastPhase != SyncPhase.syncing;
    _lastPhase = phase;
    if (!enteredSyncing || !mounted) return;
    if (ZestMotion.reduced(context)) return;
    _pop ??= AnimationController(vsync: this, duration: ZestMotion.pop);
    _pop!.forward(from: 0);
  }

  @override
  void dispose() {
    _pop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status.value;
    final phase = status?.phase;
    final textTheme = Theme.of(context).textTheme;
    final (icon, label) = switch (phase) {
      null => (Icons.hourglass_empty_rounded, 'Not synced yet'),
      SyncPhase.syncing => (Icons.sync_rounded, 'Syncing…'),
      SyncPhase.offline => (
        Icons.cloud_off_rounded,
        'Offline — changes will sync when the server is reachable.',
      ),
      SyncPhase.failed => (Icons.error_outline_rounded, "Couldn't sync. Try again."),
      SyncPhase.idle => status?.lastSyncedAt == null
          ? (Icons.hourglass_empty_rounded, 'Not synced yet')
          : (Icons.check_circle_outline_rounded, 'Synced ${_relative(status!.lastSyncedAt!)}'),
    };
    final reduced = ZestMotion.reduced(context);
    final marker = reduced || _pop == null
        ? Icon(icon, size: 20, color: ZestPalette.secondaryInk)
        : AnimatedBuilder(
            animation: _pop!,
            builder: (context, child) => Transform.scale(
              scale: 0.85 + 0.15 * ZestMotion.easeOut.transform(_pop!.value),
              child: child,
            ),
            child: Icon(icon, size: 20, color: ZestPalette.secondaryInk),
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ExcludeSemantics(child: marker),
        const SizedBox(width: ZestSpace.sm),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: ZestPalette.leaf,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _relative(DateTime lastSyncedAt) {
    final diff = DateTime.now().difference(lastSyncedAt);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    final d = diff.inDays;
    return '$d day${d == 1 ? '' : 's'} ago';
  }
}

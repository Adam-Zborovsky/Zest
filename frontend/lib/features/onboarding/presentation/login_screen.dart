import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_art.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_inline_error.dart';
import '../application/session_providers.dart';
import '../data/session_stores.dart';
import '../domain/launch_destination.dart';
import '../domain/local_profile.dart';

/// The local-first login gate: an optional name and "Continue on this
/// device". No account, credential, or sync — the copy under the card says
/// so plainly. Replaces the M7 contract shell; the class name and const
/// no-argument constructor are the contract other tracks build against.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _nameController;
  late final LocalProfile? _lastProfile;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Read once, here, and nowhere in build: the M7 contract requires this
    // screen never watch a session provider during build, so app tests that
    // pump ZestApp before the state track wires session overrides keep
    // landing on home undisturbed. This screen only ever mounts once the
    // router has already sent someone to /login, so the provider is wired
    // by then.
    _lastProfile = ref.read(sessionControllerProvider).lastProfile;
    _nameController = TextEditingController(
      text: _lastProfile?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionControllerProvider)
          .continueOnDevice(displayName: _nameController.text);
      // The router's refresh redirect moves to home on success; nothing to
      // navigate here, and this widget may already be disposed by the time
      // the future settles.
    } on SessionStorageException {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't save your profile on this device. Try again.";
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NightBand(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    ZestSpace.page,
                    ZestSpace.md + topInset,
                    ZestSpace.page,
                    ZestSpace.lg,
                  ),
                  child: _band(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZestSpace.page,
                  ZestSpace.xl,
                  ZestSpace.page,
                  ZestSpace.xxl,
                ),
                child: _body(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _band(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          top: -6,
          right: -6,
          child: BotanicalArt(motif: BotanicalMotif.citrus, size: 40),
        ),
        const Positioned(
          bottom: 2,
          right: 34,
          child: BotanicalArt(motif: BotanicalMotif.garnish, size: 28),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: ZestPalette.peach,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(5),
                    child: BotanicalArt(size: 34),
                  ),
                ),
                const SizedBox(width: ZestSpace.sm),
                Text(
                  'Zest',
                  style: textTheme.headlineSmall?.copyWith(
                    color: ZestPalette.nightInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZestSpace.xl),
            Text(
              'Welcome',
              style: textTheme.labelMedium!.copyWith(
                color: ZestPalette.nightMuted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: ZestSpace.xs),
            Semantics(
              header: true,
              child: _heading(
                textTheme.displayMedium!.copyWith(color: ZestPalette.nightInk),
              ),
            ),
            const SizedBox(height: ZestSpace.md),
            Text(
              'Zest keeps your bar, saves, and photos on this device.',
              style: textTheme.bodyLarge!.copyWith(
                color: ZestPalette.nightMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heading(TextStyle style) {
    final name = _lastProfile?.displayName;
    if (_lastProfile == null) {
      return Text.rich(
        TextSpan(
          text: 'Pull up a ',
          children: [
            TextSpan(
              text: 'stool.',
              style: const TextStyle(
                color: ZestPalette.grapefruit,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        style: style,
      );
    }
    if (name == null) {
      return Text('Welcome back.', style: style);
    }
    return Text.rich(
      TextSpan(
        text: 'Welcome back, ',
        children: [
          TextSpan(
            text: '$name.',
            style: const TextStyle(color: ZestPalette.grapefruit),
          ),
        ],
      ),
      style: style,
    );
  }

  Widget _body(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZestCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                TextSpan(
                  text: 'Your name ',
                  children: [
                    TextSpan(
                      text: '(optional)',
                      style: textTheme.bodyMedium?.copyWith(
                        color: ZestPalette.secondaryInk,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: ZestSpace.sm),
              TextField(
                key: const ValueKey('login-name-field'),
                controller: _nameController,
                maxLength: LocalProfile.maxNameLength,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _continue(),
                decoration: const InputDecoration(
                  hintText: 'What should we call you?',
                  counterText: '',
                ),
              ),
              const SizedBox(height: ZestSpace.sm),
              ZestButton(
                key: const ValueKey('login-continue'),
                label: _busy ? 'Setting up…' : 'Continue on this device',
                onPressed: _busy ? null : _continue,
              ),
              if (_error != null) ...[
                const SizedBox(height: ZestSpace.md),
                ZestInlineError(_error!),
              ],
            ],
          ),
        ),
        const SizedBox(height: ZestSpace.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: ZestPalette.leaf,
              ),
            ),
            const SizedBox(width: ZestSpace.sm),
            Expanded(
              child: Text(
                'No account and no sync. Everything stays on this device.',
                style: textTheme.bodySmall?.copyWith(color: ZestPalette.leaf),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZestSpace.lg),
        Center(
          child: ZestButton(
            key: const ValueKey('login-replay-tour'),
            label: 'Replay the tour',
            kind: ZestButtonKind.quiet,
            expand: false,
            onPressed: () => context.go(SessionRoutes.onboarding),
          ),
        ),
      ],
    );
  }
}

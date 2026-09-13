import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_art.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../../core/widgets/lime_sprite.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_inline_error.dart';
import '../../account/data/account_repository.dart';
import '../application/session_providers.dart';

/// The M8 account gate: email, password, sign in, or create an account. This
/// is the interim functional shell after M7's local-first login was
/// superseded (`docs/ACCOUNTS.md`); a separate login UI track designs this
/// screen properly. The class name and const no-argument constructor are the
/// contract other tracks build against.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool register}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(sessionControllerProvider);
      final email = _emailController.text;
      final password = _passwordController.text;
      if (register) {
        await controller.register(email: email, password: password);
      } else {
        await controller.signIn(email: email, password: password);
      }
      // The router's refresh redirect moves to home on success; nothing to
      // navigate here, and this widget may already be disposed by the time
      // the future settles.
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() => _error = _copyFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _copyFor(AccountException error) {
    switch (error.failure) {
      case AccountFailure.invalidEmail:
        return 'Enter a valid email address.';
      case AccountFailure.weakPassword:
        return 'Use a password of 10 to 128 characters.';
      case AccountFailure.invalidCredentials:
        return 'Incorrect email or password.';
      case AccountFailure.emailTaken:
        return 'An account with that email already exists.';
      case AccountFailure.rateLimited:
        final retryAfter = error.retryAfter;
        return retryAfter == null
            ? 'Too many attempts. Try again later.'
            : 'Too many attempts. Try again in '
                  '${retryAfter.inSeconds} seconds.';
      case AccountFailure.unreachable:
        return "Couldn't reach the server. Check your connection.";
      case AccountFailure.server:
        return 'Something went wrong. Try again.';
    }
  }

  static const _bandHeightFraction = 0.56;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bandMinHeight = constraints.maxHeight * _bandHeightFraction;
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: bandMinHeight),
                    child: NightBand(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          ZestSpace.page,
                          ZestSpace.md + topInset,
                          ZestSpace.page,
                          ZestSpace.lg,
                        ),
                        child: Center(child: _band(context)),
                      ),
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
            );
          },
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
          top: -4,
          right: 0,
          child: LimeSprite(pose: LimeSpritePose.wave, size: 64),
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
              child: Text(
                'Sign in to your bar.',
                style: textTheme.displayMedium!.copyWith(
                  color: ZestPalette.nightInk,
                ),
              ),
            ),
            const SizedBox(height: ZestSpace.md),
            Text(
              'Your saves, variations, and photos sync to your account.',
              style: textTheme.bodyLarge!.copyWith(
                color: ZestPalette.nightMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    return ZestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Email', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: ZestSpace.sm),
          TextField(
            key: const ValueKey('login-email-field'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'you@example.com'),
          ),
          const SizedBox(height: ZestSpace.md),
          Text('Password', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: ZestSpace.sm),
          TextField(
            key: const ValueKey('login-password-field'),
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(register: false),
            decoration: const InputDecoration(hintText: 'At least 10 characters'),
          ),
          const SizedBox(height: ZestSpace.lg),
          ZestButton(
            key: const ValueKey('login-sign-in'),
            label: _busy ? 'Signing in…' : 'Sign in',
            onPressed: _busy ? null : () => _submit(register: false),
          ),
          const SizedBox(height: ZestSpace.sm),
          ZestButton(
            key: const ValueKey('login-create-account'),
            label: _busy ? 'Please wait…' : 'Create account',
            kind: ZestButtonKind.secondary,
            onPressed: _busy ? null : () => _submit(register: true),
          ),
          if (_error != null) ...[
            const SizedBox(height: ZestSpace.md),
            ZestInlineError(_error!),
          ],
        ],
      ),
    );
  }
}

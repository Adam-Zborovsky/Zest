import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_art.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../../core/widgets/lime_sprite.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_inline_error.dart';
import '../../account/data/account_repository.dart';
import '../../account/domain/account.dart';
import '../application/session_providers.dart';
import '../domain/launch_destination.dart';

enum _AuthMode { signIn, createAccount }

/// The M8 account gate: one card with a segmented choice between signing in
/// and creating an account, honest sync copy, and the error copy for every
/// `AccountFailure` (`docs/ACCOUNTS.md`). The redirect driven by
/// `SessionController` handles navigation on success; this screen never
/// navigates itself.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  String? _serverError;
  bool _offerSignInInstead = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    if (_busy || mode == _mode) return;
    setState(() {
      _mode = mode;
      // The email is kept; the password is not carried between modes.
      _passwordController.clear();
      _emailError = null;
      _passwordError = null;
      _serverError = null;
      _offerSignInInstead = false;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final normalizedEmail = AccountRules.normalizeEmail(_emailController.text);
    final password = _passwordController.text;
    final passwordOk = AccountRules.isAcceptablePassword(password);
    setState(() {
      _emailError = normalizedEmail == null
          ? 'Enter a valid email address.'
          : null;
      _passwordError = passwordOk ? null : 'Use at least 10 characters.';
      _serverError = null;
      _offerSignInInstead = false;
    });
    if (normalizedEmail == null || !passwordOk) return;

    setState(() => _busy = true);
    try {
      final controller = ref.read(sessionControllerProvider);
      if (_mode == _AuthMode.createAccount) {
        await controller.register(email: normalizedEmail, password: password);
      } else {
        await controller.signIn(email: normalizedEmail, password: password);
      }
      // The router's refresh redirect moves to home on success; nothing to
      // navigate here, and this widget may already be disposed by the time
      // the future settles.
    } on AccountException catch (error) {
      if (!mounted) return;
      _applyFailure(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyFailure(AccountException error) {
    switch (error.failure) {
      case AccountFailure.invalidEmail:
        setState(() => _emailError = 'Enter a valid email address.');
      case AccountFailure.weakPassword:
        setState(() => _passwordError = 'Use at least 10 characters.');
      case AccountFailure.invalidCredentials:
        setState(() => _serverError = "That email and password don't match.");
      case AccountFailure.emailTaken:
        setState(() {
          _serverError =
              'An account with that email already exists. Sign in instead.';
          _offerSignInInstead = true;
        });
      case AccountFailure.rateLimited:
        setState(() => _serverError = _rateLimitedCopy(error.retryAfter));
      case AccountFailure.unreachable:
        setState(
          () => _serverError =
              "Can't reach the Zest server. Check that it's running and "
              "you're on the same Wi-Fi.",
        );
      case AccountFailure.server:
        setState(
          () => _serverError = 'Something went wrong on the server. Try again.',
        );
    }
  }

  static String _rateLimitedCopy(Duration? retryAfter) {
    if (retryAfter == null) return 'Too many attempts. Try again later.';
    final rawMinutes = retryAfter.inMilliseconds / Duration.millisecondsPerMinute;
    final minutes = rawMinutes.ceil().clamp(1, 1 << 30);
    final unit = minutes == 1 ? 'minute' : 'minutes';
    return 'Too many attempts. Try again in $minutes $unit.';
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
    final signIn = _mode == _AuthMode.signIn;
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
              'Your account',
              style: textTheme.labelMedium!.copyWith(
                color: ZestPalette.nightMuted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: ZestSpace.xs),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                signIn ? 'Sign in to your bar.' : 'Create your bar.',
                style: textTheme.displayMedium!.copyWith(
                  color: ZestPalette.nightInk,
                ),
              ),
            ),
            const SizedBox(height: ZestSpace.md),
            Text(
              'Keep your saves, variations, and photos with you.',
              style: textTheme.bodyLarge!.copyWith(color: ZestPalette.nightMuted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _body(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ZestCard(
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ModeSwitch(mode: _mode, enabled: !_busy, onChanged: _switchMode),
              const SizedBox(height: ZestSpace.lg),
              _emailField(context),
              const SizedBox(height: ZestSpace.md),
              _passwordField(context),
              const SizedBox(height: ZestSpace.lg),
              ZestButton(
                key: const ValueKey('login-submit'),
                label: _submitLabel,
                onPressed: _busy ? null : _submit,
              ),
              if (_serverError != null) ...[
                const SizedBox(height: ZestSpace.md),
                ZestInlineError(_serverError!),
              ],
              if (_offerSignInInstead) ...[
                const SizedBox(height: ZestSpace.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ZestButton(
                    key: const ValueKey('login-sign-in-instead'),
                    label: 'Sign in instead',
                    kind: ZestButtonKind.quiet,
                    expand: false,
                    onPressed: () => _switchMode(_AuthMode.signIn),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: ZestSpace.lg),
      Text(
        'Your saves and photos sync to your Zest account.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: ZestPalette.secondaryInk),
      ),
      const SizedBox(height: ZestSpace.md),
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

  String get _submitLabel {
    if (_busy) {
      return _mode == _AuthMode.createAccount
          ? 'Creating account…'
          : 'Signing in…';
    }
    return _mode == _AuthMode.createAccount ? 'Create account' : 'Sign in';
  }

  Widget _emailField(BuildContext context) => Semantics(
    liveRegion: _emailError != null,
    child: TextField(
      key: const ValueKey('login-email-field'),
      controller: _emailController,
      enabled: !_busy,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'you@example.com',
        errorText: _emailError,
      ),
    ),
  );

  Widget _passwordField(BuildContext context) {
    final createAccount = _mode == _AuthMode.createAccount;
    return Semantics(
      liveRegion: _passwordError != null,
      child: TextField(
        key: const ValueKey('login-password-field'),
        controller: _passwordController,
        enabled: !_busy,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        autofillHints: [
          createAccount ? AutofillHints.newPassword : AutofillHints.password,
        ],
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Password',
          errorText: _passwordError,
          helperText: createAccount && _passwordError == null
              ? 'At least 10 characters.'
              : null,
          suffixIcon: IconButton(
            key: const ValueKey('login-password-toggle'),
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: _busy
                ? null
                : () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ),
    );
  }
}

/// The Sign in / Create account segmented choice. Both segments are 48px
/// targets; the selected segment inverts to peach paper with leaf ink,
/// matching the Night Garden "selected controls invert" rule.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final _AuthMode mode;
  final bool enabled;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: ZestPalette.celery,
      borderRadius: ZestShape.pill,
    ),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _segment(
              context,
              key: 'login-mode-sign-in',
              value: _AuthMode.signIn,
              label: 'Sign in',
            ),
          ),
          Expanded(
            child: _segment(
              context,
              key: 'login-mode-create-account',
              value: _AuthMode.createAccount,
              label: 'Create account',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _segment(
    BuildContext context, {
    required String key,
    required _AuthMode value,
    required String label,
  }) {
    final selected = mode == value;
    final textTheme = Theme.of(context).textTheme;
    final foreground = selected
        ? ZestPalette.leaf
        : enabled
        ? ZestPalette.secondaryInk
        : ZestPalette.disabledInk;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: enabled && !selected ? () => onChanged(value) : null,
      child: Material(
        key: ValueKey(key),
        color: selected ? ZestPalette.peach : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled && !selected ? () => onChanged(value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: ZestSpace.touchTarget),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

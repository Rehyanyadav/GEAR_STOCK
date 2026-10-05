import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/liquid_background.dart';
import '../../../widgets/theme_mode_selector.dart';
import '../data/auth_repository.dart';
import 'auth_notifier.dart';

import '../../../widgets/gooey_hover_button.dart';
/// Production Login screen.
///
/// Replaced the original [StatefulWidget] + [setState] implementation with:
/// - [ConsumerStatefulWidget] watching [authNotifierProvider]
/// - Email regex + password ≥ 6 char validation (inline)
/// - Loading spinner that disables the button during auth
/// - Typed error banner (wrong credentials / no internet / server error)
/// - FocusNode chain: email → password → submit on keyboard "done"
/// - Password visibility toggle
/// - Animated cog / gear branding (unchanged from original)
/// - go_router redirect handles navigation on success — no [Navigator] calls
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'staff@gearstock.in');
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  String? _errorMessage;
  Timer? _rateLimitTimer;
  int _retrySeconds = 0;

  late final AnimationController _entryController;
  late final Animation<double> _brandScale;
  late final Animation<double> _brandOpacity;
  late final Animation<Offset> _brandSlide;

  // ── Validation ────────────────────────────────────────────────────────────

  static final _emailRegex = RegExp(
    r'^[\w.+\-]+@[\w\-]+\.[a-z]{2,}$',
    caseSensitive: false,
  );

  String? _validateEmail(String? v) {
    final l10n = AppLocalizations.of(context);
    if (v == null || v.trim().isEmpty) return l10n.errorEmailRequired;
    if (!_emailRegex.hasMatch(v.trim())) return l10n.errorEmailInvalid;
    return null;
  }

  String? _validatePassword(String? v) {
    final l10n = AppLocalizations.of(context);
    if (v == null || v.isEmpty) return l10n.errorPasswordRequired;
    if (v.length < 6) return l10n.errorPasswordTooShort;
    return null;
  }

  // ── Error mapping ─────────────────────────────────────────────────────────

  String _errorFor(Object error) {
    final l10n = AppLocalizations.of(context);
    return switch (error) {
      WrongCredentials() => l10n.errorWrongCredentials,
      NoInternet() => l10n.errorNoInternet,
      RateLimited(:final retryAfter) => l10n.errorRateLimited(
        retryAfter.inSeconds,
      ),
      ServerError(:final message) => l10n.errorServer(message),
      _ => l10n.errorGeneric,
    };
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Clear previous banner before revalidating.
    if (_errorMessage != null) setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authNotifierProvider.notifier)
        .login(_emailCtrl.text.trim(), _passwordCtrl.text);

    // Guard against unmounted widget after the async gap.
    if (!mounted) return;

    final auth = ref.read(authNotifierProvider);
    auth.whenOrNull(
      error: (error, _) {
        if (error is RateLimited) {
          _startRateLimit(error.retryAfter);
        }
        setState(() => _errorMessage = _errorFor(error));
      },
    );
    // On [Authenticated], go_router redirect fires automatically — no push().
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'codesalph92@gmail.com',
      queryParameters: const {'subject': 'GearStock support'},
    );
    try {
      final opened = await launchUrl(uri);
      if (!opened && mounted) _showSupportFallback();
    } on PlatformException {
      if (mounted) _showSupportFallback();
    }
  }

  void _showSupportFallback() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open your email app. Contact codesalph92@gmail.com.',
        ),
      ),
    );
  }

  void _startRateLimit(Duration duration) {
    _rateLimitTimer?.cancel();
    setState(() {
      _retrySeconds = (duration.inMilliseconds + 999) ~/ 1000;
    });
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_retrySeconds > 0) _retrySeconds--;
      });
      if (_retrySeconds == 0) {
        _rateLimitTimer?.cancel();
        _rateLimitTimer = null;
      }
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _brandScale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _brandSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );
    _brandOpacity = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _rateLimitTimer?.cancel();
    _entryController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final isRateLimited = _retrySeconds > 0;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: LiquidBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 76, 24, 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ── Animated brand section ──────────────────────────
                          FadeTransition(
                            opacity: _brandOpacity,
                            child: SlideTransition(
                              position: _brandSlide,
                              child: ScaleTransition(
                                scale: _brandScale,
                                child: Container(
                                  width: 104,
                                  height: 104,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withAlpha(18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary.withAlpha(24),
                                          blurRadius: 18,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/images/gearstock_logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.loginTitle,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.loginSubtitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Error banner ────────────────────────────────────
                          if (_errorMessage != null) ...[
                            _ErrorBanner(message: _errorMessage!),
                            const SizedBox(height: 14),
                          ],

                          // ── Login form card ─────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(10),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Email
                                Text(
                                  l10n.emailLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _emailCtrl,
                                  enabled: !isLoading,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  onFieldSubmitted: (_) => FocusScope.of(
                                    context,
                                  ).requestFocus(_passwordFocus),
                                  validator: _validateEmail,
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(
                                      Icons.badge_outlined,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                                    hintText: l10n.emailHint,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Password
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      l10n.passwordLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: isLoading
                                          ? null
                                          : () {
                                              // Phase 2: password reset flow
                                            },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        l10n.forgotPassword,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _passwordCtrl,
                                  focusNode: _passwordFocus,
                                  enabled: !isLoading,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: _validatePassword,
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                                    hintText: l10n.passwordHint,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                _LoginActionButton(
                                  isLoading: isLoading,
                                  isRateLimited: isRateLimited,
                                  retrySeconds: _retrySeconds,
                                  label: l10n.loginButton,
                                  onPressed: _submit,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          TextButton.icon(
                            onPressed: _contactSupport,
                            icon: Icon(
                              Icons.mail_outline_rounded,
                              size: 17,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Need help? Email support',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'codesalph92@gmail.com',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  '${l10n.appVersion}  •  ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppStatusColors.of(context).success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  l10n.serverStatus,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(top: 8, right: 16, child: const ThemeModeSelector()),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginActionButton extends StatelessWidget {
  const _LoginActionButton({
    required this.isLoading,
    required this.isRateLimited,
    required this.retrySeconds,
    required this.label,
    required this.onPressed,
  });

  final bool isLoading;
  final bool isRateLimited;
  final int retrySeconds;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: GooeyHoverButton(child: ElevatedButton(
                onPressed: isLoading || isRateLimited ? null : onPressed,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.12),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: isLoading
                      ? Row(
                          key: const ValueKey('login-loading'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 11),
                            const Text(
                              'Verifying shop access',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          key: const ValueKey('login-ready'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isRateLimited
                                  ? 'Try again in ${retrySeconds}s'
                                  : label,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!isRateLimited) ...[
                              const SizedBox(width: 9),
                              const Icon(Icons.arrow_forward_rounded, size: 19),
                            ],
                          ],
                        ),
                ),
              )),
            ),
            if (isLoading)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: colorScheme.onPrimary.withAlpha(180),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Error banner widget ───────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

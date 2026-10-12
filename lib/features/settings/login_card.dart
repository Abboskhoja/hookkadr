import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../ai/ai_clients.dart';
import '../ai/openrouter.dart';

/// "Sign in" connection: one OpenRouter account gives Claude, GPT and
/// Gemini (chat, video understanding, images) — no key typing.
class LoginCard extends StatefulWidget {
  const LoginCard({super.key});

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).loginOpenRouter();
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Fallback: sign in in the external browser, paste the shown code.
  Future<void> _loginWithCode() async {
    final app = AppScope.of(context);
    final start = OpenRouterAuth.startManual();
    await launchUrl(start.url, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    final ctl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kodni kiriting'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Brauzerda ko‘rsatilgan kod',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: const Text('Ulash'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (code == null || code.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await app.connectOpenRouterCode(code, start.verifier);
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.palette;
    final connected = app.isConnected(ProviderKind.openrouter);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(LucideIcons.logIn),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  connected ? 'Hisob ulangan' : 'Hisob bilan kirish',
                  style: AppText.title(context).copyWith(fontSize: 17),
                ),
              ),
              if (connected)
                const Icon(LucideIcons.circleCheck, color: AppColors.success),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bitta login — Claude, GPT va Gemini: suhbat, videoni ko‘rish, rasm. '
            'Kalit yozish shart emas. Hisob OpenRouter orqali, to‘lov o‘sha hisobdan.',
            style: AppText.caption(context),
          ),
          const SizedBox(height: 14),
          if (connected)
            OutlinedButton.icon(
              onPressed: () => app.disconnect(ProviderKind.openrouter),
              icon: const Icon(LucideIcons.logOut, size: 18),
              label: const Text('Chiqish'),
            )
          else ...[
            FilledButton.icon(
              onPressed: _busy ? null : _login,
              icon: _busy
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.onAccent,
                      ),
                    )
                  : const Icon(LucideIcons.logIn, size: 18),
              label: const Text('Kirish'),
            ),
            TextButton(
              onPressed: _busy ? null : _loginWithCode,
              child: const Text('Ilovaga qaytmasa — kod bilan kirish'),
            ),
          ],
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

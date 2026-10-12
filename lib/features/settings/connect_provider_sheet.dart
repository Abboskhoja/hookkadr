import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../ai/ai_clients.dart';

Future<void> showConnectProviderSheet(
  BuildContext context,
  ProviderKind kind,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ConnectSheet(kind: kind),
);

class _ConnectSheet extends StatefulWidget {
  const _ConnectSheet({required this.kind});
  final ProviderKind kind;
  @override
  State<_ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<_ConnectSheet> {
  final _c = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final app = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await app.connect(widget.kind, _c.text);
      if (mounted) Navigator.of(context).pop();
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${k.label}’ni ulash', style: AppText.title(context)),
          const SizedBox(height: 8),
          Text(
            'API kalitini kiriting (${k.keySource}). Kalit tekshiriladi va '
            'faqat shu qurilmaning xavfsiz xotirasida (Keychain / Keystore) '
            'saqlanadi. Pullik obuna (Pro/Plus) API kaliti o‘rnini bosmaydi.',
            style: AppText.caption(context),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _c,
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_busy,
            decoration: InputDecoration(hintText: k.keyHint),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _connect,
            child: _busy
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.palette.onAccent,
                    ),
                  )
                : const Text('Tekshirish va ulash'),
          ),
        ],
      ),
    );
  }
}

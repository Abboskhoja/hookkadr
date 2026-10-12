import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_clients.dart';

/// Counts real tokens reported by each provider's API response.
class TokenMeter extends ChangeNotifier {
  TokenMeter._();
  static final instance = TokenMeter._();

  SharedPreferences? _prefs;
  final Map<ProviderKind, ({int input, int output})> byProvider = {};

  int get totalInput => byProvider.values.fold(0, (a, v) => a + v.input);
  int get totalOutput => byProvider.values.fold(0, (a, v) => a + v.output);

  void attach(SharedPreferences prefs) {
    _prefs = prefs;
    for (final k in ProviderKind.values) {
      final i = prefs.getInt('tok_in_${k.name}') ?? 0;
      final o = prefs.getInt('tok_out_${k.name}') ?? 0;
      if (i > 0 || o > 0) byProvider[k] = (input: i, output: o);
    }
  }

  void record(ProviderKind k, int input, int output) {
    if (input <= 0 && output <= 0) return;
    final cur = byProvider[k] ?? (input: 0, output: 0);
    final next = (input: cur.input + input, output: cur.output + output);
    byProvider[k] = next;
    _prefs?.setInt('tok_in_${k.name}', next.input);
    _prefs?.setInt('tok_out_${k.name}', next.output);
    notifyListeners();
  }

  ({int input, int output}) snapshot() =>
      (input: totalInput, output: totalOutput);

  void reset() {
    for (final k in byProvider.keys) {
      _prefs?.remove('tok_in_${k.name}');
      _prefs?.remove('tok_out_${k.name}');
    }
    byProvider.clear();
    notifyListeners();
  }
}

String compactTokens(int n) => n >= 1000000
    ? '${(n / 1e6).toStringAsFixed(1)}M'
    : n >= 1000
    ? '${(n / 1000).toStringAsFixed(1)}k'
    : '$n';

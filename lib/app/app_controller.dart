import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/ai/ai_clients.dart';
import '../features/ai/hookkadr_cloud.dart';
import '../features/ai/offline_model.dart';
import '../features/ai/openrouter.dart';
import '../features/ai/token_meter.dart';
import '../features/ai/plan_generator.dart';
import '../features/chat/chat_models.dart';
import '../features/montage/application/montage_service.dart';
import '../features/projects/project.dart';

abstract class KeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureKeyStore implements KeyStore {
  const SecureKeyStore();
  static const _s = FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _s.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String? value) async =>
      value == null || value.isEmpty
      ? _s.delete(key: key)
      : _s.write(key: key, value: value);
}

class MemoryKeyStore implements KeyStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String? value) async =>
      value == null || value.isEmpty ? _m.remove(key) : _m[key] = value;
}

class AppController extends ChangeNotifier implements ProjectRepository {
  AppController({
    required this.keys,
    required this.prefs,
    HookkadrCloudClient? cloud,
  }) : cloud = cloud ?? _cloudFromEnvironment();

  /// The HOOKKADR server account ("Cursor model"): null when the build has
  /// no server URL or the user is not signed in.
  HookkadrCloudClient? cloud;

  /// Balance last reported by the server.
  int? credits;

  static HookkadrCloudClient? _cloudFromEnvironment() {
    if (kHookkadrApiUrl.isEmpty) return null;
    const devUid = String.fromEnvironment('HOOKKADR_DEV_UID');
    if (devUid.isEmpty) return null; // real sign-in arrives with Firebase Auth
    return HookkadrCloudClient(
      baseUrl: kHookkadrApiUrl,
      session: const DevSession(devUid),
    );
  }

  Future<void> refreshCredits() async {
    final c = cloud;
    if (c == null) return;
    try {
      credits = await c.credits();
    } on AiException {
      credits = null;
    }
    notifyListeners();
  }

  final KeyStore keys;
  final SharedPreferences prefs;
  static const _projectsKey = 'projects_v1';

  List<Project> projects = [];
  List<ChatRecord> chats = [];
  final Map<ProviderKind, String> _keys = {};

  /// null = Auto routing.
  ProviderKind? preferred;

  String? keyOf(ProviderKind k) => _keys[k];
  bool isConnected(ProviderKind k) => switch (k) {
    ProviderKind.offline => offlineInstalled,
    ProviderKind.hookkadr => cloud != null,
    _ => _keys.containsKey(k),
  };
  String? get geminiKey => _keys[ProviderKind.gemini];

  bool get aiReady => cloud != null || _keys.isNotEmpty || offlineInstalled;

  /// On-device model state.
  bool offlineInstalled = false;
  double? offlineProgress; // non-null while downloading
  String? offlineError;

  Future<void> installOffline() async {
    if (offlineProgress != null) return;
    offlineError = null;
    offlineProgress = 0;
    notifyListeners();
    try {
      await OfflineLlm.install((p) {
        offlineProgress = p;
        notifyListeners();
      });
      offlineInstalled = true;
    } on AiException catch (e) {
      offlineError = e.message;
    } finally {
      offlineProgress = null;
      notifyListeners();
    }
  }

  Future<void> removeOffline() async {
    try {
      await OfflineLlm.uninstall();
    } catch (_) {}
    offlineInstalled = false;
    if (preferred == ProviderKind.offline) await setPreferred(null);
    notifyListeners();
  }

  bool get canWatchVideo =>
      cloud != null ||
      isConnected(ProviderKind.gemini) ||
      isConnected(ProviderKind.openrouter);

  /// Who watches clips: HOOKKADR account first, then the user's own Gemini
  /// key, then the OpenRouter account's video model.
  VideoAnalyst? get videoAnalyst {
    if (cloud != null) return cloud;
    final g = _keys[ProviderKind.gemini];
    if (g != null) return GeminiClient(g);
    final o = _keys[ProviderKind.openrouter];
    return o == null ? null : OpenRouterClient(o);
  }

  /// Who draws images: OpenRouter account, then Gemini, then OpenAI.
  ImageGenerator? get imageGenerator {
    if (cloud != null) return cloud;
    final o = _keys[ProviderKind.openrouter];
    if (o != null) return OpenRouterClient(o);
    final g = _keys[ProviderKind.gemini];
    if (g != null) return GeminiClient(g);
    final a = _keys[ProviderKind.openai];
    return a == null ? null : OpenAiClient(a);
  }

  /// Sign in with OpenRouter (OAuth PKCE): no key typing.
  Future<void> loginOpenRouter() async =>
      _storeKey(ProviderKind.openrouter, await OpenRouterAuth.login());

  /// Fallback when the browser can't return to the app: user pastes code.
  Future<void> connectOpenRouterCode(String code, String verifier) async =>
      _storeKey(
        ProviderKind.openrouter,
        await OpenRouterAuth.exchange(code: code, verifier: verifier),
      );

  Future<void> _storeKey(ProviderKind kind, String key) async {
    _keys[kind] = key;
    await keys.write(kind.storageKey, key);
    notifyListeners();
  }

  bool get onboardingDone => prefs.getBool('onboarding_done') ?? false;
  Future<void> markOnboardingDone() => prefs.setBool('onboarding_done', true);

  bool get geminiConsent => prefs.getBool('consent_gemini') ?? false;
  Future<void> setGeminiConsent() => prefs.setBool('consent_gemini', true);

  TextModel _modelFor(ProviderKind k) => switch (k) {
    ProviderKind.hookkadr => cloud!,
    ProviderKind.openrouter => OpenRouterClient(_keys[k]!),
    ProviderKind.claude => ClaudeClient(_keys[k]!),
    ProviderKind.openai => OpenAiClient(_keys[k]!),
    ProviderKind.gemini => GeminiClient(_keys[k]!),
    ProviderKind.offline => OfflineLlm(),
  };

  /// Router: the planner is the user's choice if connected, otherwise the
  /// first connected provider in quality order. Video is always watched by
  /// Gemini (the only provider with native video understanding here).
  ProviderKind? get plannerKind {
    final p = preferred;
    if (p != null && isConnected(p)) return p;
    for (final k in const [
      ProviderKind.hookkadr,
      ProviderKind.claude,
      ProviderKind.openrouter,
      ProviderKind.openai,
      ProviderKind.gemini,
      ProviderKind.offline,
    ]) {
      if (isConnected(k)) return k;
    }
    return null;
  }

  PlanGenerator? generator({StageCallback? onStage}) {
    final k = plannerKind;
    if (k == null) return null;
    return PlanGenerator(
      planner: _modelFor(k),
      videoAnalyst: videoAnalyst,
      onStage: onStage,
    );
  }

  Future<void> load() async {
    TokenMeter.instance.attach(prefs);
    if (cloud != null) unawaited(refreshCredits());
    offlineInstalled = await OfflineLlm.isInstalled();
    for (final k in ProviderKind.values) {
      if (!k.needsKey) continue;
      final v = await keys.read(k.storageKey);
      if (v != null && v.isNotEmpty) _keys[k] = v;
    }
    final pref = prefs.getString('preferred_provider');
    preferred = ProviderKind.values.where((k) => k.name == pref).firstOrNull;
    final raw = prefs.getString(_projectsKey);
    if (raw != null) {
      try {
        projects = (jsonDecode(raw) as List)
            .map((e) => Project.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        projects = [];
      }
    }
    final rawChats = prefs.getString('chats_v1');
    if (rawChats != null) {
      try {
        chats = (jsonDecode(rawChats) as List)
            .map((e) => ChatRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        chats = [];
      }
    }
    notifyListeners();
  }

  ChatRecord? chatById(String id) {
    for (final c in chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Insert or update, newest first.
  Future<void> saveChat(ChatRecord chat) async {
    chat.updatedAt = DateTime.now();
    chats = [chat, ...chats.where((c) => c.id != chat.id)];
    await prefs.setString(
      'chats_v1',
      jsonEncode(chats.map((c) => c.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> deleteChat(String id) async {
    chats = chats.where((c) => c.id != id).toList();
    await prefs.setString(
      'chats_v1',
      jsonEncode(chats.map((c) => c.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Verifies the key with a real authenticated request, then stores it.
  Future<void> connect(ProviderKind kind, String rawKey) async {
    final key = rawKey.trim();
    if (key.isEmpty) throw const AiException('Kalitni kiriting.');
    final TextModel probe = switch (kind) {
      ProviderKind.hookkadr => throw const AiException(
        'HOOKKADR hisobi kirish orqali ulanadi.',
      ),
      ProviderKind.openrouter => OpenRouterClient(key),
      ProviderKind.claude => ClaudeClient(key),
      ProviderKind.openai => OpenAiClient(key),
      ProviderKind.gemini => GeminiClient(key),
      ProviderKind.offline => throw const AiException(
        'Offline AI kalit talab qilmaydi.',
      ),
    };
    await probe.verify();
    _keys[kind] = key;
    await keys.write(kind.storageKey, key);
    notifyListeners();
  }

  Future<void> disconnect(ProviderKind kind) async {
    _keys.remove(kind);
    if (preferred == kind) await setPreferred(null);
    await keys.write(kind.storageKey, null);
    notifyListeners();
  }

  Future<void> setPreferred(ProviderKind? kind) async {
    preferred = kind;
    if (kind == null) {
      await prefs.remove('preferred_provider');
    } else {
      await prefs.setString('preferred_provider', kind.name);
    }
    notifyListeners();
  }

  @override
  Project? byId(String id) {
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<Project> addProject(
    Map<String, dynamic> plan, {
    List<ProjectClip> clips = const [],
  }) async {
    final p = Project(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: plan['title'] as String,
      createdAt: DateTime.now(),
      planJson: plan,
      clips: clips,
    );
    projects = [p, ...projects];
    await _persist();
    return p;
  }

  /// Replaces the plan and keeps the previous one as a version.
  Future<void> updatePlan(String id, Map<String, dynamic> plan) async {
    projects = [
      for (final p in projects)
        if (p.id == id)
          p.copyWith(
            planJson: plan,
            history: [
              ...p.history.length >= Project.maxHistory
                  ? p.history.sublist(p.history.length - Project.maxHistory + 1)
                  : p.history,
              p.planJson,
            ],
          )
        else
          p,
    ];
    await _persist();
  }

  /// Adds clips to a project and updates its plan as one new version.
  Future<void> addClips(
    String id,
    List<ProjectClip> clips,
    Map<String, dynamic> plan,
  ) async {
    projects = [
      for (final p in projects)
        if (p.id == id)
          p.copyWith(
            clips: [...p.clips, ...clips],
            planJson: plan,
            history: [...p.history, p.planJson],
          )
        else
          p,
    ];
    await _persist();
  }

  bool canUndoPlan(String id) => byId(id)?.history.isNotEmpty ?? false;

  /// Restores the previous plan version. Returns false if there is none.
  Future<bool> undoPlan(String id) async {
    final p = byId(id);
    if (p == null || p.history.isEmpty) return false;
    projects = [
      for (final x in projects)
        if (x.id == id)
          x.copyWith(
            planJson: x.history.last,
            history: x.history.sublist(0, x.history.length - 1),
          )
        else
          x,
    ];
    await _persist();
    return true;
  }

  @override
  Future<void> setLastRender(String id, RenderInfo info) async {
    projects = [
      for (final p in projects)
        if (p.id == id) p.copyWith(lastRender: info) else p,
    ];
    await _persist();
  }

  Future<void> rename(String id, String name) async {
    projects = [
      for (final p in projects)
        if (p.id == id) p.copyWith(name: name) else p,
    ];
    await _persist();
  }

  Future<void> delete(String id) async {
    projects = projects.where((p) => p.id != id).toList();
    await _persist();
  }

  Future<void> _persist() async {
    await prefs.setString(
      _projectsKey,
      jsonEncode(projects.map((p) => p.toJson()).toList()),
    );
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

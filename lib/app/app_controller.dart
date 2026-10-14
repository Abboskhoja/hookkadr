import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kadr_llm/kadr_llm.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/ai/ai_clients.dart';
import '../features/ai/claude_frame_analyst.dart';
import '../features/ai/hookkadr_cloud.dart';
import '../features/kadr_ai/kadr_local_model.dart';
import '../features/kadr_ai/kadr_memory.dart';
import '../features/kadr_ai/kadr_painter.dart';
import '../features/kadr_ai/model_catalog.dart';
import '../features/kadr_ai/model_manager.dart';
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

/// Where Kadr AI stands on this phone, in one word for the UI.
enum KadrSetupState { idle, waitingForWifi, running, ready, failed }

class AppController extends ChangeNotifier implements ProjectRepository {
  AppController({
    required this.keys,
    required this.prefs,
    HookkadrCloudClient? cloud,
    this.autoSetup = false,
    Future<bool> Function()? unmeteredNetwork,
    Stream<bool> Function()? unmeteredChanges,
    int Function()? deviceRam,
  }) : cloud = cloud ?? _cloudFromEnvironment(),
       _unmetered = unmeteredNetwork ?? _wifiOrEthernet,
       _unmeteredChanges = unmeteredChanges ?? _wifiOrEthernetChanges,
       _deviceRam = deviceRam ?? kadrDeviceRamBytes;

  /// Kadr AI prepares itself after launch (the app's main sets this; tests
  /// leave it off so they never touch the network).
  final bool autoSetup;
  final Future<bool> Function() _unmetered;
  final Stream<bool> Function() _unmeteredChanges;
  final int Function() _deviceRam;

  static Stream<bool> _wifiOrEthernetChanges() =>
      Connectivity().onConnectivityChanged.map(
        (r) =>
            r.contains(ConnectivityResult.wifi) ||
            r.contains(ConnectivityResult.ethernet),
      );

  static Future<bool> _wifiOrEthernet() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.contains(ConnectivityResult.wifi) ||
          r.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

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

  /// Kadr AI's own on-device model packs.
  KadrModelManager models = KadrModelManager();
  DownloadToken? _download;

  Future<void> installOffline() async {
    if (offlineProgress != null) return;
    offlineError = null;
    offlineProgress = 0;
    _download = DownloadToken();
    notifyListeners();
    try {
      await models.install(
        KadrModelPack.brain,
        onProgress: (p) {
          offlineProgress = p;
          notifyListeners();
        },
        token: _download,
      );
      offlineInstalled = true;
    } on ModelInstallException catch (e) {
      offlineError = e.message;
    } catch (e) {
      offlineError = 'Modelni o‘rnatib bo‘lmadi: $e';
    } finally {
      offlineProgress = null;
      _download = null;
      notifyListeners();
    }
  }

  void cancelOfflineInstall() => _download?.cancel();

  /// Kadr AI on this phone, when its model pack is installed.
  KadrLocalModel? get localModel =>
      offlineInstalled ? KadrLocalModel(models) : null;

  /// Checks the on-device packs without delaying app start.
  Future<void> refreshModelState() async {
    try {
      var changed = false;
      final installed = await models.isInstalled(KadrModelPack.brain);
      if (installed != offlineInstalled) {
        offlineInstalled = installed;
        changed = true;
      }
      for (final pack in [
        KadrModelPack.painter,
        KadrModelPack.decoder,
        KadrModelPack.motion,
      ]) {
        final has = await models.isInstalled(pack);
        if (has != installedPacks.contains(pack.id)) {
          has ? installedPacks.add(pack.id) : installedPacks.remove(pack.id);
          changed = true;
        }
      }
      if (changed) notifyListeners();
    } catch (_) {
      // No file system access (tests): stays "not installed".
    }
  }

  /// Painter/motion packs present on the phone (ids), with download state.
  final Set<String> installedPacks = {};
  final Map<String, double> packProgress = {};
  final Map<String, String> packError = {};
  final Map<String, DownloadToken> _packDownloads = {};

  bool isPackInstalled(KadrModelPack pack) => pack.role == KadrPackRole.brain
      ? offlineInstalled
      : installedPacks.contains(pack.id);

  /// Kadr AI draws images on this phone.
  bool get painterInstalled =>
      installedPacks.contains(KadrModelPack.painter.id) &&
      installedPacks.contains(KadrModelPack.decoder.id);

  /// Kadr AI turns its images into moving clips on this phone.
  bool get motionInstalled =>
      painterInstalled && installedPacks.contains(KadrModelPack.motion.id);

  Future<void> installPack(KadrModelPack pack) async {
    await prefs.remove('kadr_skip_${pack.id}');
    if (pack.role == KadrPackRole.brain) return installOffline();
    if (packProgress.containsKey(pack.id)) return;
    packError.remove(pack.id);
    packProgress[pack.id] = 0;
    final token = _packDownloads[pack.id] = DownloadToken();
    notifyListeners();
    try {
      // The painter's small decoder (10 MB) comes with it.
      if (pack.role == KadrPackRole.painter) {
        if (!await models.isInstalled(KadrModelPack.decoder)) {
          await models.install(KadrModelPack.decoder, token: token);
        }
        installedPacks.add(KadrModelPack.decoder.id);
      }
      await models.install(
        pack,
        onProgress: (p) {
          packProgress[pack.id] = p;
          notifyListeners();
        },
        token: token,
      );
      installedPacks.add(pack.id);
    } on ModelInstallException catch (e) {
      packError[pack.id] = e.message;
    } catch (e) {
      packError[pack.id] = 'Modelni o‘rnatib bo‘lmadi: $e';
    } finally {
      packProgress.remove(pack.id);
      _packDownloads.remove(pack.id);
      notifyListeners();
    }
  }

  void cancelPackInstall(KadrModelPack pack) => pack.role == KadrPackRole.brain
      ? cancelOfflineInstall()
      : _packDownloads[pack.id]?.cancel();

  Future<void> removePack(KadrModelPack pack) async {
    // The user removed it on purpose: automatic setup leaves it alone.
    await prefs.setBool('kadr_skip_${pack.id}', true);
    if (pack.role == KadrPackRole.brain) return removeOffline();
    KadrPainter.unload();
    final packs = [
      pack,
      if (pack.role == KadrPackRole.painter) ...[
        KadrModelPack.decoder,
        // Motion only animates the painter's pictures.
        KadrModelPack.motion,
      ],
    ];
    for (final p in packs) {
      try {
        await models.remove(p);
      } catch (_) {}
      installedPacks.remove(p.id);
    }
    notifyListeners();
  }

  double? progressOf(KadrModelPack pack) =>
      pack.role == KadrPackRole.brain ? offlineProgress : packProgress[pack.id];

  String? errorOf(KadrModelPack pack) =>
      pack.role == KadrPackRole.brain ? offlineError : packError[pack.id];

  /// What Kadr AI can do on this phone right now, in plain words.
  List<String> get onDeviceSkills => [
    if (offlineInstalled) 'suhbat, ssenariy va montaj rejasi',
    if (offlineInstalled && painterInstalled) 'rasm chizish va rasmli video',
    if (offlineInstalled && motionInstalled) 'jonli harakatli video',
  ];

  // ---------------------------------------------------------- auto setup

  KadrSetupState setupState = KadrSetupState.idle;
  String? setupNote;
  bool _setupBusy = false;
  StreamSubscription<bool>? _waitWifi;

  bool _skipped(KadrModelPack p) => prefs.getBool('kadr_skip_${p.id}') ?? false;

  /// The packs this phone should have: what its memory can run.
  List<KadrModelPack> get wantedPacks {
    final ram = _deviceRam();
    bool fits(KadrModelPack p) => ram <= 0 || ram >= p.minRamBytes;
    return [
      if (fits(KadrModelPack.brain)) KadrModelPack.brain,
      if (fits(KadrModelPack.painter)) KadrModelPack.painter,
      if (fits(KadrModelPack.motion)) KadrModelPack.motion,
    ];
  }

  /// Everything Kadr AI should have on this phone is in place.
  bool get kadrReady =>
      wantedPacks.every((p) => isPackInstalled(p) || _skipped(p));

  /// 0..1 over the bytes still being prepared, null when nothing runs.
  double? get setupProgress {
    if (setupState != KadrSetupState.running) return null;
    final packs = wantedPacks.where((p) => !_skipped(p)).toList();
    final total = packs.fold<int>(0, (a, p) => a + p.sizeBytes);
    if (total == 0) return null;
    var done = 0.0;
    for (final p in packs) {
      final prog = progressOf(p);
      done += isPackInstalled(p) ? p.sizeBytes : (prog ?? 0) * p.sizeBytes;
    }
    return (done / total).clamp(0, 1).toDouble();
  }

  /// Gets Kadr AI ready without the user doing anything: brain first (chat
  /// works soonest), then the painter, then motion. Big downloads wait for
  /// Wi-Fi unless [allowCellular]; afterwards everything works offline.
  Future<void> autoSetupKadrAi({bool allowCellular = false}) async {
    if (_setupBusy) return;
    final missing = [
      for (final p in wantedPacks)
        if (!isPackInstalled(p) && !_skipped(p)) p,
    ];
    if (missing.isEmpty) {
      setupState = KadrSetupState.ready;
      setupNote = null;
      notifyListeners();
      return;
    }
    if (!allowCellular &&
        !(prefs.getBool('kadr_cellular_ok') ?? false) &&
        !await _unmetered()) {
      setupState = KadrSetupState.waitingForWifi;
      setupNote = 'Wi-Fi’ga ulanganda Kadr AI o‘zi tayyorlanadi.';
      notifyListeners();
      _waitWifi ??= _unmeteredChanges().listen((wifi) {
        if (!wifi) return;
        _waitWifi?.cancel();
        _waitWifi = null;
        unawaited(autoSetupKadrAi());
      });
      return;
    }
    if (allowCellular) await prefs.setBool('kadr_cellular_ok', true);
    _setupBusy = true;
    setupState = KadrSetupState.running;
    setupNote = null;
    notifyListeners();
    try {
      for (final p in missing) {
        await installPack(p);
        if (!isPackInstalled(p)) {
          setupState = KadrSetupState.failed;
          setupNote = errorOf(p) ?? 'Kadr AI tayyorlanmadi.';
          return;
        }
      }
      setupState = KadrSetupState.ready;
    } finally {
      _setupBusy = false;
      notifyListeners();
    }
  }

  /// What Kadr AI has learned about this user (on the phone only).
  late final KadrMemory memory = KadrMemory(prefs);

  Future<void> forgetFact(String fact) async {
    await memory.forget(fact);
    notifyListeners();
  }

  Future<void> clearMemory() async {
    await memory.clear();
    notifyListeners();
  }

  /// Kadr AI's painter on this phone, when its pack is installed. Starts in
  /// the style the user is known to like.
  KadrPainter? get painter => painterInstalled
      ? KadrPainter(models, style: memory.preferredStyle ?? PaintStyle.photo)
      : null;

  Future<void> removeOffline() async {
    KadrLocalModel.unload();
    try {
      await models.remove(KadrModelPack.brain);
    } catch (_) {}
    offlineInstalled = false;
    if (preferred == ProviderKind.offline) await setPreferred(null);
    notifyListeners();
  }

  bool get canWatchVideo =>
      cloud != null ||
      isConnected(ProviderKind.gemini) ||
      isConnected(ProviderKind.openrouter) ||
      isConnected(ProviderKind.claude);

  /// Gemini/OpenRouter/HOOKKADR receive the video file (≈18 MB inline
  /// limit); Claude only looks at frames extracted on the device.
  bool get analystHasSizeLimit =>
      cloud != null ||
      isConnected(ProviderKind.gemini) ||
      isConnected(ProviderKind.openrouter) ||
      !isConnected(ProviderKind.claude);

  /// Who watches clips: HOOKKADR account first, then the user's own Gemini
  /// key, then the OpenRouter account's video model.
  VideoAnalyst? get videoAnalyst {
    if (cloud != null) return cloud;
    final g = _keys[ProviderKind.gemini];
    if (g != null) return GeminiClient(g);
    final o = _keys[ProviderKind.openrouter];
    if (o != null) return OpenRouterClient(o);
    final c = _keys[ProviderKind.claude];
    return c == null ? null : ClaudeFrameAnalyst(ClaudeClient(c));
  }

  /// Who draws images: OpenRouter account, then Gemini, then OpenAI.
  ImageGenerator? get imageGenerator {
    // Kadr AI's own painter first: private, free, works offline.
    final local = painter;
    if (local != null) return local;
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

  /// Pro mode shows technical controls (model choice, tokens, prompts,
  /// API keys, exact resolutions). Off by default: the app is for everyone.
  bool get proMode => prefs.getBool('pro_mode') ?? false;
  Future<void> setProMode(bool on) async {
    await prefs.setBool('pro_mode', on);
    if (!on && preferred != null) await setPreferred(null);
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
    ProviderKind.offline => KadrLocalModel(models),
  };

  /// Router: the planner is the user's choice if connected, otherwise the
  /// first connected provider in quality order. Video is always watched by
  /// Gemini (the only provider with native video understanding here).
  ProviderKind? get plannerKind {
    final p = preferred;
    if (p != null && isConnected(p)) return p;
    // Kadr AI's own on-device model first: private, free, works offline.
    for (final k in const [
      ProviderKind.offline,
      ProviderKind.hookkadr,
      ProviderKind.claude,
      ProviderKind.openrouter,
      ProviderKind.openai,
      ProviderKind.gemini,
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
    unawaited(() async {
      await refreshModelState();
      if (autoSetup) await autoSetupKadrAi();
    }());
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

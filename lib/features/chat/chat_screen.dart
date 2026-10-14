import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../render/thumbnailer.dart';

import '../../app/app_controller.dart';
import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/light_markdown.dart';
import '../../core/widgets/render_player.dart';
import '../../core/widgets/poster.dart';
import '../ai/ai_clients.dart';
import '../ai/intent.dart';
import '../ai/plan_generator.dart';
import '../analysis/domain/edit_plan.dart';
import '../ai/token_meter.dart';
import '../../core/theme/motion.dart';
import '../plan/plan_diff.dart';
import '../render/export_presets.dart';
import '../render/export_sheet.dart';
import '../render/media_analyzer.dart';
import '../render/render_service.dart';
import '../montage/application/montage_service.dart';
import '../editor/editor_screen.dart';
import '../kadr_ai/kadr_memory.dart';
import '../kadr_ai/kadr_painter.dart';
import '../kadr_ai/kadr_video_maker.dart';
import '../product_ad/data/ad_output_check.dart';
import '../product_ad/data/music_synth.dart';
import '../projects/project.dart';
import '../projects/projects_screen.dart';
import '../settings/connections_screen.dart';
import '../settings/settings_screen.dart';
import '../montage/output_format.dart';
import 'chat_models.dart';

class _Clip {
  _Clip(this.id, this.path, this.name);
  final String id;
  final String path;
  final String name;
  String note = '';
  double? durationSec;
  int? sizeBytes;
  Uint8List? thumb;

  bool get tooLarge => (sizeBytes ?? 0) > GeminiClient.maxInlineBytes;
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

String _dur(double s) {
  final m = s ~/ 60;
  final r = (s - m * 60).round();
  return '$m:${r.toString().padLeft(2, '0')}';
}

/// What the user picked on the home screen; null means Kadr AI decides.
enum KadrMode {
  video(
    'Video yaratish',
    'Matndan video',
    LucideIcons.clapperboard,
    AppColors.blueLight,
  ),
  image('Rasm yaratish', 'Reklama, poster', LucideIcons.image, AppColors.coral),
  montage(
    'Montaj qilish',
    'O‘z videolaringizdan',
    LucideIcons.scissors,
    AppColors.brand,
  ),
  question(
    'Savol berish',
    'Maslahat, g‘oya, matn',
    LucideIcons.messageCircle,
    AppColors.success,
  );

  const KadrMode(this.title, this.hint, this.icon, this.color);
  final String title;
  final String hint;
  final IconData icon;
  final Color color;
}

/// A request from elsewhere in the app ("Home → Videodan montaj") that the
/// chat should start: a mode, optional text and output settings.
class KadrRequest {
  const KadrRequest(this.mode, {this.text = '', this.aspect, this.seconds});
  final KadrMode? mode;
  final String text;
  final String? aspect;
  final int? seconds;
}

/// Kadr AI chat. Every message works inside the context of the active
/// project and its attached clips.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.onOpenProjects, this.requests});

  /// Switches to the projects tab when the chat lives in [HomeShell].
  final VoidCallback? onOpenProjects;

  /// Requests pushed by other screens; each new value starts that task.
  final ValueListenable<KadrRequest?>? requests;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _maxClips = 6;
  final _c = TextEditingController();
  final _scroll = ScrollController();
  final _clips = <_Clip>[];
  ChatRecord? _chat;
  int _clipCounter = 0;
  String _platform = 'TikTok';
  String _aspect = '9:16';
  String _resolution = '1080p';
  int _duration = 30;
  bool _busy = false;
  bool _autoRender = true;
  KadrMode? _mode;

  /// Painter style the user picked; null = what Kadr AI learned they like.
  PaintStyle? _style;
  bool _learnedDefaults = false;

  PaintStyle _styleFor(AppController app) =>
      _style ?? app.memory.preferredStyle ?? PaintStyle.photo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_learnedDefaults) return;
    _learnedDefaults = true;
    // Start in the format this user uses most.
    final aspect = AppScope.of(context).memory.preferredAspect;
    if (aspect != null) _aspect = aspect;
  }

  /// Reply being written right now by on-device Kadr AI (token stream).
  String? _live;
  final _focus = FocusNode();
  List<ActivityStep>? _steps;

  List<Msg> get _msgs => _chat?.messages ?? const [];

  @override
  void initState() {
    super.initState();
    widget.requests?.addListener(_onRequest);
  }

  void _onRequest() {
    final r = widget.requests?.value;
    if (r == null || !mounted) return;
    setState(() {
      _chat = null;
      _clips.clear();
      _mode = r.mode;
      _c.text = r.text;
      if (r.aspect != null) _aspect = r.aspect!;
      if (r.seconds != null) _duration = r.seconds!;
    });
    if (r.mode == KadrMode.montage) {
      _pickVideos();
    } else {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    widget.requests?.removeListener(_onRequest);
    _focus.dispose();
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  });

  ChatRecord _ensureChat(String firstText) => _chat ??= ChatRecord(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    title: firstText.length > 42 ? '${firstText.substring(0, 42)}…' : firstText,
    updatedAt: DateTime.now(),
  );

  Future<void> _persist() async {
    final chat = _chat;
    if (chat != null) await AppScope.of(context).saveChat(chat);
  }

  Future<void> _pickVideos() async {
    final files = await ImagePicker().pickMultiVideo(
      limit: _maxClips - _clips.length,
    );
    await _addFiles(files);
  }

  Future<void> _recordVideo() async {
    final f = await ImagePicker().pickVideo(source: ImageSource.camera);
    if (f != null) await _addFiles([f]);
  }

  Future<void> _addFiles(List<XFile> files) async {
    if (files.isEmpty) return;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/clips')..createSync(recursive: true);
    for (final f in files) {
      if (_clips.length >= _maxClips) break;
      _clipCounter++;
      final id = 'clip_${_clipCounter.toString().padLeft(2, '0')}';
      final stored =
          '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${f.name}';
      await File(f.path).copy(stored);
      final clip = _Clip(id, stored, f.name);
      if (!mounted) return;
      setState(() => _clips.add(clip));
      _loadMeta(clip);
    }
  }

  void _showAttachMenu() => showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.imageUp),
              title: const Text('Galereyadan video'),
              subtitle: Text('${_clips.length}/$_maxClips tanlangan'),
              enabled: _clips.length < _maxClips,
              onTap: () {
                Navigator.pop(ctx);
                _pickVideos();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Kamera bilan olish'),
              enabled: _clips.length < _maxClips,
              onTap: () {
                Navigator.pop(ctx);
                _recordVideo();
              },
            ),
          ],
        ),
      ),
    ),
  );

  void _showFormatSheet() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final pro = AppScope.of(context).proMode;
        final p = ctx.palette;
        void set(VoidCallback f) {
          setState(f);
          setSheet(() {});
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Qanday bo‘lsin?', style: AppText.title(ctx)),
                const SizedBox(height: 12),
                for (final f in OutputFormat.all)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      f.aspect == '16:9'
                          ? LucideIcons.monitor
                          : f.aspect == '9:16'
                          ? LucideIcons.smartphone
                          : LucideIcons.square,
                      color: f.aspect == _aspect ? p.accent : p.textSecondary,
                    ),
                    title: Text(f.label),
                    subtitle: Text(f.hint),
                    trailing: f.aspect == _aspect
                        ? Icon(LucideIcons.check, color: p.accent)
                        : null,
                    onTap: () {
                      set(() {
                        _aspect = f.aspect;
                        _platform = f.platform;
                      });
                      AppScope.of(context).memory.choseAspect(f.aspect);
                    },
                  ),
                if (AppScope.of(context).painterInstalled &&
                    _mode != KadrMode.montage &&
                    _mode != KadrMode.question) ...[
                  const SizedBox(height: 12),
                  Text('Uslub', style: AppText.caption(ctx)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final st in PaintStyle.values)
                        ChoiceChip(
                          label: Text(st.label),
                          selected: st == _styleFor(AppScope.of(context)),
                          onSelected: (_) {
                            set(() => _style = st);
                            AppScope.of(context).memory.choseStyle(st);
                          },
                        ),
                    ],
                  ),
                ],
                if (_mode != KadrMode.image) ...[
                  const SizedBox(height: 12),
                  Text('Uzunligi', style: AppText.caption(ctx)),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 15, label: Text('15 soniya')),
                      ButtonSegment(value: 30, label: Text('30 soniya')),
                      ButtonSegment(value: 60, label: Text('1 daqiqa')),
                    ],
                    selected: {_duration},
                    emptySelectionAllowed: true,
                    onSelectionChanged: (v) {
                      if (v.isNotEmpty) set(() => _duration = v.first);
                    },
                  ),
                ],
                if (pro) ...[
                  const SizedBox(height: 18),
                  Text('Sifat (Pro)', style: AppText.caption(ctx)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in const ['720p', '1080p', '4K'])
                        ChoiceChip(
                          label: Text(r),
                          selected: r == _resolution,
                          onSelected: (_) => set(() => _resolution = r),
                        ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Avto-render'),
                    subtitle: const Text(
                      'Reja tayyor bo‘lishi bilan MP4 yasaladi',
                    ),
                    value: _autoRender,
                    onChanged: (v) => set(() => _autoRender = v),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tayyor'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  /// Home tile tapped: remember what the user wants and get them started.
  void _selectMode(KadrMode m) {
    setState(() => _mode = m);
    if (m == KadrMode.montage) {
      _pickVideos();
    } else {
      _focus.requestFocus();
    }
  }

  Future<void> _loadMeta(_Clip c) async {
    try {
      c.sizeBytes = await File(c.path).length();
      final ctl = VideoPlayerController.file(File(c.path));
      await ctl.initialize();
      c.durationSec = ctl.value.duration.inMilliseconds / 1000;
      await ctl.dispose();
    } catch (_) {}
    try {
      c.thumb = await Thumbnailer.jpeg(c.path);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _editNote(_Clip clip) async {
    final ctl = TextEditingController(text: clip.note);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${clip.id} uchun izoh'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Masalan: shuni boshiga qo‘y, 00:04–00:08 ni ishlat',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (result != null) setState(() => clip.note = result.trim());
  }

  Future<bool> _confirmGemini() async {
    final app = AppScope.of(context);
    if (app.geminiConsent) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gemini bilan tahlil qilinsinmi?'),
        content: const Text(
          'Videolaringiz Google Gemini’ga yuboriladi, u sahnalar, nutq va '
          'vaqtlarni tushunadi. Keyin faqat matnli tahlil reja tuzuvchi AI’ga boradi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hozir emas'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ruxsat berish'),
          ),
        ],
      ),
    );
    if (ok == true) await app.setGeminiConsent();
    return ok == true;
  }

  /// Returns 'local' / 'live' (Kadr AI on the phone), 'images', 'veo', or
  /// null (cancelled).
  Future<String?> _chooseVideoMethod(AppController app) async {
    final local = app.painterInstalled;
    final live = app.motionInstalled;
    final hasGemini = app.isConnected(ProviderKind.gemini);
    final hasImages =
        !local && (hasGemini || app.isConnected(ProviderKind.openai));
    if (!local && !hasGemini && !hasImages) {
      throw const AiException(
        'Video yaratish uchun Kadr AI rassomini telefonga o‘rnating: Profil → '
        'Kadr AI telefonda → Rassom. Bir marta yuklanadi, keyin internetsiz ishlaydi. '
        'O‘z kliplaringizdan montaj esa hozir ham ishlaydi.',
      );
    }
    // Only one way: no question to ask.
    if (local && !live && !hasGemini) return 'local';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Video qanday yaratilsin?'),
        content: Text(
          [
            if (local)
              'Telefonda: Kadr AI ssenariy yozadi, har sahnani chizadi, zoom, '
                  'subtitr va musiqa bilan videoga yig‘adi. Internetsiz, bepul.',
            if (live)
              'Telefonda, jonli: har sahna 2,7 soniyalik harakatli klipga '
                  'aylanadi. Sekinroq — telefonga qarab bir necha daqiqa.',
            if (hasImages)
              'Rasmlardan video (bulutda): har sahna uchun AI rasm chiziladi, so‘ng '
                  'zoom va subtitr bilan videoga yig‘iladi. Pullik provider hisobidan.',
            if (hasGemini)
              'Veo (bulutda): AI video (${GeminiClient.videoModel}). Pullik, bir '
                  'necha daqiqa.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor'),
          ),
          if (local)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'local'),
              child: const Text('Telefonda'),
            ),
          if (live)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'live'),
              child: const Text('Jonli'),
            ),
          if (hasImages)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'images'),
              child: const Text('Rasmlardan'),
            ),
          if (hasGemini)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'veo'),
              child: const Text('Veo'),
            ),
        ],
      ),
    );
  }

  /// Kadr AI on the phone: storyboard → painted (and optionally animated)
  /// scenes → music → rendered and verified MP4.
  Future<KadrVideoResult> _makeKadrVideo(
    AppController app,
    PlanGenerator gen,
    String request, {
    required bool live,
  }) {
    final painter = app.painter;
    if (painter == null) {
      throw const AiException('Kadr AI rassomi o‘rnatilmagan.');
    }
    return KadrVideoMaker(
      repository: app,
      renderer: RenderService(),
      music: MusicSynth(),
      painter: KadrPainterScenes(
        KadrPainter(app.models, style: _styleFor(app)),
      ),
      storyboard: (req, sec, n) => gen.writeStoryboard(
        request: req,
        durationSec: sec,
        aspectRatio: _aspect,
        scenes: n,
      ),
      verify: checkAdOutput,
    ).create(
      request: request,
      durationSec: _duration.clamp(10, 30),
      live: live,
      aspectRatio: _aspect,
      resolution: _resolution,
      onStage: _stage,
      onProgress: (p) {
        if (mounted) setState(() => _steps?.last.progress = p);
      },
    );
  }

  /// AI storyboard -> one AI image per scene -> editable project that the
  /// offline renderer turns into a video.
  Future<String> _generateSlideshow(
    AppController app,
    PlanGenerator gen,
    String request,
  ) async {
    final seconds = _duration.clamp(10, 30);
    final scenes = await gen.writeStoryboard(
      request: request,
      durationSec: seconds,
      aspectRatio: _aspect,
      scenes: (seconds / 5).round().clamp(3, 6),
    );
    final clips = <ProjectClip>[];
    for (final (i, sc) in scenes.indexed) {
      _stage('Rasm ${i + 1}/${scenes.length} chizilmoqda');
      final path = await _generateImage(app, sc.prompt);
      clips.add(
        ProjectClip(
          id: 'clip_${(i + 1).toString().padLeft(2, '0')}',
          path: path,
          name: 'AI rasm ${i + 1}',
          sizeBytes: File(path).lengthSync(),
        ),
      );
    }
    _stage('Video rejasi yig‘ilmoqda');
    final plan = PlanGenerator.buildSlideshowPlan(
      scenes: scenes,
      durationSec: seconds,
      aspectRatio: _aspect,
      resolution: _resolution,
      title: request,
    );
    EditPlan.fromJson(plan); // never store an invalid plan
    return (await app.addProject(plan, clips: clips)).id;
  }

  Future<String> _generateImage(AppController app, String prompt) async {
    final painter = app.painter;
    if (painter != null) {
      _stage('Kadr AI rasm chizmoqda (telefonda)');
      final file = await painter.paint(
        prompt,
        aspectRatio: _aspect,
        style: _styleFor(app),
        onProgress: (p) {
          if (mounted) setState(() => _steps?.last.progress = p.fraction);
        },
      );
      return file.path;
    }
    final gen = app.imageGenerator;
    if (gen == null) {
      throw const AiException(
        'Rasm chizish uchun Kadr AI rassomini telefonga o‘rnating: Profil → '
        'Kadr AI telefonda → Rassom (bir marta yuklanadi, keyin internetsiz).',
      );
    }
    _stage('Rasm chizilmoqda');
    final Uint8List bytes = await gen.generateImage(
      prompt,
      aspectRatio: _aspect,
    );
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/images')..createSync(recursive: true);
    final file = File(
      '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> _generateVideo(AppController app, String prompt) async {
    final key = app.keyOf(ProviderKind.gemini);
    if (key == null) {
      throw const AiException(
        'Veo uchun Gemini ulang. Telefonda video yaratish uchun esa Kadr AI '
        'rassomini o‘rnating: Profil → Kadr AI telefonda.',
      );
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/clips')..createSync(recursive: true);
    final path = '${dir.path}/veo_${DateTime.now().millisecondsSinceEpoch}.mp4';
    _stage('Veo’ga so‘rov yuborildi');
    String? last;
    await GeminiClient(key).generateVideo(
      prompt,
      savePath: path,
      aspectRatio: _aspect,
      onStatus: (s) {
        if (s != last) {
          last = s;
          if (mounted) {
            setState(() {
              final st = _steps;
              if (st != null &&
                  st.isNotEmpty &&
                  st.last.label.startsWith('Video yaratilmoqda')) {
                st.removeLast();
              }
            });
          }
          _stage(s);
        }
      },
    );
    double dur = 8;
    try {
      final ctl = VideoPlayerController.file(File(path));
      await ctl.initialize();
      dur = ctl.value.duration.inMilliseconds / 1000;
      await ctl.dispose();
    } catch (_) {}
    final d = (dur * 10).floor() / 10;
    final ar = _aspect == '16:9' ? '16:9' : '9:16';
    final title = prompt.length > 48 ? '${prompt.substring(0, 48)}…' : prompt;
    final plan = <String, dynamic>{
      'schemaVersion': 1,
      'title': title,
      'summary': 'Veo yaratgan ${d.toStringAsFixed(1)} soniyalik klip.',
      'durationSec': d,
      'aspectRatio': ar,
      'shots': [
        {
          'id': 's1',
          'startSec': 0,
          'endSec': d,
          'description': prompt,
          'sourceClipId': 'clip_01',
          'sourceIn': 0,
          'sourceOut': d,
        },
      ],
      'mediaSlots': <Map<String, dynamic>>[],
      'captions': <Map<String, dynamic>>[],
      'audioTracks': <Map<String, dynamic>>[],
      'export': {'resolution': _resolution, 'fps': 30},
    };
    final project = await app.addProject(
      plan,
      clips: [
        ProjectClip(
          id: 'clip_01',
          path: path,
          name: 'AI video (Veo)',
          durationSec: dur,
          sizeBytes: File(path).lengthSync(),
        ),
      ],
    );
    return project.id;
  }

  /// The user rated something Kadr AI drew: it learns the style they like.
  Future<void> _rate(Msg m, int value) async {
    if (m.rating == value) return;
    final app = AppScope.of(context);
    setState(() => m.rating = value);
    await app.memory.rate(PaintStyle.byName(m.style), value);
    await _persist();
  }

  void _stage(String label) {
    final steps = _steps;
    if (steps == null) return;
    setState(() {
      if (steps.isNotEmpty && steps.last.state == ActivityState.active) {
        steps.last.state = ActivityState.done;
      }
      steps.add(ActivityStep(label));
    });
    _scrollDown();
  }

  Future<void> _send() async {
    final text = _c.text.trim();
    if (_busy) return;
    if (_mode == KadrMode.montage && _clips.isEmpty) {
      await _pickVideos();
      return;
    }
    if (text.isEmpty && _clips.isEmpty) return;
    final mode = _mode;
    final app = AppScope.of(context);
    final clips = List<_Clip>.of(_clips);

    // "Eslab qol: …" — Kadr AI keeps it on the phone; no model needed.
    final fact = clips.isEmpty ? KadrMemory.factFrom(text) : null;
    if (fact != null) {
      await app.memory.remember(fact);
      final chat = _ensureChat(text);
      setState(() {
        chat.messages
          ..add(Msg.user(text))
          ..add(
            Msg.ai(
              'Eslab qoldim: “$fact”. Endi javob, ssenariy va rasmlarda buni '
              'hisobga olaman. Profil → Kadr AI xotirasi’da ko‘rish yoki '
              'o‘chirish mumkin.',
            ),
          );
        _c.clear();
      });
      await _persist();
      _scrollDown();
      return;
    }

    final chat = _ensureChat(text.isEmpty ? 'Video montaj' : text);
    if (clips.isNotEmpty &&
        app.canWatchVideo &&
        !(app.analystHasSizeLimit && clips.any((c) => c.tooLarge)) &&
        !await _confirmGemini()) {
      return;
    }

    setState(() {
      chat.messages.add(
        Msg.user(
          text.isEmpty ? '${clips.length} ta videodan montaj qil' : text,
          clipNames: [for (final c in clips) '${c.id} · ${c.name}'],
        ),
      );
      _c.clear();
      _clips.clear();
      _mode = null;
    });
    _scrollDown();

    final gen = app.generator(onStage: _stage);
    if (gen == null && clips.isEmpty) {
      setState(
        () => chat.messages.add(
          Msg.ai(
            'Bu ish uchun Kadr AI kerak: Profil → Kadr AI telefonda → “Miya”ni '
            'bir marta yuklab oling, keyin internetsiz ishlaydi. O‘z videolaringizni '
            'montaj qilish esa hozir ham ishlaydi — “Montaj qilish” ni tanlang.',
            needsAi: true,
          ),
        ),
      );
      await _persist();
      return;
    }
    final existing = chat.projectId == null ? null : app.byId(chat.projectId!);
    final intent = clips.isNotEmpty
        ? ChatIntent.createPlan
        : switch (mode) {
            KadrMode.video => ChatIntent.video,
            KadrMode.image => ChatIntent.image,
            KadrMode.question => ChatIntent.chat,
            _ => detectIntent(
              text,
              hasProject: existing != null,
              hasClips: false,
            ),
          };
    String? videoMethod;
    if (intent == ChatIntent.video) {
      try {
        videoMethod = await _chooseVideoMethod(app);
      } on AiException catch (e) {
        setState(() => chat.messages.add(Msg.ai(e.message, isError: true)));
        await _persist();
        return;
      }
      if (videoMethod == null) {
        setState(
          () => chat.messages.add(Msg.ai('Video generatsiyasi bekor qilindi.')),
        );
        await _persist();
        return;
      }
    }

    final steps = <ActivityStep>[];
    final before = TokenMeter.instance.snapshot();
    ({int i, int o}) used() {
      final now = TokenMeter.instance.snapshot();
      return (i: now.input - before.input, o: now.output - before.output);
    }

    setState(() {
      _busy = true;
      _steps = steps;
      chat.messages.add(Msg.activity(steps));
    });
    try {
      if (clips.isNotEmpty) {
        final res = await _runMontage(app, gen, clips, text);
        final render = _autoRender
            ? await _renderNow(app, res.projectId)
            : null;
        if (!mounted) return;
        setState(() {
          if (steps.isNotEmpty && steps.last.state == ActivityState.active) {
            steps.last.state = ActivityState.done;
          }
          steps.add(
            ActivityStep(
              render != null ? 'Video tayyor' : 'Reja tayyor',
              ActivityState.done,
            ),
          );
          chat.projectId = res.projectId;
          chat.title = res.plan['title'] as String;
          final u = used();
          chat.messages.add(
            Msg.ai(
              [
                res.plan['summary'] as String,
                if (render != null)
                  'Video tayyor: ${render.resolution} · ${FileSizeEstimator.formatBytes(render.sizeBytes)}. '
                      'Yuqorida ko‘ring yoki galereyaga eksport qiling.'
                else if (_autoRender)
                  'Render qilinmadi — Eksport tugmasini bosing.',
                if (res.note != null) res.note!,
              ].join('\n\n'),
              projectId: render == null ? res.projectId : null,
              tokensIn: u.i,
              tokensOut: u.o,
            ),
          );
        });
        return;
      }
      final g = gen!;
      switch (intent) {
        case ChatIntent.chat:
          final history = <Map<String, String>>[
            for (final m in chat.messages)
              if (m.kind != MsgKind.activity && !m.isError && m.text.isNotEmpty)
                {
                  'role': m.kind == MsgKind.user ? 'user' : 'assistant',
                  'content': m.text,
                },
          ];
          final recent = history.length > 12
              ? history.sublist(history.length - 12)
              : history;
          final local = app.plannerKind == ProviderKind.offline
              ? app.localModel
              : null;
          final String reply;
          if (local != null) {
            // On-device Kadr AI: show the answer as it is written.
            final b = StringBuffer();
            setState(() => _live = '');
            try {
              await for (final t in local.stream(
                system: [
                  PlanGenerator.chatSystem,
                  app.memory.promptContext(),
                ].where((x) => x.isNotEmpty).join('\n\n'),
                messages: recent,
                maxTokens: 700,
              )) {
                b.write(t);
                if (!mounted) return;
                setState(() => _live = b.toString());
                _scrollDown();
              }
            } finally {
              if (mounted) setState(() => _live = null);
            }
            reply = b.toString().trim();
            if (reply.isEmpty) {
              throw const AiException('Kadr AI bo‘sh javob qaytardi.');
            }
          } else {
            reply = await g.converse(recent);
          }
          if (!mounted) return;
          setState(() {
            if (steps.isNotEmpty) steps.last.state = ActivityState.done;
            final u = used();
            chat.messages.add(Msg.ai(reply, tokensIn: u.i, tokensOut: u.o));
          });
          return;
        case ChatIntent.image:
          final prompt = await g.writeGenerationPrompt(
            request: text,
            video: false,
            aspectRatio: _aspect,
          );
          final drewOnPhone = app.painter != null;
          final path = await _generateImage(app, prompt);
          if (!mounted) return;
          setState(() {
            if (steps.isNotEmpty) steps.last.state = ActivityState.done;
            final u = used();
            chat.messages.add(
              Msg.ai(
                drewOnPhone
                    ? 'Rasm tayyor — telefonda chizildi '
                          '(${_styleFor(app).label} uslubi). Yoqdimi? Bahoyingizdan '
                          'o‘rganaman.'
                    : 'Rasm tayyor.',
                imagePath: path,
                genPrompt: prompt,
                style: drewOnPhone ? _styleFor(app).name : null,
                tokensIn: u.i,
                tokensOut: u.o,
              ),
            );
          });
          return;
        case ChatIntent.video:
          if (videoMethod == 'local' || videoMethod == 'live') {
            final res = await _makeKadrVideo(
              app,
              g,
              text,
              live: videoMethod == 'live',
            );
            if (!mounted) return;
            setState(() {
              if (steps.isNotEmpty) steps.last.state = ActivityState.done;
              steps.add(ActivityStep('Video tayyor', ActivityState.done));
              chat.projectId = res.projectId;
              final u = used();
              chat.messages.add(
                Msg.ai(
                  [
                    'Video tayyor: ${res.scenes.length} ta sahna, '
                        '${res.durationSec.toStringAsFixed(1)} soniya, musiqa bilan. '
                        'Hammasi telefonda yaratildi.',
                    for (final (i, sc) in res.scenes.indexed)
                      '${i + 1}. ${sc.caption ?? sc.prompt}',
                    'Yuqorida ko‘ring, galereyaga saqlang yoki muharrirda tahrirlang. '
                        'Yoqdimi? Bahoyingizdan o‘rganaman.',
                  ].join('\n'),
                  tokensIn: u.i,
                  tokensOut: u.o,
                  style: _styleFor(app).name,
                ),
              );
            });
            return;
          }
          final String pid;
          String? used0;
          if (videoMethod == 'images') {
            pid = await _generateSlideshow(app, g, text);
          } else {
            used0 = await g.writeGenerationPrompt(
              request: text,
              video: true,
              aspectRatio: _aspect,
            );
            pid = await _generateVideo(app, used0);
          }
          if (!mounted) return;
          setState(() {
            if (steps.isNotEmpty) steps.last.state = ActivityState.done;
            steps.add(ActivityStep('Tayyor', ActivityState.done));
            chat.projectId = pid;
            final u = used();
            chat.messages.add(
              Msg.ai(
                videoMethod == 'images'
                    ? 'Video loyihasi tayyor: rasmlar sahnalarga joylandi. Muharrirda '
                          'ko‘ring, kerak bo‘lsa tahrirlang va MP4 qilib eksport qiling.'
                    : 'AI video tayyor. Muharrirda ko‘rib, boshqa kliplar bilan birlashtirib '
                          'eksport qilishingiz mumkin.',
                projectId: pid,
                genPrompt: used0,
                tokensIn: u.i,
                tokensOut: u.o,
              ),
            );
          });
          return;
        case ChatIntent.createPlan:
        case ChatIntent.editPlan:
          break;
      }
      final Map<String, dynamic> plan;
      final String id;
      var changes = const <String>[];
      Map<String, dynamic>? pending;
      String? baseSig;
      if (clips.isNotEmpty) {
        plan = await g.fromClips(
          clips: [
            for (final c in clips)
              ClipInput(
                id: c.id,
                path: c.path,
                note: c.note,
                durationSec: c.durationSec,
              ),
          ],
          prompt: text,
          platform: _platform,
          durationSec: _duration,
          aspectRatio: _aspect,
          resolution: _resolution,
        );
        id = (await app.addProject(
          plan,
          clips: [
            for (final c in clips)
              ProjectClip(
                id: c.id,
                path: c.path,
                name: c.name,
                durationSec: c.durationSec,
                sizeBytes: c.sizeBytes,
              ),
          ],
        )).id;
      } else if (existing != null && intent == ChatIntent.editPlan) {
        plan = await g.edit(
          current: existing.planJson,
          instruction: text,
          clips: [
            for (final c in existing.clips)
              ClipInput(id: c.id, path: c.path, durationSec: c.durationSec),
          ],
        );
        // Proposal only: nothing changes until the user taps Apply.
        changes = describePlanDiff(existing.planJson, plan);
        pending = plan;
        baseSig = planSignature(existing.planJson);
        id = existing.id;
      } else {
        plan = await g.fromPrompt(
          prompt: text,
          platform: _platform,
          durationSec: _duration,
          aspectRatio: _aspect,
          resolution: _resolution,
        );
        id = (await app.addProject(plan)).id;
      }
      if (!mounted) return;
      setState(() {
        if (steps.isNotEmpty) steps.last.state = ActivityState.done;
        steps.add(ActivityStep('Tayyor', ActivityState.done));
        chat.projectId = id;
        chat.title = plan['title'] as String;
        final u = used();
        chat.messages.add(
          pending == null
              ? Msg.ai(
                  plan['summary'] as String,
                  projectId: id,
                  tokensIn: u.i,
                  tokensOut: u.o,
                )
              : Msg.ai(
                  changes.isEmpty
                      ? 'Joriy loyihada o‘zgarish topilmadi.'
                      : 'Taklif: ${changes.length} ta o‘zgarish. Ko‘rib chiqing va qo‘llang.',
                  tokensIn: u.i,
                  tokensOut: u.o,
                  changes: changes,
                  pendingPlan: changes.isEmpty ? null : pending,
                  baseSignature: changes.isEmpty ? null : baseSig,
                  approval: changes.isEmpty ? null : 'pending',
                ),
        );
      });
    } on AiException catch (e) {
      if (mounted) {
        setState(() {
          if (steps.isNotEmpty) steps.last.state = ActivityState.failed;
          chat.messages.add(Msg.ai(e.message, isError: true));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (steps.isNotEmpty) steps.last.state = ActivityState.failed;
          chat.messages.add(Msg.ai('Kutilmagan xato: $e', isError: true));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _steps = null;
        });
        await _persist();
      }
      _scrollDown();
    }
  }

  MontageService _montage(AppController app) => MontageService(
    analyzer: MediaAnalyzer(),
    renderer: RenderService(),
    repository: app,
  );

  MontageSettings get _settings => MontageSettings(
    targetSec: _duration,
    aspectRatio: _aspect,
    resolution: _resolution,
    platform: _platform,
  );

  /// UI adapter: the montage logic lives in [MontageService].
  Future<MontageResult> _runMontage(
    AppController app,
    PlanGenerator? gen,
    List<_Clip> clips,
    String text,
  ) => _montage(app).buildProject(
    clips: [
      for (final c in clips)
        MontageClip(
          id: c.id,
          path: c.path,
          name: c.name,
          note: c.note,
          durationSec: c.durationSec,
          sizeBytes: c.sizeBytes,
        ),
    ],
    prompt: text,
    settings: _settings,
    planner: gen,
    canWatchVideo: app.canWatchVideo,
    analystSizeLimited: app.analystHasSizeLimit,
    onStage: _stage,
  );

  Future<RenderInfo?> _renderNow(AppController app, String projectId) =>
      _montage(app).render(
        projectId,
        resolution: _resolution,
        onStage: _stage,
        onProgress: (p) {
          if (mounted) setState(() => _steps?.last.progress = p);
        },
      );

  /// Applies an AI proposal after the user confirmed it. Refuses when the
  /// project changed since the proposal was made (version conflict).
  Future<void> _applyProposal(Msg m) async {
    final chat = _chat;
    final id = chat?.projectId;
    final plan = m.pendingPlan;
    if (chat == null || id == null || plan == null || _busy) return;
    final app = AppScope.of(context);
    final project = app.byId(id);
    if (project == null) return;
    if (planSignature(project.planJson) != m.baseSignature) {
      setState(() {
        m.approval = 'conflict';
        chat.messages.add(
          Msg.ai(
            'Bu taklif tayyorlangandan keyin loyiha o‘zgargan. Eski taklifni qo‘llasam, '
            'yangi tahrirlaringiz yo‘qoladi. Iltimos, so‘rovni qayta yuboring.',
            isError: true,
          ),
        );
      });
      await _persist();
      return;
    }
    try {
      EditPlan.fromJson(plan); // validate again before touching the project
    } on EditPlanFormatException catch (e) {
      setState(
        () => chat.messages.add(
          Msg.ai('Taklif yaroqsiz: ${e.message}', isError: true),
        ),
      );
      return;
    }
    await app.updatePlan(id, plan);
    setState(() => m.approval = 'applied');
    await _persist();
    if (!_autoRender || project.clips.isEmpty) return;
    final steps = <ActivityStep>[];
    setState(() {
      _busy = true;
      _steps = steps;
      chat.messages.add(Msg.activity(steps));
    });
    try {
      await _renderNow(app, id);
      if (mounted) setState(() => steps.last.state = ActivityState.done);
    } on RenderException catch (e) {
      if (mounted) {
        setState(() {
          if (steps.isNotEmpty) steps.last.state = ActivityState.failed;
          chat.messages.add(Msg.ai(e.message, isError: true));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _steps = null;
        });
        await _persist();
      }
    }
  }

  Future<void> _cancelProposal(Msg m) async {
    setState(() => m.approval = 'cancelled');
    await _persist();
  }

  Future<void> _undoLast() async {
    final chat = _chat;
    final id = chat?.projectId;
    if (chat == null || id == null) return;
    final ok = await AppScope.of(context).undoPlan(id);
    if (!mounted) return;
    setState(
      () => chat.messages.add(
        Msg.ai(
          ok ? 'Oldingi versiyaga qaytildi.' : 'Qaytariladigan versiya yo‘q.',
          isError: !ok,
        ),
      ),
    );
    await _persist();
    _scrollDown();
  }

  void _newChat() => setState(() {
    _chat = null;
    _clips.clear();
    _c.clear();
  });

  void _openChat(ChatRecord r) => setState(() {
    _chat = r;
    _clips.clear();
  });

  void _openConnections() => AppScope.of(context).proMode
      ? Navigator.of(context).push(
          CupertinoPageRoute<void>(builder: (_) => const ConnectionsScreen()),
        )
      : SettingsScreen.open(context);

  void _openProjects() {
    final open = widget.onOpenProjects;
    if (open != null) {
      open();
    } else {
      Navigator.of(
        context,
      ).push(CupertinoPageRoute<void>(builder: (_) => const ProjectsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final empty = _msgs.isEmpty;
    return Scaffold(
      backgroundColor: p.background,
      drawer: _ChatDrawer(
        activeId: _chat?.id,
        onNewChat: () {
          Navigator.pop(context);
          _newChat();
        },
        onOpenChat: (r) {
          Navigator.pop(context);
          _openChat(r);
        },
        onDeleted: (id) {
          if (_chat?.id == id) _newChat();
        },
        onProjects: () {
          Navigator.pop(context);
          _openProjects();
        },
        onSettings: () {
          Navigator.pop(context);
          SettingsScreen.open(context);
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              onNewChat: empty ? null : _newChat,
              onProfile: () => SettingsScreen.open(context),
            ),
            if (!empty && _chat?.projectId != null)
              _Workspace(projectId: _chat!.projectId!, onUndo: _undoLast),
            Expanded(
              child: empty
                  ? _EmptyHome(
                      onMode: _selectMode,
                      onIdea: (m, s) => setState(() {
                        _mode = m;
                        _c.text = s;
                      }),
                      onOpen: (id) => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => EditorScreen(projectId: id),
                        ),
                      ),
                    )
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      children: [
                        for (final (i, m) in _msgs.indexed)
                          _MessageView(
                            msg: m,
                            onConnect: _openConnections,
                            onRate: m.style == null ? null : (v) => _rate(m, v),
                            onApply: () => _applyProposal(m),
                            onCancel: () => _cancelProposal(m),
                            onUndo:
                                i == _msgs.length - 1 && m.changes.isNotEmpty
                                ? _undoLast
                                : null,
                          ),
                        if (_live != null) _LiveReply(text: _live!),
                      ],
                    ),
            ),
            _Composer(
              controller: _c,
              focus: _focus,
              clips: _clips,
              mode: _mode,
              onClearMode: () => setState(() => _mode = null),
              aspect: _aspect,
              duration: _duration,
              busy: _busy,
              refining: _chat?.projectId != null && _clips.isEmpty,
              onAttach: _showAttachMenu,
              onFormat: _showFormatSheet,
              onNote: _editNote,
              onRemove: (c) => setState(() => _clips.remove(c)),
              onSend: _send,
              onManage: _openConnections,
            ),
          ],
        ),
      ),
    );
  }
}

/// No bar: only the round controls float over the page. The page title is
/// not repeated here — the drawer lists the conversations.
class _Header extends StatelessWidget {
  const _Header({required this.onNewChat, required this.onProfile});
  final VoidCallback? onNewChat;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = AppScope.of(context);
    Widget round(String tip, IconData icon, VoidCallback? onTap) => Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GlassIconButton(icon: icon, tooltip: tip, onTap: onTap),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          round(
            'Suhbatlar',
            LucideIcons.menu,
            () => Scaffold.of(context).openDrawer(),
          ),
          const Spacer(),
          if (app.credits != null)
            Tooltip(
              message: 'Kreditlar',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.coins, size: 16, color: p.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${app.credits}',
                    style: TextStyle(
                      color: p.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (onNewChat != null)
            round('Yangi suhbat', LucideIcons.squarePen, onNewChat),
          round('Profil va sozlamalar', LucideIcons.circleUserRound, onProfile),
        ],
      ),
    );
  }
}

/// Claude-style left sidebar: search, new chat, history grouped by date.
class _ChatDrawer extends StatefulWidget {
  const _ChatDrawer({
    required this.activeId,
    required this.onNewChat,
    required this.onOpenChat,
    required this.onDeleted,
    required this.onProjects,
    required this.onSettings,
  });
  final String? activeId;
  final VoidCallback onNewChat;
  final ValueChanged<ChatRecord> onOpenChat;
  final ValueChanged<String> onDeleted;
  final VoidCallback onProjects;
  final VoidCallback onSettings;

  @override
  State<_ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<_ChatDrawer> {
  String _q = '';

  String _group(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = day.difference(that).inDays;
    if (diff <= 0) return 'Bugun';
    if (diff == 1) return 'Kecha';
    if (diff < 7) return 'Shu hafta';
    return 'Oldinroq';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.palette;
    final q = _q.trim().toLowerCase();
    final chats = [
      for (final c in app.chats)
        if (q.isEmpty || c.title.toLowerCase().contains(q)) c,
    ];
    final rows = <Widget>[];
    String? last;
    for (final (i, c) in chats.indexed) {
      final g = _group(c.updatedAt);
      if (g != last) {
        last = g;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(
              g,
              style: AppText.caption(context)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
      rows.add(
        Dismissible(
          key: ValueKey(c.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: AppColors.danger,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(LucideIcons.trash2, color: Colors.white),
          ),
          onDismissed: (_) {
            app.deleteChat(c.id);
            widget.onDeleted(c.id);
          },
          child:
              ListTile(
                    dense: true,
                    selected: c.id == widget.activeId,
                    selectedTileColor: p.surfaceRaised.withValues(alpha: 0.6),
                    title: Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => widget.onOpenChat(c),
                  )
                  .animate()
                  .fadeIn(delay: (25 * i).ms, duration: 250.ms)
                  .slideX(begin: -0.05),
        ),
      );
    }
    return Drawer(
      backgroundColor: p.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Suhbatlarni qidirish',
                  prefixIcon: Icon(
                    LucideIcons.search,
                    size: 18,
                    color: p.textSecondary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            ListTile(
              leading: Icon(LucideIcons.squarePen, color: p.accent),
              title: Text(
                'Yangi suhbat',
                style: TextStyle(color: p.accent, fontWeight: FontWeight.w600),
              ),
              onTap: widget.onNewChat,
            ),
            Expanded(
              child: chats.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          q.isEmpty
                              ? 'Suhbatlar shu yerda saqlanadi.'
                              : 'Hech narsa topilmadi.',
                          textAlign: TextAlign.center,
                          style: AppText.caption(context),
                        ),
                      ),
                    )
                  : ListView(children: rows),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.folderOpen),
              title: const Text('Loyihalarim'),
              onTap: widget.onProjects,
            ),
            ListTile(
              leading: const Icon(LucideIcons.circleUserRound),
              title: const Text('Profil va sozlamalar'),
              onTap: widget.onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({
    required this.onMode,
    required this.onIdea,
    required this.onOpen,
  });
  final ValueChanged<KadrMode> onMode;
  final void Function(KadrMode mode, String text) onIdea;
  final ValueChanged<String> onOpen;

  static const _ideas = [
    (
      KadrMode.video,
      'Restoran reklamasi',
      'Restoranim uchun 30 soniyali chiroyli reklama video',
    ),
    (
      KadrMode.image,
      'Mahsulot rasmi',
      'Oq fonda telefon g‘ilofining chiroyli reklama rasmi',
    ),
    (
      KadrMode.question,
      'Reels g‘oyasi',
      'Qahvaxonam uchun 5 ta Reels g‘oyasini ber',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: BrandLogo(key: const ValueKey('brand-logo'), size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'Salom! Men Kadr AI',
                textAlign: TextAlign.center,
                style: AppText.display(context, size: 30),
              ).animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 6),
              Text(
                'Nima qilamiz? Tanlang yoki pastga yozing.',
                textAlign: TextAlign.center,
                style: AppText.body(context)
                    .copyWith(color: context.palette.textSecondary),
              ),
              const SizedBox(height: 24),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 138,
                ),
                children: [
                  for (final (i, m) in KadrMode.values.indexed)
                    _ModeTile(mode: m, onTap: () => onMode(m))
                        .animate()
                        .fadeIn(delay: (80 * i).ms, duration: 300.ms)
                        .slideY(begin: 0.08, curve: Curves.easeOutCubic),
                ],
              ),
              const SizedBox(height: 22),
              Text('Masalan', style: AppText.caption(context)),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _ideas.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final e = _ideas[i];
                    return _IdeaRow(
                      icon: e.$1.icon,
                      text: e.$2,
                      onTap: () => onIdea(e.$1, e.$3),
                    );
                  },
                ),
              ),
              if (app.projects.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Davom ettirish', style: AppText.caption(context)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: app.projects.length.clamp(0, 8),
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final pr = app.projects[i];
                      return SizedBox(
                        width: 150,
                        child: ProjectPosterCard(
                          title: pr.name,
                          plan: pr.planJson,
                          onTap: () => onOpen(pr.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the four big "what do you want" choices.
class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.mode, required this.onTap});
  final KadrMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = mode.color;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.separator, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(mode.icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                mode.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                mode.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(context).copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdeaRow extends StatelessWidget {
  const _IdeaRow({required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.separator, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: p.textSecondary),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(color: p.textPrimary, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// The answer on-device Kadr AI is writing right now.
class _LiveReply extends StatelessWidget {
  const _LiveReply({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text.rich(
      TextSpan(
        children: [
          lightMarkdown(
            text,
            GoogleFonts.inter(
              color: context.palette.textPrimary,
              fontSize: 16,
              height: 1.55,
            ),
          ),
          TextSpan(
            text: ' ▍',
            style: TextStyle(color: context.palette.accent),
          ),
        ],
      ),
    ),
  );
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.msg,
    required this.onConnect,
    this.onRate,
    this.onUndo,
    this.onApply,
    this.onCancel,
  });
  final Msg msg;
  final VoidCallback onConnect;

  /// 👍 (1) / 👎 (-1) on a picture or video Kadr AI drew.
  final ValueChanged<int>? onRate;
  final VoidCallback? onUndo;
  final VoidCallback? onApply;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = AppScope.of(context);
    final Widget w;
    switch (msg.kind) {
      case MsgKind.user:
        w = Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 18, left: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: p.surfaceRaised,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final n in msg.clipNames)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.film, size: 14, color: p.accent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            n,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption(context)
                                .copyWith(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(msg.text, style: AppText.body(context)),
              ],
            ),
          ),
        );
      case MsgKind.activity:
        final steps = msg.steps!;
        final working = steps.any((s) => s.state == ActivityState.active);
        final header = Text(
          working ? 'HOOKKADR ishlamoqda…' : 'Bajarilgan ishlar',
          style: TextStyle(
            color: p.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        );
        w = Padding(
          padding: const EdgeInsets.only(bottom: 18, right: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandLogo(size: 20)
                      .animate(
                        target: working ? 1 : 0,
                        onPlay: (c) => working ? c.repeat(reverse: true) : null,
                      )
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1.15, 1.15),
                        duration: 700.ms,
                      ),
                  const SizedBox(width: 8),
                  working
                      ? header
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(duration: 1400.ms, color: p.accent)
                      : header,
                ],
              ),
              const SizedBox(height: 8),
              for (final s in steps)
                Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            child: switch (s.state) {
                              ActivityState.active =>
                                const CupertinoActivityIndicator(radius: 7),
                              ActivityState.done => const Icon(
                                LucideIcons.check,
                                size: 16,
                                color: AppColors.success,
                              ),
                              ActivityState.failed => const Icon(
                                LucideIcons.x,
                                size: 15,
                                color: AppColors.danger,
                              ),
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.progress != null &&
                                          s.state == ActivityState.active
                                      ? '${s.label} · ${(s.progress! * 100).round()}%'
                                      : s.label,
                                  style: AppText.body(context)
                                      .copyWith(fontSize: 15),
                                ),
                                if (s.progress != null &&
                                    s.state == ActivityState.active)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: s.progress,
                                        minHeight: 4,
                                        backgroundColor: p.surfaceRaised,
                                        color: p.accent,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate(key: ValueKey(s.label))
                    .fadeIn(duration: 250.ms)
                    .slideX(begin: -0.04),
            ],
          ),
        );
      case MsgKind.ai:
        final project = msg.projectId == null ? null : app.byId(msg.projectId!);
        w = Padding(
          padding: const EdgeInsets.only(bottom: 22, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              msg.isError
                  ? Text(
                      msg.text,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 15.5,
                        height: 1.45,
                      ),
                    )
                  : Text.rich(
                      lightMarkdown(
                        msg.text,
                        GoogleFonts.inter(
                          color: p.textPrimary,
                          fontSize: 16,
                          height: 1.55,
                        ),
                      ),
                    ),
              if (msg.imagePath != null &&
                  File(msg.imagePath!).existsSync()) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _openImage(context, msg.imagePath!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: Image.file(
                        File(msg.imagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
              if (msg.genPrompt != null && AppScope.of(context).proMode)
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      'AI yozgan prompt',
                      style: AppText.caption(context),
                    ),
                    children: [
                      SelectableText(
                        msg.genPrompt!,
                        style: AppText.caption(context).copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    if (msg.tokensIn + msg.tokensOut > 0 &&
                        AppScope.of(context).proMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '↑${compactTokens(msg.tokensIn)} ↓${compactTokens(msg.tokensOut)} token',
                          style: AppText.caption(context)
                              .copyWith(fontSize: 11.5),
                        ),
                      ),
                    _copyButton(context, msg.text),
                    if (onRate != null) ...[
                      _RateButton(
                        icon: LucideIcons.thumbsUp,
                        label: 'Yoqdi',
                        selected: msg.rating == 1,
                        onTap: () => onRate!(1),
                      ),
                      _RateButton(
                        icon: LucideIcons.thumbsDown,
                        label: 'Yoqmadi',
                        selected: msg.rating == -1,
                        onTap: () => onRate!(-1),
                      ),
                    ],
                  ],
                ),
              ),
              if (msg.changes.isNotEmpty) ...[
                const SizedBox(height: 10),
                _EditDiffCard(
                  changes: msg.changes,
                  approval: msg.approval,
                  onApply: msg.approval == 'pending' ? onApply : null,
                  onCancel: msg.approval == 'pending' ? onCancel : null,
                  onUndo: msg.approval == 'applied' || msg.approval == null
                      ? onUndo
                      : null,
                ),
              ],
              if (msg.needsAi) ...[
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(180, 44),
                  ),
                  onPressed: onConnect,
                  child: const Text('Kadr AI’ni yoqish'),
                ),
              ],
              if (project != null) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => EditorScreen(projectId: project.id),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: p.separator, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShotStrip(
                          durations: shotDurations(project.planJson),
                          height: 6,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          project.name,
                          style: AppText.title(context).copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${seconds((project.planJson['durationSec'] as num).toDouble())} · '
                          '${shotDurations(project.planJson).length} kadr · '
                          '${project.planJson['aspectRatio']}',
                          style: AppText.caption(context),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Muharrirda ochish',
                              style: TextStyle(
                                color: p.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 14,
                              color: p.accent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
    }
    if (AppMotion.reduce(context)) {
      return w.animate().fadeIn(duration: AppMotion.reduced);
    }
    return msg.kind == MsgKind.user
        ? w
              .animate()
              .fadeIn(duration: AppMotion.messageEnter)
              .slideY(begin: 0.06, curve: AppMotion.curve)
        : w.animate().fadeIn(duration: AppMotion.assistantCardEnter);
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.clips,
    required this.mode,
    required this.onClearMode,
    required this.aspect,
    required this.duration,
    required this.busy,
    required this.refining,
    required this.onAttach,
    required this.onFormat,
    required this.onNote,
    required this.onRemove,
    required this.onSend,
    required this.onManage,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final List<_Clip> clips;
  final KadrMode? mode;
  final VoidCallback onClearMode;
  final String aspect;
  final int duration;
  final bool busy;
  final bool refining;
  final VoidCallback onAttach;
  final VoidCallback onFormat;
  final ValueChanged<_Clip> onNote;
  final ValueChanged<_Clip> onRemove;
  final VoidCallback onSend;
  final VoidCallback onManage;

  String get _hint => switch (mode) {
    KadrMode.video => 'Qanday video kerak? Masalan: kafe uchun reklama',
    KadrMode.image => 'Qanday rasm kerak? Masalan: oq fonda soat',
    KadrMode.montage =>
      clips.isEmpty
          ? 'Videolarni tanlang (+)'
          : 'Qanday montaj? Yozmasangiz ham bo‘ladi',
    KadrMode.question => 'Savolingizni yozing',
    null =>
      refining
          ? 'O‘zgartirishni yozing: masalan, boshini qisqartir'
          : 'Kadr AI’ga yozing…',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = AppScope.of(context);
    final showFormat =
        !refining &&
        (clips.isNotEmpty ||
            mode == KadrMode.video ||
            mode == KadrMode.montage ||
            mode == KadrMode.image);
    final format = OutputFormat.of(aspect);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: p.separator, width: 0.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mode != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InputChip(
                    avatar: Icon(mode!.icon, size: 16, color: mode!.color),
                    label: Text(mode!.title),
                    onDeleted: busy ? null : onClearMode,
                    deleteIcon: const Icon(LucideIcons.x, size: 14),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (clips.isNotEmpty) ...[
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: clips.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) =>
                        _ClipCard(
                              sizeLimited: app.analystHasSizeLimit,
                              clip: clips[i],
                              busy: busy,
                              onNote: onNote,
                              onRemove: onRemove,
                            )
                            .animate()
                            .fadeIn(duration: 250.ms)
                            .scale(begin: const Offset(0.92, 0.92)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: controller,
                focusNode: focus,
                enabled: !busy,
                minLines: 1,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  filled: false,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
                  border: InputBorder.none,
                  hintText: _hint,
                ),
              ),
              Row(
                children: [
                  _RoundButton(
                    icon: LucideIcons.plus,
                    tooltip: 'Video yoki rasm qo‘shish',
                    onTap: busy ? null : onAttach,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: showFormat
                          ? ActionChip(
                              avatar: Icon(
                                aspect == '16:9'
                                    ? LucideIcons.monitor
                                    : LucideIcons.smartphone,
                                size: 16,
                              ),
                              label: Text(
                                mode == KadrMode.image
                                    ? format.label
                                    : '${format.label} · $duration s',
                              ),
                              onPressed: busy ? null : onFormat,
                              visualDensity: VisualDensity.compact,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  if (app.proMode) _ModelPicker(busy: busy, onManage: onManage),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: busy ? null : onSend,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: busy ? p.surfaceRaised : p.accent,
                      ),
                      child: busy
                          ? Padding(
                              padding: const EdgeInsets.all(11),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.textSecondary,
                              ),
                            )
                          : Icon(
                              LucideIcons.arrowUp,
                              color: p.onAccent,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: p.separator),
          ),
          child: Icon(icon, size: 20, color: p.textPrimary),
        ),
      ),
    );
  }
}

/// Pro only: choose which AI answers (Auto by default).
class _ModelPicker extends StatelessWidget {
  const _ModelPicker({required this.busy, required this.onManage});
  final bool busy;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = AppScope.of(context);
    return PopupMenuButton<String>(
      enabled: !busy,
      color: p.surface,
      onSelected: (v) {
        if (v == 'manage') {
          onManage();
        } else if (v == 'auto') {
          app.setPreferred(null);
        } else {
          app.setPreferred(ProviderKind.values.byName(v));
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'auto',
          child: Text('Auto — tavsiya etiladi'),
        ),
        for (final k in ProviderKind.values)
          PopupMenuItem(
            value: k.name,
            enabled: app.isConnected(k),
            child: Text(
              app.isConnected(k) ? k.label : '${k.label} · ulanmagan',
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'manage', child: Text('AI ulanishlari')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusDot(on: app.aiReady),
            const SizedBox(width: 6),
            Text(
              app.preferred?.label ?? 'Auto',
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 11, color: p.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ClipCard extends StatelessWidget {
  const _ClipCard({
    this.sizeLimited = true,
    required this.clip,
    required this.busy,
    required this.onNote,
    required this.onRemove,
  });
  final _Clip clip;
  final bool sizeLimited;
  final bool busy;
  final ValueChanged<_Clip> onNote;
  final ValueChanged<_Clip> onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final meta = [
      if (clip.durationSec != null) _dur(clip.durationSec!),
      if (clip.sizeBytes != null) _mb(clip.sizeBytes!),
    ].join(' · ');
    return GestureDetector(
      onTap: busy ? null : () => onNote(clip),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: BorderRadius.circular(14),
          border: (clip.tooLarge && sizeLimited)
              ? Border.all(color: AppColors.danger)
              : null,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 58,
                height: 76,
                child: clip.thumb != null
                    ? Image.memory(clip.thumb!, fit: BoxFit.cover)
                    : ColoredBox(
                        color: p.surfaceRaised,
                        child: const Center(
                          child: CupertinoActivityIndicator(radius: 8),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          clip.id,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: busy ? null : () => onRemove(clip),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            LucideIcons.x,
                            size: 12,
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    (clip.tooLarge && sizeLimited)
                        ? '18 MB dan katta'
                        : (meta.isEmpty ? 'O‘lchanmoqda…' : meta),
                    style: TextStyle(
                      fontSize: 11,
                      color: (clip.tooLarge && sizeLimited)
                          ? AppColors.danger
                          : p.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    clip.note.isEmpty ? 'Izoh qo‘shish…' : clip.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      color: clip.note.isEmpty ? p.accent : p.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openImage(BuildContext context, String path) => showDialog<void>(
  context: context,
  builder: (ctx) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: InteractiveViewer(child: Image.file(File(path))),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Yopish'),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () async {
                  try {
                    if (!await Gal.hasAccess(toAlbum: true)) {
                      await Gal.requestAccess(toAlbum: true);
                    }
                    await Gal.putImage(path, album: 'HOOKKADR');
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Galereyaga saqlandi')),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Saqlab bo‘lmadi: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(LucideIcons.download, size: 18),
                label: const Text('Galereyaga saqlash'),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

Widget _copyButton(BuildContext context, String text) => GestureDetector(
  onTap: () {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nusxalandi'),
        duration: Duration(seconds: 1),
      ),
    );
  },
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
    child: Icon(
      LucideIcons.copy,
      size: 16,
      color: context.palette.textSecondary,
    ),
  ),
);

class _EditDiffCard extends StatelessWidget {
  const _EditDiffCard({
    required this.changes,
    required this.onUndo,
    this.approval,
    this.onApply,
    this.onCancel,
  });
  final List<String> changes;
  final VoidCallback? onUndo;
  final String? approval;
  final VoidCallback? onApply;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            approval == 'pending' ||
                    approval == 'cancelled' ||
                    approval == 'conflict'
                ? '${changes.length} ta o‘zgarish taklif qilindi'
                : '${changes.length} ta o‘zgarish qo‘llandi',
            style: AppText.body(context)
                .copyWith(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 6),
          for (final c in changes.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.check,
                    size: 15,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c,
                      style: AppText.body(context).copyWith(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          if (changes.length > 8)
            Text(
              '+${changes.length - 8} ta yana',
              style: AppText.caption(context),
            ),
          if (onApply != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                    ),
                    onPressed: onApply,
                    icon: const Icon(LucideIcons.check, size: 18),
                    label: const Text('Qo‘llash'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Bekor qilish'),
                  ),
                ],
              ),
            ),
          if (approval == 'cancelled' ||
              approval == 'conflict' ||
              approval == 'applied')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                switch (approval) {
                  'applied' => 'Qo‘llandi',
                  'cancelled' => 'Bekor qilindi',
                  _ => 'Qo‘llanmadi: loyiha o‘zgargan',
                },
                style: AppText.caption(context)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          if (onUndo != null && approval == 'applied')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onUndo,
                icon: const Icon(LucideIcons.undo2, size: 16),
                label: const Text('Bekor qilish (Undo)'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Persistent video workspace above the chat: preview of the CURRENT
/// output, its real specs, and quick actions. Collapses to a mini bar while
/// the keyboard is open.
class _Workspace extends StatelessWidget {
  const _Workspace({required this.projectId, required this.onUndo});
  final String projectId;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final project = app.byId(projectId);
    if (project == null) return const SizedBox.shrink();
    final p = context.palette;
    final hk = context.hk;
    final plan = project.planJson;
    final render = project.lastRender;
    final hasFile = render != null && File(render.path).existsSync();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final height = (MediaQuery.sizeOf(context).height * 0.30).clamp(
      150.0,
      300.0,
    );

    final specs = hasFile
        ? '${render.aspectRatio} · ${render.resolution} · ${seconds(render.durationSec)} · '
              '${render.fps} FPS · MP4 · ${FileSizeEstimator.formatBytes(render.sizeBytes)}'
        : '${plan['aspectRatio']} · ${seconds((plan['durationSec'] as num).toDouble())} · '
              '${(plan['shots'] as List).length} kadr · render qilinmagan';

    void openEditor() => Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => EditorScreen(projectId: projectId),
      ),
    );
    void export() {
      try {
        showExportSheet(
          context,
          project: project,
          plan: EditPlan.fromJson(plan),
        );
      } on EditPlanFormatException catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    if (keyboard) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              hasFile ? LucideIcons.circlePlay : LucideIcons.film,
              size: 18,
              color: p.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Joriy: $specs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(context),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: height,
              color: hk.videoStage,
              child: hasFile
                  ? RenderPlayer(key: ValueKey(render.path), path: render.path)
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 180,
                              child: ShotStrip(
                                durations: shotDurations(plan),
                                height: 6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Video hali render qilinmagan.\nEksport tugmasi MP4 yaratadi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: hk.videoChrome.withValues(alpha: 0.75),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  specs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(context).copyWith(fontSize: 12),
                ),
              ),
              if (hasFile && !project.renderIsCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: hk.borderStrong),
                  ),
                  child: Text(
                    'Reja o‘zgardi — qayta eksport',
                    style: AppText.caption(context).copyWith(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: 'Tahrirlash',
                onPressed: openEditor,
                icon: const Icon(LucideIcons.panelsTopLeft),
              ),
              if (project.history.isNotEmpty)
                IconButton(
                  tooltip: 'Oldingi versiya',
                  onPressed: onUndo,
                  icon: const Icon(LucideIcons.undo2),
                ),
              const Spacer(),
              IconButton.filled(
                tooltip: 'Eksport',
                onPressed: export,
                icon: const Icon(LucideIcons.download),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IconButton(
      tooltip: label,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, size: 17, color: selected ? p.accent : p.textSecondary),
    );
  }
}

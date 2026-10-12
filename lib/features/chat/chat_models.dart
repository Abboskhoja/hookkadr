enum ActivityState { active, done, failed }

class ActivityStep {
  ActivityStep(this.label, [this.state = ActivityState.active]);
  final String label;
  ActivityState state;

  /// Real 0..1 progress when the worker reports it (render); never faked.
  double? progress;

  Map<String, dynamic> toJson() => {'label': label, 'state': state.name};
  factory ActivityStep.fromJson(Map<String, dynamic> j) => ActivityStep(
    j['label'] as String,
    ActivityState.values.asNameMap()[j['state']] ?? ActivityState.done,
  );
}

enum MsgKind { user, ai, activity }

class Msg {
  Msg.user(this.text, {this.clipNames = const []})
    : kind = MsgKind.user,
      projectId = null,
      imagePath = null,
      tokensIn = 0,
      tokensOut = 0,
      genPrompt = null,
      changes = const [],
      pendingPlan = null,
      baseSignature = null,
      approval = null,
      steps = null,
      needsAi = false,
      isError = false;

  Msg.ai(
    this.text, {
    this.projectId,
    this.needsAi = false,
    this.isError = false,
    this.imagePath,
    this.tokensIn = 0,
    this.tokensOut = 0,
    this.genPrompt,
    this.changes = const [],
    this.pendingPlan,
    this.baseSignature,
    this.approval,
  }) : kind = MsgKind.ai,
       clipNames = const [],
       steps = null;

  Msg.activity(this.steps)
    : kind = MsgKind.activity,
      imagePath = null,
      tokensIn = 0,
      tokensOut = 0,
      genPrompt = null,
      changes = const [],
      pendingPlan = null,
      baseSignature = null,
      approval = null,
      text = '',
      clipNames = const [],
      projectId = null,
      needsAi = false,
      isError = false;

  final MsgKind kind;
  final String text;
  final List<String> clipNames;
  final String? projectId;
  final List<ActivityStep>? steps;
  final bool needsAi;
  final bool isError;
  final String? imagePath;
  final int tokensIn;
  final int tokensOut;

  /// The prompt the AI wrote for an image/video generator (shown to user).
  final String? genPrompt;

  /// EditDiffCard lines: what the AI changed in the plan.
  final List<String> changes;

  /// AI-proposed plan awaiting the user's Apply/Cancel (spec: approval).
  final Map<String, dynamic>? pendingPlan;

  /// Signature of the plan the proposal was computed from; if the project
  /// changed since, applying it would overwrite newer work (conflict).
  final String? baseSignature;

  /// null (no proposal) | pending | applied | cancelled | conflict
  String? approval;

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'tokensIn': tokensIn,
    'tokensOut': tokensOut,
    'genPrompt': genPrompt,
    'changes': changes,
    'pendingPlan': pendingPlan,
    'baseSignature': baseSignature,
    'approval': approval,
    'kind': kind.name,
    'text': text,
    'clipNames': clipNames,
    'projectId': projectId,
    'steps': steps?.map((s) => s.toJson()).toList(),
    'needsAi': needsAi,
    'isError': isError,
  };

  factory Msg.fromJson(Map<String, dynamic> j) {
    final kind = MsgKind.values.asNameMap()[j['kind']] ?? MsgKind.ai;
    switch (kind) {
      case MsgKind.user:
        return Msg.user(
          j['text'] as String,
          clipNames: (j['clipNames'] as List).cast<String>(),
        );
      case MsgKind.activity:
        return Msg.activity([
          for (final s in (j['steps'] as List))
            ActivityStep.fromJson(s as Map<String, dynamic>)
              ..state =
                  ActivityState.values.asNameMap()[(s as Map)['state']] ==
                      ActivityState.active
                  ? ActivityState
                        .failed // an interrupted run is not "working"
                  : ActivityState.values.asNameMap()[s['state']] ??
                        ActivityState.done,
        ]);
      case MsgKind.ai:
        return Msg.ai(
          j['text'] as String,
          projectId: j['projectId'] as String?,
          needsAi: j['needsAi'] as bool? ?? false,
          isError: j['isError'] as bool? ?? false,
          imagePath: j['imagePath'] as String?,
          tokensIn: (j['tokensIn'] as num?)?.toInt() ?? 0,
          tokensOut: (j['tokensOut'] as num?)?.toInt() ?? 0,
          genPrompt: j['genPrompt'] as String?,
          changes: (j['changes'] as List?)?.cast<String>() ?? const [],
          pendingPlan: j['pendingPlan'] as Map<String, dynamic>?,
          baseSignature: j['baseSignature'] as String?,
          approval: j['approval'] as String?,
        );
    }
  }
}

class ChatRecord {
  ChatRecord({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.projectId,
    List<Msg>? messages,
  }) : messages = messages ?? [];

  final String id;
  String title;
  DateTime updatedAt;
  String? projectId;
  final List<Msg> messages;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'projectId': projectId,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatRecord.fromJson(Map<String, dynamic> j) => ChatRecord(
    id: j['id'] as String,
    title: j['title'] as String,
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    projectId: j['projectId'] as String?,
    messages: [
      for (final m in (j['messages'] as List))
        Msg.fromJson(m as Map<String, dynamic>),
    ],
  );
}

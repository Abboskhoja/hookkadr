/// What the user wants from a chat message. Deterministic so it works the
/// same with every provider, including the small offline model.
enum ChatIntent { createPlan, editPlan, image, video, chat }

final _imageWord = RegExp(
  r'(rasm|surat|tasvir|image|picture|illustr|poster|картин|изображ|фото)',
);
final _videoGenWord = RegExp(
  r'(generats|generat|veo|сгенер|ai[ -]?video|ии[ -]?видео)',
);
final _videoWord = RegExp(r'(video|kadr|klip|sahna|видео|clip|shot)');
final _makeWord = RegExp(
  r'(yarat|chiz|qil|generat|create|make|draw|нарису|созда|сдела)',
);
final _planWord = RegExp(
  r'(montaj|reja|reklama|reels|tiktok|shorts|intro|trailer|subtit|kadr|soniya|sekund|'
  r'video|edit|монтаж|ролик|видео|клип)',
);
final _questionStart = RegExp(
  r'^(nima|nega|nimaga|qanday|qanaqa|qaysi|kim|qachon|qayer|qancha|nechta|'
  r'salom|assalomu|rahmat|hello|hi|hey|what|why|how|who|when|where|'
  r'привет|что|как|почему|зачем|кто|когда|где|сколько|спасибо)\b',
);

ChatIntent detectIntent(
  String text, {
  required bool hasProject,
  required bool hasClips,
}) {
  final t = text.toLowerCase().trim();
  if (hasClips) return ChatIntent.createPlan;
  if (_videoGenWord.hasMatch(t) && _videoWord.hasMatch(t)) {
    return ChatIntent.video;
  }
  if (_imageWord.hasMatch(t) && _makeWord.hasMatch(t)) return ChatIntent.image;
  final isQuestion = t.endsWith('?') || _questionStart.hasMatch(t);
  if (isQuestion) return ChatIntent.chat;
  if (hasProject) return ChatIntent.editPlan;
  if (_planWord.hasMatch(t)) return ChatIntent.createPlan;
  return ChatIntent.chat;
}

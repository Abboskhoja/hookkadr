/// Phones report less memory than they are sold with: the kernel and the GPU
/// carve-out are left out (a "6 GB" iPhone 13 Pro reports ~5.7 GiB, an
/// "8 GB" iPhone 15 Pro ~7.45 GiB, "8 GB" Android phones 7.2–7.6 GiB).
/// True when [reportedBytes] comes from a phone of at least [classBytes];
/// unknown memory (0) is never held against the phone.
bool ramClassAtLeast(int reportedBytes, int classBytes) =>
    reportedBytes <= 0 || reportedBytes >= classBytes * 0.8;

/// What a pack does inside Kadr AI.
enum KadrPackRole { brain, painter, motion, decoder }

/// Model packs Kadr AI can run on the phone. Every entry is pinned to an
/// exact file revision and SHA-256, with its licence, so what runs is
/// exactly what was evaluated (see `ai/hookkadr_ai/llm/bench.py`).
class KadrModelPack {
  const KadrModelPack({
    required this.id,
    required this.title,
    required this.baseModel,
    this.chatFormat = '',
    this.role = KadrPackRole.brain,
    this.purpose = '',
    required this.fileName,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.license,
    required this.licenseUrl,
    required this.minRamBytes,
    this.contextSize = 4096,
  });

  final String id;
  final String title;

  /// Upstream model the weights come from (never hidden from the user).
  final String baseModel;

  /// Prompt format family, see `chat_format.dart` (brain packs only).
  final String chatFormat;
  final KadrPackRole role;

  /// What the pack adds, in the user's words.
  final String purpose;
  final String fileName;
  final String url;
  final String sha256;
  final int sizeBytes;
  final String license;
  final String licenseUrl;
  final int minRamBytes;
  final int contextSize;

  /// Can a phone reporting [ramBytes] of memory run this pack?
  bool fitsRam(int ramBytes) => ramClassAtLeast(ramBytes, minRamBytes);

  String get sizeLabel => '${(sizeBytes / 1e9).toStringAsFixed(1)} GB';

  /// The Kadr AI brain. Chosen on 2026-10-14 by the Uzbek benchmark: the
  /// only small candidate that wrote coherent Uzbek (Qwen3.5 0.8B/2B did not).
  static const brain = KadrModelPack(
    id: 'kadr-brain-gemma4-e2b-q4km',
    title: 'Kadr AI miya',
    purpose: 'Suhbatlashadi, ssenariy va montaj rejasini yozadi',
    baseModel: 'Google Gemma 4 E2B (instruction), Q4_K_M',
    chatFormat: 'gemma4',
    fileName: 'gemma-4-E2B-it-Q4_K_M.gguf',
    url:
        'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/'
        '0314792d7f1f7e229411f620751375812bb9faf2/gemma-4-E2B-it-Q4_K_M.gguf',
    sha256: '740185b21d22ceb83a11c3aa62ad5842ef32c70f6096d756bbee85a1e4ec34b8',
    sizeBytes: 3106738272,
    license: 'Apache-2.0',
    licenseUrl: 'https://huggingface.co/google/gemma-4-E2B-it',
    minRamBytes: 6 * 1024 * 1024 * 1024,
  );

  /// The painter: draws images on the phone. DreamShaper 8 is a Stable
  /// Diffusion 1.5 fine-tune with the LCM distillation merged in, so 4–6
  /// sampling steps are enough (a plain SD 1.5 needs 20–30).
  static const painter = KadrModelPack(
    id: 'kadr-painter-dreamshaper8-lcm',
    title: 'Kadr AI rassom',
    role: KadrPackRole.painter,
    purpose: 'Rasm chizadi va videolar uchun kadrlar yaratadi',
    baseModel: 'DreamShaper 8 LCM (Stable Diffusion 1.5)',
    fileName: 'DreamShaper8_LCM.safetensors',
    url:
        'https://huggingface.co/Lykon/dreamshaper-8-lcm/resolve/'
        '4645d8bc6a8e6b106d21606d63e8460cdad4f1a6/DreamShaper8_LCM.safetensors',
    sha256: 'a4f3e1526c5dc4fcbe342f5c410d83ae202c7a415fcefcbb92e0f93fcd0a87c3',
    sizeBytes: 2133804992,
    license: 'CreativeML Open RAIL-M',
    licenseUrl: 'https://huggingface.co/Lykon/dreamshaper-8-lcm',
    // Measured peak footprint with Q8 weights: 2.3 GB (Apple M2, Metal).
    minRamBytes: 6 * 1024 * 1024 * 1024,
  );

  /// Tiny image decoder installed together with the painter: about 5x
  /// faster than the checkpoint's own VAE decoder, nearly the same picture.
  static const decoder = KadrModelPack(
    id: 'kadr-decoder-taesd',
    title: 'Kadr AI tezkor dekoder',
    role: KadrPackRole.decoder,
    purpose: 'Rasmlarni tezroq tayyorlaydi',
    baseModel: 'TAESD (Tiny AutoEncoder for Stable Diffusion)',
    fileName: 'taesd.safetensors',
    url:
        'https://huggingface.co/madebyollin/taesd/resolve/'
        '614f76814bbe30edbe2e627ace1c2234c81a2c0e/diffusion_pytorch_model.safetensors',
    sha256: 'db169d69145ec4ff064e49d99c95fa05d3eb04ee453de35824a6d0f325513549',
    sizeBytes: 9793292,
    license: 'MIT',
    licenseUrl: 'https://huggingface.co/madebyollin/taesd',
    minRamBytes: 0,
  );

  /// Motion for the painter's images: a 4-step distilled AnimateDiff
  /// module that turns one scene into a short moving clip.
  static const motion = KadrModelPack(
    id: 'kadr-motion-animatediff-lightning-4step',
    title: 'Kadr AI harakat',
    role: KadrPackRole.motion,
    purpose: 'Rasmlarni jonli harakatli video kliplarga aylantiradi',
    baseModel: 'AnimateDiff-Lightning 4-step (ByteDance)',
    fileName: 'animatediff_lightning_4step_comfyui.safetensors',
    url:
        'https://huggingface.co/ByteDance/AnimateDiff-Lightning/resolve/'
        '027c893eec01df7330f5d4b733bc9485ee02e8b2/'
        'animatediff_lightning_4step_comfyui.safetensors',
    sha256: 'aeb66ae8ff4a868d31379c3bde3e5e7e510a4d4b565a06ee4f1297e93a561dc5',
    sizeBytes: 908929664,
    license: 'CreativeML Open RAIL-M',
    licenseUrl: 'https://huggingface.co/ByteDance/AnimateDiff-Lightning',
    // Measured peak footprint with a 16-frame clip: 2.9 GB (Apple M2).
    minRamBytes: 8 * 1024 * 1024 * 1024,
  );

  static const all = [brain, painter, decoder, motion];
}

/// A format described the way people say it, not as an aspect ratio.
class OutputFormat {
  const OutputFormat(this.label, this.hint, this.aspect, this.platform);
  final String label;
  final String hint;
  final String aspect;
  final String platform;

  static const all = [
    OutputFormat('Telefon uchun', 'Reels, TikTok, Shorts', '9:16', 'Reels'),
    OutputFormat('YouTube uchun', 'Yotiq video', '16:9', 'YouTube'),
    OutputFormat('Kvadrat', 'Post va lenta', '1:1', 'Instagram'),
    OutputFormat('Instagram post', 'Biroz tik', '4:5', 'Instagram'),
  ];

  static OutputFormat of(String aspect) =>
      all.firstWhere((f) => f.aspect == aspect, orElse: () => all.first);
}

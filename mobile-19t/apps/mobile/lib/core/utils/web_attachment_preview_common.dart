bool isReusableBrowserPreviewUrl(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith('blob:') || trimmed.startsWith('data:')) return true;
  final uri = Uri.tryParse(trimmed);
  return uri != null && (uri.hasScheme || trimmed.startsWith('/'));
}

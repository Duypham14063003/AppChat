const maxChatDocumentSizeBytes = 20 * 1024 * 1024;
const supportedChatDocumentExtensions = {
  'pdf',
  'txt',
  'md',
  'csv',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'rtf',
  'zip',
  'rar',
};

bool isSupportedChatDocumentSize(int sizeInBytes) {
  return sizeInBytes >= 0 && sizeInBytes <= maxChatDocumentSizeBytes;
}

bool isSupportedChatDocumentExtension(String filename) {
  final trimmed = filename.trim();
  final dotIndex = trimmed.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == trimmed.length - 1) return false;
  final ext = trimmed.substring(dotIndex + 1).toLowerCase();
  return supportedChatDocumentExtensions.contains(ext);
}

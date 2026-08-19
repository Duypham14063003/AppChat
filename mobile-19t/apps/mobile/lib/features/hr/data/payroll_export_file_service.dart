import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/browser_file_download_stub.dart'
    if (dart.library.html) '../../../core/utils/browser_file_download_web.dart';
import 'hr_models.dart';

class PayrollExportFileService {
  Future<void> save(PayrollWorkbookDownload workbook) async {
    if (kIsWeb) {
      await downloadBytesInBrowser(
        bytes: workbook.bytes,
        filename: workbook.filename,
        mimeType: workbook.mimeType,
      );
      return;
    }

    await Share.shareXFiles(
      [
        XFile.fromData(
          workbook.bytes,
          mimeType: workbook.mimeType,
          name: workbook.filename,
        ),
      ],
      fileNameOverrides: [workbook.filename],
    );
  }
}

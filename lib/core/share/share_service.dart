// خدمة المشاركة: واجهة مجردة فوق قائمة المشاركة القياسية في النظام، ليبقى
// التطبيق وما يختبره مستقلاً عن المنصة.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// عقد المشاركة النصية.
abstract interface class ShareService {
  /// يفتح قائمة المشاركة القياسية بالنص. يرمي عند تعذر فتحها.
  Future<void> shareText(String text, {String? subject});
}

/// التنفيذ الإنتاجي فوق share_plus.
class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}

/// خدمة المشاركة المستعملة في التطبيق.
final Provider<ShareService> shareServiceProvider = Provider<ShareService>(
  (Ref ref) => const SharePlusShareService(),
);

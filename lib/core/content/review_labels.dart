// تسمية حالة المراجعة العلمية، مشتركة بين السيرة والأذكار.

import 'models/review_info.dart';

/// حالة المراجعة العلمية بالعربية.
String reviewStatusLabel(ReviewStatus status) {
  switch (status) {
    case ReviewStatus.pendingScholarlyReview:
      return 'بانتظار المراجعة العلمية';
    case ReviewStatus.approved:
      return 'مراجَعة علمياً';
    case ReviewStatus.changesRequested:
      return 'طُلبت تعديلات علمية';
  }
}

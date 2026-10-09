// تبويبات الشريط السفلي ونية الانتقال بينها.
//
// يعيش التبويب الحالي في مزود مستقل في core، فتطلب أي ميزة الانتقال إلى
// تبويب آخر (مثل زر «إلى ميدان المراجعة» بعد إتمام الوِرد) دون أن تستورد
// غلاف التطبيق نفسه.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// تبويبات التطبيق بترتيبها في الشريط.
enum AppTab {
  /// مسار الأربعين النووية.
  arbaeen('الأربعين النووية', Icons.auto_stories_outlined, Icons.auto_stories_rounded),

  /// رحلة السيرة.
  seerah('رحلة السيرة', Icons.map_outlined, Icons.map_rounded),

  /// ميدان المراجعة.
  review('ميدان المراجعة', Icons.psychology_alt_outlined, Icons.psychology_alt_rounded),

  /// الإعدادات.
  settings('الإعدادات', Icons.tune_outlined, Icons.tune_rounded);

  const AppTab(this.label, this.icon, this.selectedIcon);

  /// الاسم في الشريط.
  final String label;

  /// الأيقونة.
  final IconData icon;

  /// الأيقونة عند الاختيار.
  final IconData selectedIcon;
}

/// متحكم التبويب الحالي.
class AppTabController extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.arbaeen;

  /// ينتقل إلى تبويب.
  void select(AppTab tab) {
    if (state != tab) {
      state = tab;
    }
  }
}

/// التبويب الحالي.
final NotifierProvider<AppTabController, AppTab> appTabProvider =
    NotifierProvider<AppTabController, AppTab>(AppTabController.new);

/// يغلق الشاشات المفتوحة فوق الغلاف ثم ينتقل إلى التبويب المطلوب.
void openAppTab(BuildContext context, WidgetRef ref, AppTab tab) {
  Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  ref.read(appTabProvider.notifier).select(tab);
}

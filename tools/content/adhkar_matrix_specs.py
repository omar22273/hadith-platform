"""تجميع مواصفات ملفات الأذكار الخمسة وملف السنن المهجورة؛ كل ملف في وحدة مستقلة ليسهل تحريره."""
import adhkar_spec_after_prayer as after_prayer
import adhkar_spec_daily_life as daily_life
import adhkar_spec_home_masjid as home_masjid
import adhkar_spec_morning_evening as morning_evening
import adhkar_spec_sleep as sleep
import adhkar_spec_sunan as sunan

FILES = {
    "adhkar_morning_evening": {"title": morning_evening.TITLE, "items": morning_evening.ITEMS, "tracks": morning_evening.TRACKS},
    "adhkar_sleep": {"title": sleep.TITLE, "items": sleep.ITEMS, "tracks": sleep.TRACKS},
    "adhkar_after_prayer": {"title": after_prayer.TITLE, "items": after_prayer.ITEMS},
    "adhkar_home_masjid": {"title": home_masjid.TITLE, "items": home_masjid.ITEMS, "tracks": home_masjid.TRACKS},
    "adhkar_daily_life": {"title": daily_life.TITLE, "items": daily_life.ITEMS},
    # السنن المهجورة ملف مستقل (بطاقات بأبواب لا أذكار بأعداد): يُكتب في assets/data/sunan/.
    "sunan_mahjoorah": {"title": sunan.TITLE, "items": sunan.ITEMS, "kind": "sunan"},
}

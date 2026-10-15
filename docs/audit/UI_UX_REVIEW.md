# Professional workspace UI/UX

Tekshiruv: to‘liq suite — 353 passed, 1 skipped. `flutter analyze` — xatosiz.
`kart_production_test.dart` iPhone 18 Pro Max / iOS 27 simulatorida o‘tdi:
synthetic source → lokal storyboard → 640×360, 25 FPS, 10 s MP4 → FFprobe.
Android telefon ulanmagan, shu passda Android native test bajarilmadi.

Golden test internet font so‘rovini fosh qildi: Inter-Regular tashqi URLdan
yuklanishga urindi. Endi `pubspec.yaml`da mavjud Inter.ttf font sifatida
ro‘yxatdan o‘tadi; theme/chat `TextStyle` orqali lokal family ishlatadi.
Uch golden (320×568, 844×390, 1024×768) yaratilgan, telefon portrait va
landscape rasmlari ko‘zdan kechirilgan. Ular synthetic matnli kartani ko‘rsatadi.

Talabnomadagi dark palette `AppPalette.dark`da markazlashtirildi; asosiy
ilova dark rejimga o‘tdi. Bu eski och theme qarorini yangi talab bilan almashtiradi.

Editor ilgari ham AppBarsiz edi. Endi portrait timeline scroll bilan cheklanadi,
landscape’da preview va tahrir paneli yonma-yon turadi. Ixcham, standart,
kengaytirilgan, timeline fokus va to‘liq preview rejimlari mavjud. Eksport
tugmasi endi aynan «Eksport» deb nomlanadi; source media o‘zgarmaydi.

320×568 da preview overlay toshishi test bilan qayta ko‘rsatildi va sig‘adigan
layout bilan tuzatildi. Tanlangan kadr asboblari inspektordan oldin turadi.
Background’da playback to‘xtaydi; qaytishda foydalanuvchi ijroni o‘zi boshlaydi.

Chegaralar: bu pass barcha ekranlarni qayta loyihalamaydi; kichik stage’da
overlay kichrayadi. Timeline thumbnail, frame ruler, real video multitrack,
AI media workspace va golden screenshot coverage keyingi ishlar.

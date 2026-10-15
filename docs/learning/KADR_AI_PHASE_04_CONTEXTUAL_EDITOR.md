# Editor boshqaruvi va AI tasdiqlash

## Audit va integratsiya

Mavjud feature-first papkalar, ChangeNotifier/AppController, EditPlan/PlanOps, VideoPlayer va FFmpeg eksport saqlandi. EditorWorkspace avvaldan portrait, landscape va fullscreen ko‘rinishlarga ega. EditorTimeline trim/reorder, zoom va seek callbacklarini haqiqiy loyiha operatsiyalariga yuboradi. KadrAiSheet editor ichidan ochiladi.

Kamchiliklar: klip toolbar’i timeline bilan scroll bo‘lib ketardi; umumiy toolbar ham yonma-yon qolardi. 4:5 preview 9:16 sifatida ochilardi. Lokal AI takliflari tasdiqsiz qo‘llanardi. pubspec’da e’lon qilingan template_product.png diskda yo‘q edi; oldin yaratilgan asl asset tiklandi.

## Implementatsiya

- `EditorTokens`: neytral editor palitrasi, toolbar o‘lchamlari, 48dp touch target va Reduce Motion’ga mos panel animatsiyasi.
- `ContextualToolbar`: tanlov borida klip vositalari, aks holda umumiy vositalar. Orqaga tugmasi faqat tanlovni yopadi, loyiha holatini o‘zgartirmaydi.
- `EditorWorkspace`: toolbar doim pastda; timeline va inspector alohida aylantiriladi.
- `EditorScreen`: undo/redo yuqorida, eksport touch target’i kengaydi, oldingi/keyingi output kadrga seek qo‘shildi, 4:5 preview tuzatildi.
- `ToolButton`: tooltip, screen reader nomi, selected/disabled holati, palitraga mos rang.
- `KadrAiSheet`: lokal va online rejalarga yagona ko‘rib chiqish/tasdiqlash oqimi. So‘rov boshlangandagi plan signature saqlanadi; taklif eskirsa qo‘llanmaydi.

## Nega shu arxitektura

Toolbar tanlovi faqat UI holati. Montajni o‘zgartiruvchi amallar eski PlanOps orqali qoladi. AI ham o‘sha EditPlan’ni taklif qiladi. Alohida parallel timeline yoki yangi state management tizimi kerak emas.

## Tekshiruv

Yakuniy `flutter test`: 358 o‘tdi, 1 skip. Golden suratlar 320×568, 844×390 va 1024×768 o‘lchamlarda qayta tekshirildi. `plan_diff.dart` storyboard, rang, musiqa, logotip va klip effektlarini tasdiqlash ro‘yxatiga kiritadi; qo‘llashdan so‘ng AI panelidagi hisobot va undo saqlanadi.

`ai_edit_approval_test.dart` valid loyiha bilan avval 16:9 o‘rniga tasdiqsiz 9:16 natija ko‘rsatib yiqildi. Tuzatishdan keyin cancel/apply testi o‘tdi. `contextual_toolbar_test.dart` tanlovni almashtirishni, `editor_adaptive_test.dart` esa haqiqiy editor ichidagi tanlov, kadr qadami va fullscreen holatini tekshiradi. Birinchi toolbar test urinishini asset yo‘qligi to‘xtatgan; bu mantiqiy RED dalili emas.

```sh
flutter analyze
flutter test
flutter devices
flutter run -d <qurilma-id>
```

Qurilmada: loyihani oching → klipni tanlang → bo‘ling → undo/redo → AI’dan format o‘zgarishini so‘rang → bekor qiling → qayta so‘rab tasdiqlang → eksport. Native seek kadr aniqligi, video preview/export mosligi va 60 FPS ishlash tezligi real media bilan alohida o‘lchanishi kerak. Widget testlar bularni isbotlamaydi.

## Keyingi ishlar va aniq chegaralar

Audio/text/overlay uchun to‘liq kontekst toolbar, haqiqiy multitrack video, waveform cache, transform/keyframe manipulyatsiyasi, native frame-accurate dekodlash va performance profiling hali bu bosqichning natijasi emas. Oldingi/keyingi kadr amali output FPS bo‘yicha timeline vaqtini belgilaydi; native player aynan o‘sha kadrni dekodlaganini bu test tasdiqlamaydi. Qo‘llanmagan VFX yoki subtitr vositalari yangi ishlaydigan tugma sifatida qo‘shilmadi.

CapCut UX manbasi: https://www.capcut.com/resource/split-video-into-parts — klip, playhead va split oqimi. HOOKKADR implementatsiyasi mustaqil.

O‘rganilgan tamoyil: kontekstga mos boshqaruv va AI tasdiqlash bir xil loyiha holati ustida ishlashi kerak; chiroyli UI native media sifatining isboti emas.

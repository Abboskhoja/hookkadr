# 2-bosqich — montaj ish maydoni

Sodda tushuncha: montaj ma’lumotlari va ularni ekranda joylashtirish ikki
alohida masala. Telefonni aylantirish yoki preview’ni kattalashtirish
`EditPlan`ni o‘zgartirmasligi kerak.

`EditorWorkspace` viewport constraints asosida panellarni joylashtiradi.
`EditorScreen` tanlash, PlanOps, undo/redo va playback bilan ishlaydi.
`PreviewOverlay` kichik stage’da matn toshmasligini ta’minlaydi.
`AppPalette.dark` brend ranglarini bir joyda saqlaydi.

RED: yangi 320×568, 844×390, 1024×768 testlari eski editorda yiqildi.
GREEN: layoutdan keyin preview rejimi va lifecycle tekshiriladi. Mavjud trim,
reorder, effect va AI testlari saqlanadi. Golden rasmlar layoutni tekshiradi,
ular haqiqiy video kadr yoki kodek testi emas.

```sh
flutter analyze
flutter test
flutter devices
flutter test integration_test/kart_production_test.dart -d <device-id>
flutter run -d <device-id>
```

Qo‘lda: loyiha oching → klip tanlang → trim → undo → timeline rejimini
o‘zgartiring → to‘liq preview → qayting → Eksport. Background’dan qaytishda
Ijro tugmasi pauza holatida turishi kerak. Native test synthetic video va
tonedan foydalanadi; gallery permission’ni tekshirmaydi.

Bu bosqich offline UI va montaj arxitekturasi haqida. Online AI chaqiruvi
qo‘shilmadi. Lokal generativ model mavjudligi layoutdan mustaqil.

O‘rganganimiz: responsive UI faqat rang emas; constraints, scroll ownership,
state saqlanishi, lifecycle va regression test birga loyihalanadi.

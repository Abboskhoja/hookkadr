# HOOKKADR bug register

## Professional editor pass

- **UI-01 — fixed, widget dalili:** 320×568 da preview overlay 100 px overflow.
  `test/editor_adaptive_test.dart` bilan qayta ko‘rsatildi. `PreviewOverlay`
  mavjud stage constraints ichiga sig‘adi.
- **UI-02 — fixed, widget dalili:** qat’iy vertikal editor landscape uchun
  mos emas. `EditorWorkspace` yonma-yon panellar va scrollable inspektor beradi.
- **LIFE-01 — regression qo‘shildi:** background’da timer playback davom
  etmasligi; observer pauza qiladi, kechikkan seek callback ijroni qayta boshlamaydi.
- **Hali ochiq:** video speed/audio/transition preview parity, media import
  deduplication va lost-data, storage backup, real Android tekshiruvi.

Oldingi AUD-003/004 bandlari ehtimoliy guard hardening edi; ular uchun o‘sha
passda reproducer yo‘q edi. Ularni tasdiqlangan runtime crash deb talqin qilmang.

Sana: 2026-10-15

Faqat dalil bilan tasdiqlangan holatlar yoziladi. `Open` bandlar statik audit
yoki yetishmayotgan test qamrovi bo‘lib, avtomatik ravishda runtime bug degani
emas.

| ID | Holat | Dalil | Severity | Tuzatish / regression |
|---|---|---|---|---|
| AUD-001 | Editor playback har 40 ms’da parent tree’ni qayta quradi | `lib/features/editor/editor_screen.dart` timer va `setState` oqimi | High | Open; granular playback rebuild uchun alohida profiling kerak |
| AUD-002 | Editor timeline trim handle’larida screen-reader label yo‘q edi | `editor_timeline.dart` handle subtree | High | Fixed; `Semantics` qo‘shildi; analyze va testlar qayta tekshiriladi |
| AUD-003 | Controller initialize callback’i stale controller bilan rebuild qilishi mumkin edi | `_syncVideo` async callback | High | Fixed; ownership check qo‘shildi |
| AUD-004 | Playback timer dispose’dan keyin state update qilishi mumkin edi | `_togglePlay` periodic callback | Medium | Fixed; mounted guard qo‘shildi |
| AUD-005 | Provider’dan kelgan rasm importdan oldin yo‘qolsa measurement exception chiqishi mumkin edi | `ClipImporter.measure` image branch | High | Fixed; existence check va safe fallback qo‘shildi |
| AUD-006 | Golden UI testlari topilmadi | `matchesGoldenFile` qidiruvida natija yo‘q | High | Open; 5 asosiy ekran uchun fixture va review kerak |
| AUD-007 | Real Android/iOS E2E qamrovi sessiya auditida qayta ishlatilmadi | Bu sessiyada faqat host analyze/test bajarildi | High | Open; device command natijasi bilan yopiladi |
| AUD-008 | EditPlan hozircha bitta asosiy video track modeli bilan ishlaydi | `EditPlan` schema va render pipeline | Medium | Open; multi-track schema alohida migration talab qiladi |

## Verification boundary

`flutter analyze` va host `flutter test` muvaffaqiyati native picker,
permission, video decoder yoki export device pipeline’i to‘liq ishlashini
isbotlamaydi. Ushbu register shu chegarani ataylab ochiq qoldiradi.


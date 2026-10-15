# HOOKKADR mobil audit

Sana: 2026-10-15

Bu audit mavjud repository va shu sessiyada haqiqatan ishga tushirilgan
buyruqlar asosida yozildi. Real qurilmada bajarilmagan tekshiruvlar bajarilgan
deb ko‘rsatilmaydi.

## Toolchain

- Flutter 3.47.7 stable
- Dart 3.13.5
- `flutter analyze`: xatosiz, `No issues found!`
- `flutter test --reporter expanded`: 347 ta test o‘tdi, 1 ta test skip bo‘ldi
- Platformalar: loyihada Android va iOS targetlari mavjud; ushbu audit sessiyasida
  real-device integration command qayta ishga tushirilmagan

## Mavjud ishlaydigan qatlamlar

- `EditPlan` va `PlanOps` orqali trim, split, move, duplicate, freeze-frame,
  transition, grade, caption va audio amallari mavjud.
- Render pipeline FFmpeg chiqishini tekshiradi; muvaffaqiyatsiz fayl tayyor deb
  qaytarilmaydi.
- KADR AI lokal rejalashtirish va timeline amallariga ulangan.
- Editor timeline’da trim handle, reorder, seek va undo/redo mavjud.
- Project va chat holati lokal `SharedPreferences` orqali saqlanadi.

## Shu sessiyadagi mustahkamlashlar

- Video controller initialize callback’i controller almashtirilgan yoki route
  yopilgan holatda eski state’ni qayta chizmaydi.
- Playback timer dispose qilingan widget’ga `setState` chaqirmaydi.
- Import qilingan rasm measurement bosqichida provider faylni olib tashlasa,
  crash qilmaydi; optional metadata bo‘sh qoladi.
- Timeline trim handle’lari o‘zbekcha accessibility semantics bilan belgilandi.

## Keyingi tekshiruvlar

1. Android telefonida import → trim → preview → save → export integration flow.
2. iOS simulator yoki qurilmada xuddi shu flow va permission denial.
3. Background/foreground va screen-lock lifecycle.
4. 360×800 va tablet o‘lchamlarida editor overflow/error overlay tekshiruvi.
5. Golden testlar: Home, Editor, AI Studio, Settings va Export.


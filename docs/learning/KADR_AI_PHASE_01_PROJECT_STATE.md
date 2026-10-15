# KADR AI — 1-bosqich: loyiha holatini xavfsiz saqlash

## Bu bosqichda nima qurildi?

KADR AI montaj rejasini (`EditPlan`) yaratadi. Reja telefonda saqlanmasa yoki
bitta buzilgan yozuv sabab barcha loyihalar ko‘rinmay qolsa, AI funksiyasi
ishonchli bo‘la olmaydi. Shuning uchun birinchi bosqichda model emas, uning
atrofidagi xavfsiz state qatlamini mustahkamladik.

## Arxitektura qarori

Mavjud loyiha `AppController`ni state orchestration qatlami, `Project`ni
domain modeli va `SharedPreferences`ni lokal storage sifatida ishlatadi.
Hozir BLoC yoki yangi repository framework qo‘shmadik: bu kichik tuzatish
uchun katta migratsiya regressiya xavfini oshiradi.

Oqim:

```text
AI/EditPlan → AppController.updatePlan/addClips → Project history
           → JSON encode → SharedPreferences
           ← JSON decode → faqat yaroqli Project yozuvlarini recovery qilish
```

## Fayl va class vazifalari

- `lib/app/app_controller.dart` — project lifecycle, persistence va undo
  history orchestration’i.
- `lib/features/projects/project.dart` — `Project`, `ProjectClip` va
  `RenderInfo` domain modellari.
- `lib/features/analysis/domain/edit_plan.dart` — AI va render engine
  o‘rtasidagi tekshiriladigan timeline shartnomasi.
- `test/workspace_test.dart` — recovery, history, render freshness va
  accessibility kontraktlarining regression testlari.

## Muhim qoida

`load()` endi barcha yozuvlarni bitta `.map()` ichida yiqitmaydi. Har bir
project alohida parse qilinadi; bittasi buzilgan bo‘lsa, qolgan yaroqli
projectlar tiklanadi. `addClips()` esa undo history’ni `Project.maxHistory`
(20) bilan cheklaydi.

## Tekshirilgan buyruqlar

```bash
flutter test test/workspace_test.dart
flutter analyze
```

Qurilmada loyiha holatini tekshirish uchun:

```bash
flutter devices
flutter run -d <android-device-id>
flutter run -d <ios-device-id>
```

Keyingi bosqichda media asset registry va import recovery’ni shu kontrakt
ustiga quramiz. Offline montaj va lokal model internet bo‘lmasa ham alohida
ishlaydi; Online providerlar esa explicit ulanish va foydalanuvchi kaliti
bo‘lmasa ishga tushmaydi.

## O‘rganganimiz

AI arxitekturasi faqat model yuklashdan iborat emas. Domain state, persistence,
validation va recovery ishonchli bo‘lmasa, eng yaxshi model ham foydalanuvchi
loyihasini xavfsiz boshqara olmaydi.


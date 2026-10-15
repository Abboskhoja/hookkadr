# 3-bosqich — montajni boshlash interfeysi

## Nima qurildi

CapCut singari montajni boshlashni osonlashtiradigan katta “Yangi loyiha” tugmasi, rasmli studio muqovasi va shablon kartalari. HOOKKADR logotipi, navigatsiyasi va mavjud montaj dvigateli saqlandi.

## Nega shunday

UI — foydalanuvchining harakatini mavjud xizmatga yetkazadigan qatlam. Yangi dizayn uchun ikkinchi EditPlan yoki render engine yaratish kerak emas. Shu sabab yangi loyiha tugmasi mavjud MontageScreen’ni ochadi. Media tanlash foydalanuvchining keyingi amali bo‘lib qoladi.

- `lib/features/home/home_screen.dart`: HomeScreen, kirish nuqtalari va AI so‘rovlarini uzatish.
- `lib/features/home/studio_hero.dart`: StudioHero, faqat muqova va boshlash tugmasi.
- `lib/features/home/templates_screen.dart`: TemplatesScreen, moslashuvchan rasmli kartalar; mavjud VideoTemplate parametrlari saqlanadi.
- `test/studio_design_test.dart`: kichik ekran/kattalashtirilgan matn/planshet, navigatsiya va golden suratlar.

Rasmlar `assets/images/` ichida. Muqova — illyustratsiya, tayyor eksport namunasi emas. Rasmlar va UI internet talab qilmaydi. Bu o‘zgarish yangi AI model yoki online xizmat qo‘shmaydi.

## Yuborilgan hujjatlarni baholash

To‘qqiz master prompt fayli byte darajasida bir xil. TDD starter README’si fake analyzer, real renderer va RNNoise hali ulanmaganini aniq aytadi. Starter mavjud production kod ustiga ko‘chirilmagan. Architect hujjatidagi BLoC/Riverpod tavsiyasi mavjud ChangeNotifier’ni avtomatik almashtirishga sabab emas.

## Sinash

```sh
flutter analyze
flutter test
flutter devices
flutter run -d 85YP4HIVIBAUYLNR
```

Oxirgi buyruq faqat shu Android qurilma ulanganida ishlaydi. Bosh sahifa → Yangi loyiha → video tanlash; Shablonlar → Reels montaj; loyihadan editor → preview → eksport yo‘llarini qurilmada sinang. Bu UI bosqichida native eksport qayta tekshirilmagan.

## O‘rganilgan tamoyil

Chiroyli interfeys biznes mantiqini takrorlamaydi. SliverGrid ko‘rinmayotgan kartalarni kech yaratadi; testlar pastdagi elementni qidirishdan oldin sahifani aylantirishi kerak. Golden testda rasmlar dekodlanishi va lokal shriftlar yuklanishi kutiladi.

## Alohida qolgan ishlar

Master hujjatdagi to‘liq multitrack, RNNoise, animatsion oltin titrlar, GPU VFX va semantik Smart Cut ushbu UI o‘zgarishi bilan bajarilgan deb hisoblanmaydi. Ular alohida media, preview va real eksport testlarini talab qiladi.

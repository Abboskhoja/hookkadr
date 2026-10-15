# Buzilgan loyiha yozuvini yo‘qotmaslik

Oldingi kod JSON ro‘yxatidagi sog‘lom loyihalarni ochardi, ammo yaroqsiz yozuvlarni xotiraga olmasdi. Keyingi rename yoki autosave faqat sog‘lom ro‘yxatni saqlab, asl buzilgan ma’lumotni yo‘qotishi mumkin edi.

`ProjectStore` saqlashdan avval diskdagi hozirgi kolleksiyani tekshiradi. Agar biror yozuv o‘qilmasa, asl to‘liq JSON `projects_recovery_v1` ichiga nusxalanadi. Zaxira muvaffaqiyatli yozilgandan keyingina `projects_v1` almashtiriladi. Bir xil zaxira takror qo‘shilmaydi; turli buzilgan nusxalar saqlanadi.

## Fayl va class vazifalari

- `lib/features/projects/project_store.dart`: ProjectStore, JSON o‘qish va zaxiralash siyosati. Flutter importi yo‘q; read/write callbacklari testda xatoli diskni taqlid qilishga imkon beradi.
- `lib/app/app_controller.dart`: mavjud ilova holati; prefs adapterini ProjectStore’ga uzatadi.
- `test/project_store_test.dart`: buzilgan satr, noto‘g‘ri root, qisman buzilgan ro‘yxat, backup failure, main write failure, buzilgan recovery va takroriy nusxalar.
- `test/workspace_test.dart`: haqiqiy AppController load → rename → yangi controller load oqimi, zaxira saqlanishi.

TDD: avval ProjectStore yo‘qligidan yangi testlar kompilyatsiyada yiqildi; so‘ng implementatsiya va controller integratsiyasi yozildi. Bu testlar OS process kill yoki elektr uzilishini simulyatsiya qilmaydi.

```sh
flutter test test/project_store_test.dart test/workspace_test.dart
flutter analyze
flutter test
flutter run -d <flutter-devices-dagi-id>
```

Telefon sinovi uchun test ma’lumotli loyiha yarating, nomini o‘zgartiring, ilovani qayta oching. Haqiqiy foydalanuvchi ma’lumotini ataylab buzmang; corruption ssenariylari izolyatsiyalangan testlarda bajariladi.

Bu to‘liq transactional storage emas. SharedPreferences saqlanib qoldi; keyingi bosqich — xatoda in-memory rollback, saqlash xatosini UI’da ko‘rsatish va recovery arxivini foydalanuvchi boshqaradigan tiklash oynasi. Zaxira buzilgan faylni avtomatik tuzatmaydi, uni yo‘qolishdan saqlaydi.

Offline/online: bu funksiya to‘liq lokal, API yoki yangi AI model talab qilmaydi. Asl video/audio fayllarga tegmaydi.

O‘rganilgan tamoyil: o‘qilmagan ma’lumotni tashlab yuborish recovery emas. Avval asl nusxani saqlash, keyin yangi holatni yozish kerak; yozish xatosi haqiqiy xato bo‘lib qolishi kerak.

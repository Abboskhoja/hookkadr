# HOOKKADR — mavjud imkoniyatlar

Ushbu pass: professional editor workspace. Oldingi foydalanuvchi o‘zgarishlari saqlandi.

| Qism | Holat | Dalil va chegara |
|---|---|---|
| Home, Projects, Templates, Settings | WORKING (widget) | `widget_test.dart`; native foydalanish alohida tekshiriladi |
| Trim, split, reorder, undo/redo | WORKING (widget/domain) | `editor_shot_tools_test.dart`, `editor_timeline_drag_test.dart` |
| Adaptive editor | WORKING (widget) | `editor_adaptive_test.dart`: 320×568, 844×390, 1024×768 |
| Native gallery import | PARTIALLY WORKING | `ClipImporter` ishlatiladi; permission denial va Android lost-data recovery to‘liq emas |
| Preview | PARTIALLY WORKING | Real VideoPlayer; speed, transition va musiqa preview parity hali to‘liq emas |
| MP4 export | Implemented; native tekshiruv alohida | `RenderService`, `kart_production_test.dart`; synthetic media testi gallery testi emas |
| Offline montaj buyruqlari | WORKING (test) | `CommandAgent`, `KadrDirector`, `editor_studio_test.dart` |
| Lokal generativ model | UNKNOWN — bu passda inference sinalmadi | Native adapter va pack manager mavjud; o‘rnatilgan model shart |
| Video multitrack / proxy | NOT IMPLEMENTED | Asosiy video ketma-ketligi; audio/caption lane multitrack video degani emas |
| Online Research | NOT IMPLEMENTED | Alohida source/citation/cache oqimi yo‘q |

`WORKING (widget)` telefon kodeki yoki permission oqimi tasdiqlanganini bildirmaydi.

# KADR AI imkoniyatlari

- Offline: CommandAgent/PlanOps orqali qo‘llab-quvvatlangan buyruqlar,
  storyboard, metadata tahlili, mahalliy render. Lokal LLM majburiy emas.
- Lokal model bilan: KadrLocalModel suhbat; KadrPainter va motion adapterlari
  tegishli pack o‘rnatilganida ishlaydi. Ushbu pass generativ sifatni tasdiqlamaydi.
- Online: mavjud provider adapterlari bor. Internet research manbalari va
  citations tizimi hali yo‘q. Ushbu pass tashqi AI so‘rovi yubormadi.
- Editor KadrAiSheet ichida deterministik va LLM takliflari Apply/Cancel orqali tasdiqlanadi; stale plan signature tekshiriladi. Boshqa kirish nuqtalarini alohida tekshirish kerak.

Layoutdagi o‘zgarishlar AI engine yoki loyiha formatini almashtirmaydi.

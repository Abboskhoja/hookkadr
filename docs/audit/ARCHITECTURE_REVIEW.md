# Arxitektura

Haqiqiy oqim: HomeShell → EditorScreen / ChatScreen → PlanOps / KadrDirector
→ EditPlan validatsiyasi → AppController → Project JSON / SharedPreferences
→ VideoPlayer preview → RenderService → FFmpeg → FFprobe verification.

`EditorWorkspace` faqat layout va ko‘rinish rejimlarini boshqaradi. U project
JSON yoki rendererga bog‘lanmaydi. Shu sabab orientation va preview rejimi
montaj tarixini o‘zgartirmaydi. `EditorScreen` mavjud amallarni ulashda qoladi.

Zaif joylar: AppController storage va AI routingni birlashtiradi; preview
FFmpeg export bilan bitta renderer emas; Editor ichidagi AI amallari endi Apply/Cancel orqali tasdiqlanadi. ProjectStore buzilgan project JSON uchun zaxiralash siyosatini ajratadi. Katta migratsiya qilinmadi.

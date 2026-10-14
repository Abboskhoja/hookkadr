# Implementation roadmap (vertikal bo'laklar)

1. **Rasmlardan reklama (offline)** — 5 ta foto → Kadr AI matn → kadr-aniq 20 s 9:16 reja (ritmga mos),
   Ken Burns harakati, o'tishlar, matnlar, sintez fon musiqasi → MP4 → ffprobe tekshiruvi. **Bajarildi (simulyator).**
2. **60 s videodan 15 s Reels** — sahna/sifat bo'yicha kadr tanlash (scene_quality + harakat), render, tekshiruv.
3. **Telefonda rasm generatsiyasi** — model/runtime benchmark (CoreML/llama.cpp-diffusion), qurilma darvozasi.
4. **Shaxsiylashtirish** — lokal afzalliklar (uslub, format, matn uslubi), o'chirish/reset bilan.
5. **Lokalizatsiya uz/en/ru** (5 tabli navigatsiya va Templates — bajarildi).
6. **Native GPU** (Metal) va Android `.so`; haqiqiy qurilma benchmarklari.

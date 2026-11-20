# E93: benchmark na telefonu – návod pro Jana

Scéna `godot-prototyp/bench_telefon.tscn` (skript `scripts/bench/bench_telefon.gd`). Hra se nemění; scéna jen spustí ostrov START
jako hra a změří ho. Trvá asi 1–3 minuty, displej nech zapnutý a telefon nech v klidu (ne na nabíječce, pokud chceš realistická čísla;
po měření zapiš, jestli byl teplý).

## A) Hotové APK (nejrychlejší)

Na boxu jsou dvě APK (nejsou v gitu): `/workspace/willage-ideas/telefon-e93/`

- `willage_bench_telefon_release.apk` – **na měření použij tuhle** (release šablona, rychlejší GDScript), podepsaná ladicím klíčem.
- `willage_bench_telefon_debug.apk` – ladicí šablona (pomalejší, pro chyby přes `adb logcat`).

Jen arm64-v8a, Android 7+ (OpenGL ES 3.0). Balík `cz.utalag.willage.bench`, název „Willage bench“.

1. Zkopíruj APK do telefonu (kabel, Drive, e-mail).
2. Povol instalaci z neznámých zdrojů pro aplikaci, kterou APK otevíráš, a nainstaluj.
3. Spusť „Willage bench“ na šířku. Počkej na „HOTOVO“.
4. Výsledek je **ve schránce** (dotykem na obrazovku se zkopíruje znovu) – vlož ho do chatu / poznámek. Na obrazovce je shrnutí
   (udělej snímek obrazovky). Plný JSON je i v `user://bench_telefon.json` (interní úložiště aplikace; u ladicího APK ho přečte
   `adb shell run-as cz.utalag.willage.bench cat files/bench_telefon.json`, u release jen přes schránku).
5. Napiš model telefonu, jestli byl na nabíječce, a jestli se scéna zasekávala.

Přes kabel s `adb`: `adb install -r willage_bench_telefon_release.apk`, `adb logcat -s godot` (výpis průběhu).

## B) Vlastní export z Godotu 4.7.2 (když chceš upravit scénu)

1. Editor → Manage Export Templates → stáhnout 4.7.2 (obsahuje Android).
2. Nainstaluj JDK 17 a Android SDK (Android Studio nebo command-line tools: `sdkmanager "platform-tools" "build-tools;35.0.1"
   "platforms;android-35"`).
3. Editor Settings → Export → Android: `Java SDK Path`, `Android SDK Path`, `Debug Keystore` (vytvoří se:
   `keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android
   -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12`).
4. Projekt: v `project.godot` je zapnuté `rendering/textures/vram_compression/import_etc2_astc=true` (Android to vyžaduje).
5. Export → preset **„Android (bench)“** (vlastní značka `bench_telefon` → hlavní scéna `res://bench_telefon.tscn`; hra a desktop
   mají dál `main.tscn`). Export Project / One-click deploy.
   Release bez vlastního klíče: proměnné `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD` = ladicí klíč (jen na test).

Příkazová řádka (jak to vzniklo na boxu):
`godot --headless --path godot-prototyp --export-release "Android (bench)" willage_bench_telefon_release.apk`

## Nastavení vykreslování pro mobil (stav a doporučení)

- `rendering_method` i `rendering_method.mobile` = `gl_compatibility` (OpenGL ES 3.0): nejširší podpora, levnější start;
  „Mobile“ (Vulkan) by mohl dát nižší CPU cenu draw calls, ale ne na všech telefonech.
- `directional_shadow/size` = 8192 a `soft_shadow_filter_quality` = 3 jsou na mobil drahé → zkusit `size.mobile = 2048`
  a kvalitu 0–1 (zatím NEZMĚNĚNO, jen návrh).
- MSAA 2× – na dlaždicových GPU relativně levné, ale stojí paměť.
- Benchmark má i průchod s 3D v polovičním rozlišení (`scaling_3d_scale` 0,5) – ukáže, jestli je telefon omezený pixely (GPU).

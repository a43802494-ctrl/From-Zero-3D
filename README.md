# FROM ZERO — RISE CITY (internal art and controls development build)

A Godot 4.6 first-person 3D mobile life simulator with jobs, delivery economy,
a main menu (PLAY/⚙ SETTINGS), adjustable volume/quality/sensitivity, saved
progress, 360-degree thumbstick and a small curated city built from real CC0 3D models.

## Build

```bash
python3 tools/fetch_models.py
# Then open in Godot 4.6 and import the models, or let GitHub Actions do both.
```

GitHub Actions builds an Android debug APK and publishes it under the run's Artifacts.
This is an *internal development build*, **not** an app-store release and not a
verified photorealistic or production-quality game. Test on an Android device.

## Art source and licensing

3D models by Kenney under CC0 1.0; downloaded via
[Hidencod/tge-assets](https://github.com/Hidencod/tge-assets).
See `assets/README.md`.

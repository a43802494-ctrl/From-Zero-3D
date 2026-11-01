# FROM ZERO — Rise City (Android 3D)

Godot 4.6 first-person city/life-sim **work-in-progress**, not a shipping-quality game. A mobile visual reconstruction with responsive landscape UI, an eight-direction analog stick, separate camera-touch area, hold-to-run, jump, 3D storefront facades, road details and a skinned animated glTF NPC.

## Build

Assets: `python3 tools/fetch_models.py` (fetches external GLBs with documented licenses; network required). Godot project import and APK export are automated by `.github/workflows/android.yml`. CI performs script validation, control layout tests and APK build. This does *not* constitute a real-device performance or aesthetic test.

See `README_AR.md` and `assets/ATTRIBUTIONS.md`.

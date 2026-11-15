# Android builds

## Identity and SDK

`com.stylemuse.ai` is **provisional for testing**. No reserved Android package,
Play Console registration, or upload keystore was found in this repository/docs.
It is not a verified Play reservation. Confirm the actual Play application ID
before publishing; changing the ID creates a separate Android app.

The app explicitly compiles and targets API **36**, with Flutter's minimum SDK.
Older plugin library compile SDKs are aligned to 36 in `build.gradle.kts`.
Official target requirements: https://developer.android.com/google/play/requirements/target-sdk

## VPS tools

```sh
source /opt/stylemuse-tooling/env.sh
cd /opt/stylemuse-flutter-play
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Flutter 3.50.0 / Dart 3.14.0: `/opt/stylemuse-tooling/flutter`.
Android SDK: `/opt/stylemuse-tooling/android-sdk` (platform 36, build tools
36.0.0, platform tools, NDK 28.2.13676358, CMake 3.22.1).
Java 17: `/usr/lib/jvm/java-17-openjdk-amd64` (Ubuntu package).
Generated local.properties and machine build caches are ignored.

Installable **debug-signed test APK**: `build/app/outputs/flutter-apk/app-debug.apk`.
This is not a production-signed release.

## Release signing fails closed

`flutter build appbundle --release` and release APK tasks throw during Gradle
configuration unless `android/key.properties` contains all fields below and
the referenced keystore file exists. There is no debug-signing fallback.
No production key has been generated or invented. Real cryptographic signing
still requires the correct key alias/password and Play-authorized upload key.

```properties
storeFile=/absolute/private/path/upload.jks
storePassword=SUPPLY_PRIVATELY
keyAlias=SUPPLY_PRIVATELY
keyPassword=SUPPLY_PRIVATELY
```

Keep that file and all keys outside Git (ignored). Only after the account owner
supplies genuine signing material should `flutter build appbundle --release`
be used. A successful local signature does not prove Play Console ownership.

## Emulator and memory

```sh
source /opt/stylemuse-tooling/env.sh
emulator -avd stylemuse_api36 -no-window -no-audio -no-boot-anim \
  -gpu swiftshader -memory 1024 -cores 2 -no-snapshot -no-metrics
adb devices -l
adb shell getprop sys.boot_completed
adb install --no-streaming -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.stylemuse.ai/.MainActivity
```

API36 Google APIs x86_64 AVD: `/root/.android/avd/stylemuse_api36.avd`.
KVM acceleration was verified usable. Prefer `--no-streaming` installation;
streamed installation stalled on this VPS.
The VPS has ~4 GB RAM. Initial Gradle builds were OOM-killed. Build memory is
bounded in gradle.properties; temporary 6 GB swap was enabled at
`/opt/stylemuse-tooling/build.swap` (not added to fstab). Avoid simultaneous
emulator/build workloads. Do not disable swap while it is in use without
checking available RAM. No live services were modified.

## Preserved PR16 baseline

Detached archive of `d8678c1` exists at `/opt/stylemuse-tooling/pr16-baseline`;
its lib files were not changed. Toolchain/platform files were added there only.
Evidence and successive build logs live under `/opt/stylemuse-tooling/`.
Baseline APK: `/opt/stylemuse-tooling/artifacts/stylemuse-pr16-baseline-debug.apk`.
Baseline build passed; baseline analysis reports one Flutter material import
deprecation info, and baseline `flutter test` cannot run because PR16 has no
`test/` directory. The release-signing rejection is captured in
`/opt/stylemuse-tooling/release-signing-gate.log`.

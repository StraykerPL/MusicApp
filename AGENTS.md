# Repository Guidelines

## Project Structure & Module Organization
`lib/` contains the Flutter application code. Core logic lives in `lib/Business/`, shared constants in `lib/Constants/`, data models in `lib/Models/`, reusable UI helpers in `lib/Shared/`, and screen-level widgets in `lib/Widgets/`. The app entry point is [`lib/main.dart`](A:/Repozytoria/musicapp/lib/main.dart).

Tests live under `test/`. Use `test/unit/` for isolated unit tests, `test/mocks/` for test doubles such as the FFI-backed database helper, and top-level `test/*_test.dart` files for feature-focused coverage. Static assets are stored in `assets/`, currently including the app logo.

## Build, Test, and Development Commands
Run commands from the repository root:

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter test test/database_helper_test.dart
dart format lib test
```

`flutter pub get` installs dependencies. `flutter run` launches the app on the selected device. `flutter analyze` applies the lints from `analysis_options.yaml`. `flutter test` runs the full suite; the targeted test command is useful when changing database code. `dart format` keeps Dart files consistent before review.

## Coding Style & Naming Conventions
Follow `package:flutter_lints/flutter.yaml`. Use 2-space indentation and keep files ASCII unless the file already uses Unicode. Prefer `UpperCamelCase` for classes, `lowerCamelCase` for methods and variables, and `snake_case.dart` for filenames. Keep business logic in `lib/Business/` instead of embedding it directly in widgets.

## Testing Guidelines
Use `flutter_test` for unit and widget tests. Name test files `*_test.dart` and describe cases in terms of behavior, for example `insertData stores every provided row`. When mocking persistence, prefer realistic helpers over handwritten API shims. Add or update tests for any behavior change in database, playlist, or audio-management code.

## Commit & Pull Request Guidelines
Recent history uses short, imperative summaries such as `Add playlist feature...` and `General refactor and code simplification...`. Keep commit subjects specific and under one line. Group related changes into a single commit when practical.

PRs should include a clear description, linked issue when applicable, and screenshots for UI changes. Call out platform-specific impact if a change touches Android, iOS, desktop, or web folders.

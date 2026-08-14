import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Models/app_dependencies.dart';
import 'package:strayker_music/main.dart';

void main() {
  testWidgets('mounts a loading MaterialApp before dependencies complete',
      (WidgetTester tester) async {
    final pending = Completer<AppDependencies>();

    await tester.pumpWidget(
      BootstrapApp(dependenciesInitializer: () => pending.future),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('dependency failure renders retry and starts a new attempt',
      (WidgetTester tester) async {
    final previousOnError = FlutterError.onError;
    final reportedErrors = <FlutterErrorDetails>[];
    FlutterError.onError = reportedErrors.add;
    addTearDown(() => FlutterError.onError = previousOnError);
    var attempts = 0;
    final retryPending = Completer<AppDependencies>();
    Future<AppDependencies> initialize() {
      attempts++;
      if (attempts == 1) {
        return Future<AppDependencies>.error(StateError('audio unavailable'));
      }
      return retryPending.future;
    }

    await tester.pumpWidget(
      BootstrapApp(dependenciesInitializer: initialize),
    );
    await tester.pump();

    expect(find.textContaining('audio unavailable'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await tester.pump();

    expect(attempts, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(reportedErrors, hasLength(1));
  });
}

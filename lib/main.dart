import 'dart:async';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/app_dependencies.dart';
import 'package:strayker_music/Repositories/music_file_repository.dart';
import 'package:strayker_music/Repositories/playlist_repository.dart';
import 'package:strayker_music/Repositories/settings_snapshot_repository.dart';
import 'package:strayker_music/Services/database_helper.dart';
import 'package:strayker_music/Services/default_audio_handler.dart';
import 'package:strayker_music/Services/music_library_service.dart';
import 'package:strayker_music/Services/playlist_manager.dart';
import 'package:strayker_music/Services/sound_collection_manager.dart';
import 'package:strayker_music/Services/sound_player.dart';
import 'package:strayker_music/ViewModels/playlist_view_model.dart';
import 'package:strayker_music/Widgets/playlist_view.dart';
import 'package:strayker_music/Widgets/app_error_view.dart';
import 'package:strayker_music/Widgets/app_loading_view.dart';
import 'package:strayker_music/Widgets/app_startup_error_view.dart';

typedef AppDependenciesInitializer = Future<AppDependencies> Function();

void main() {
  runZonedGuarded<void>(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = FlutterError.presentError;
    PlatformDispatcher.instance.onError =
        (Object error, StackTrace stackTrace) {
      FlutterError.presentError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
      return true;
    };
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return AppErrorView(error: details.exception);
    };
    runApp(const BootstrapApp());
  }, (Object error, StackTrace stackTrace) {
    FlutterError.presentError(
      FlutterErrorDetails(exception: error, stack: stackTrace),
    );
  });
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({
    super.key,
    this.dependenciesInitializer = initializeDependencies,
  });

  final AppDependenciesInitializer dependenciesInitializer;

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late Future<AppDependencies> _dependenciesFuture;
  AppDependencies? _dependencies;

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  void _startInitialization() {
    final Future<AppDependencies> future = widget.dependenciesInitializer();
    _dependenciesFuture = future;
    unawaited(
      future.then<void>(
        (AppDependencies dependencies) {
          if (!mounted || !identical(_dependenciesFuture, future)) {
            unawaited(dependencies.dispose());

            return;
          }

          _dependencies = dependencies;
        },
        onError: (Object error, StackTrace stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              context: ErrorDescription('while initializing app dependencies'),
            ),
          );
        },
      ),
    );
  }

  void _retry() {
    setState(_startInitialization);
  }

  @override
  void dispose() {
    final AppDependencies? dependencies = _dependencies;
    if (dependencies != null) {
      unawaited(dependencies.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Constants.appName,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A2D47),
          primary: const Color(0xFF1A2D47),
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: FutureBuilder<AppDependencies>(
        future: _dependenciesFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<AppDependencies> snapshot,
        ) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingView();
          }

          if (snapshot.hasError) {
            return AppStartupErrorView(
              error: snapshot.error!,
              onRetry: _retry,
            );
          }

          return _AppProviders(dependencies: snapshot.requireData);
        },
      ),
    );
  }
}

class _AppProviders extends StatelessWidget {
  const _AppProviders({required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<SoundPlayer>(
          create: (_) => SoundPlayer(handler: dependencies.audioHandler),
        ),
        Provider<PlaylistRepository>.value(
          value: dependencies.playlistRepository,
        ),
        Provider<SettingsSnapshotRepository>.value(
          value: dependencies.settingsSnapshotRepository,
        ),
        Provider<MusicLibraryService>.value(
          value: dependencies.musicLibraryService,
        ),
        ChangeNotifierProvider<PlaylistManager>(
          create: (BuildContext context) => PlaylistManager(
            playlistRepository: context.read<PlaylistRepository>(),
            allSongs: const <Never>[],
          ),
        ),
        Provider<SoundCollectionManager>(
          create: (BuildContext context) => SoundCollectionManager(
            player: context.read<SoundPlayer>(),
            settingsSnapshotRepository:
                context.read<SettingsSnapshotRepository>(),
          ),
        ),
        ChangeNotifierProvider<PlaylistViewModel>(
          create: (BuildContext context) => PlaylistViewModel(
            playlistManager: context.read<PlaylistManager>(),
            soundCollectionManager: context.read<SoundCollectionManager>(),
            musicLibraryService: context.read<MusicLibraryService>(),
          )..initialize(),
        ),
      ],
      child: const PlaylistView(),
    );
  }
}

Future<AppDependencies> initializeDependencies() async {
  final DatabaseHelper databaseHelper = DatabaseHelper();
  final PlaylistRepository playlistRepository = PlaylistRepository(
    databaseHelper: databaseHelper,
  );
  final SettingsSnapshotRepository settingsRepository =
      SettingsSnapshotRepository(databaseHelper: databaseHelper);
  final MusicFileRepository musicFileRepository = MusicFileRepository();
  final MusicLibraryService musicLibraryService = MusicLibraryService(
    musicFileRepository: musicFileRepository,
    settingsSnapshotRepository: settingsRepository,
  );
  final DefaultAudioHandler audioHandler = await initializeAudioHandler();

  return AppDependencies(
    playlistRepository: playlistRepository,
    settingsSnapshotRepository: settingsRepository,
    musicLibraryService: musicLibraryService,
    audioHandler: audioHandler,
  );
}

Future<DefaultAudioHandler> initializeAudioHandler() async {
  final DefaultAudioHandler preparedHandler =
      await DefaultAudioHandler.create();
  try {
    return await AudioService.init<DefaultAudioHandler>(
      builder: () => preparedHandler,
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'pl.straykersoftware.strayker_music.channel.audio',
        androidNotificationChannelName: Constants.appName,
      ),
    );
  } on Object catch (error, stackTrace) {
    await preparedHandler.dispose();
    Error.throwWithStackTrace(error, stackTrace);
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Business/playlist_manager.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/ViewModels/playlist_view_model.dart';
import 'package:strayker_music/ViewModels/settings_view_model.dart';
import 'package:strayker_music/Widgets/settings.dart';

class MainDrawer extends StatefulWidget {
  const MainDrawer({super.key});

  @override
  State<MainDrawer> createState() => _MainDrawer();
}

class _MainDrawer extends State<MainDrawer> {
  late final PackageInfo _packageInfo;

  @override
  void initState() {
    PackageInfo.fromPlatform().then((info) {
      _packageInfo = info;
    });
    super.initState();
  }

  _showAboutAppDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(Constants.appName),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                    'Version: ${_packageInfo.version}+${_packageInfo.buildNumber}\n\nOS Version: ${Platform.operatingSystemVersion}\n\nDart: ${Platform.version}'),
                const Image(image: AssetImage('assets/logo.png')),
                const Text(
                    "Copyright © 2018-actual Daniel Strayker Nowak\nAll rights reserved")
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('OK',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.displayLarge?.color)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistViewModel = context.watch<PlaylistViewModel>();

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              // TODO: Special version of Strayker Logo must be created for that.
              // image: DecorationImage(
              //   image: AssetImage('assets/logo.png'),
              //   alignment: Alignment.bottomLeft
              // ),
            ),
            child: const SizedBox(
              width: double.infinity,
              child: Text(Constants.appName),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(right: 16.0),
              itemCount: playlistViewModel.availablePlaylists.length,
              itemBuilder: (ctx, index) {
                final playlistName =
                    playlistViewModel.availablePlaylists[index];
                return ListTile(
                  title: Text(playlistName),
                  onTap: () async {
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      await playlistViewModel.switchPlaylist(playlistName);
                    }
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text("Settings"),
            onTap: () {
              final databaseHelper = context.read<DatabaseHelper>();
              final playlistManager = context.read<PlaylistManager>();
              final loadedSongCount = context.read<List<MusicFile>>().length;
              Navigator.push(
                context,
                MaterialPageRoute(
                  // Route-scoped: the provider disposes unsaved settings state
                  // when the settings route is removed.
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => SettingsViewModel(
                      databaseHelper: databaseHelper,
                      playlistManager: playlistManager,
                      loadedSongCount: loadedSongCount,
                    )..load(),
                    child: const SettingsView(),
                  ),
                ),
              );
            },
          ),
          ListTile(
            title: const Text("About"),
            onTap: () {
              _showAboutAppDialog(context);
            },
          )
        ],
      ),
    );
  }
}

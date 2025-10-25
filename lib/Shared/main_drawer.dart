import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Business/playlist_manager.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Widgets/settings.dart';

class MainDrawer extends StatefulWidget {
  const MainDrawer({super.key});

  @override
  State<MainDrawer> createState() => _MainDrawer();
}

class _MainDrawer extends State<MainDrawer> {
  late final PackageInfo _packageInfo;
  late final PlaylistManager _playlistManager;
  List<String> _playlists = [];

  @override
  void initState() {
    PackageInfo.fromPlatform().then((info) {
      _packageInfo = info;
    });
    _playlistManager = context.read<PlaylistManager>();
    _playlistManager.loadAvailablePlaylists().then((_) => {
      setState(() {
        _playlists = _playlistManager.availablePlaylists;
      })
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
                Text('Version: ${_packageInfo.version}+${_packageInfo.buildNumber}\n\nOS Version: ${Platform.operatingSystemVersion}\n\nDart: ${Platform.version}'),
                const Image(image: AssetImage('assets/logo.png')),
                const Text("Copyright © 2018-actual Daniel Strayker Nowak\nAll rights reserved")
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color)),
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
              itemCount: _playlists.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_playlists[index]),
                  onTap: () async {
                    if (context.mounted) {
                      await _playlistManager.switchToPlaylist(_playlists[index]);
                      Navigator.of(context).pop();
                    }
                  },
                );
              }
            ),
          ),
          ListTile(
            title: const Text("Settings"),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsView()));
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
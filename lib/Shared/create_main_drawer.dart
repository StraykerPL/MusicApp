import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:strayker_music/Widgets/settings.dart';

Future<void> _showAboutAppDialog(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    return showDialog<void>(
      // ignore: use_build_context_synchronously
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Strayker Music'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Version: ${packageInfo.version}+${packageInfo.buildNumber}\n\nOS Version: ${Platform.operatingSystemVersion}\n\nDart: ${Platform.version}'),
                const Image(image: AssetImage('assets/logo.png')),
                const Text("Copyright © 2018-actual Daniel Strayker Nowak\nAll rights reserved")
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

Drawer createMainDrawer(BuildContext context) {
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
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
          child: const Text("Strayker Music"),
        ),
        ListTile(
          title: const Text("Settings"),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (ctxt) => const SettingsView()));
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
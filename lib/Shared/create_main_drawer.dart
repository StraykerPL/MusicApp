import 'dart:io';

import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Widgets/settings.dart';

Future<void> _showAboutAppDialog(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    return showDialog<void>(
      // ignore: use_build_context_synchronously
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(Constants.appName),
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

TreeNode _buildTreeNodes() {
  // TODO: Replace placeholder with database read logic.
  final List<String> playlists = [
    "Playlist 1",
    "PlayList 2",
    "Playlist 3",
  ];
  TreeNode rootNode = TreeNode(data: "Playlists");
  
  for (int i = 0; i < playlists.length; i++) {
    rootNode.add(TreeNode(key: i.toString(), data: playlists[i]));
  }

  return rootNode;
}

Drawer createMainDrawer(BuildContext context) {
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
          child: TreeView.simple(
            padding: const EdgeInsets.only(right: 16.0),
            tree: _buildTreeNodes(),
            expansionIndicatorBuilder: (context, node) => ChevronIndicator.rightDown(
              alignment: Alignment.centerRight,
              tree: node,
              color: Theme.of(context).textTheme.displayLarge?.color,
            ),
            onItemTap: (item) {
              // TODO: Add indicator to ListTile for currently active playlist.
              // if (!item.isRoot) {
              //   ScaffoldMessenger.of(context).showSnackBar(
              //     SnackBar(content: Text("Selected: ${item.data}")),
              //   );
              // }
            },
            builder: (context, node) => ListTile(
              title: Text(
                node.data.toString(),
                style: TextStyle(
                  fontWeight: node.isLeaf ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
          ),
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
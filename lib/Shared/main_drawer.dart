import 'dart:io';

import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Constants/constants.dart';
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

  TreeNode _buildTreeNodes() {
    // TODO: Replace placeholder with database read logic.
    final List<String> playlists = [
      "Playlist 1",
      "Playlist 2",
      "Playlist 3",
    ];
    TreeNode rootNode = TreeNode(data: "Playlists");
    
    for (int i = 0; i < playlists.length; i++) {
      rootNode.add(TreeNode(key: i.toString(), data: playlists[i]));
    }

    return rootNode;
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
              Navigator.push(context, MaterialPageRoute(builder: (ctxt) => context.watch<SettingsView>()));
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
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MusicApp',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'MusicApp'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final player = AudioPlayer();
  List<FileSystemEntity> _files1 = [];
  List<FileSystemEntity> _files2 = [];
  List<FileSystemEntity> _songs = [];
  String selectedSongPath = "";

  void getMusicFiles() {
    Permission.manageExternalStorage.request();
    Directory dir1 = Directory('/storage/emulated/0/MicroSD/Muzyka');
    Directory dir2 = Directory('/storage/emulated/0/MicroSD/Muzyka One Republic');
    
    try {
      _files1 = dir1.listSync(recursive: true, followLinks: false);
      _files2 = dir2.listSync(recursive: true, followLinks: false);
    } catch (e) {
      print(e);
    }

    for(FileSystemEntity entity in _files1) {
      String path = entity.path;
      if(path.endsWith('.mp3')) {
        setState(() {
          _songs.add(entity);
        });
      }
    }

    for(FileSystemEntity entity in _files2) {
      String path = entity.path;
      if(path.endsWith('.mp3')) {
        setState(() {
          _songs.add(entity);
        });
      }
    }
  }

  void playSond(String songName) {
    player.stop();
    player.setUrl(songName);
    player.play();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => getMusicFiles());
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Column (
        children: [
          _songs.isNotEmpty ? ListView.builder(
            scrollDirection: Axis.vertical,
            shrinkWrap: true,
            itemCount: _songs.length,
            prototypeItem: ListTile(
              title: Text(_songs.first.path),
            ),
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(_songs[index].path),
                onTap: () => {
                  selectedSongPath = _songs[index].path
                },
              );
            },
          ) : const Text("Empty Music List"),
          ElevatedButton(
            onPressed: () {
              playSond(selectedSongPath);
            },
            child: const Text('Play'),
          )],
      ),
    );
  }
}

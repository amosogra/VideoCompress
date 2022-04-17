import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:file_selector/file_selector.dart';
import 'package:video_compress_example/utils/file_utils.dart';
import 'package:video_compress_example/video_player.dart';
import 'dart:io';

import './video_thumbnail.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _counter = "video";
  late String _desFile;
  String? _displayedFile;
  late int _duration;
  String? _filePath;
  bool _isVideoCompressed = false;
  Subscription? _subscription;
  StreamController<double> controller = StreamController<double>.broadcast();

  @override
  void initState() {
    super.initState();
    _subscription = VideoCompress.compressProgress$.subscribe((progress) {
      controller.add(progress);
      //debugPrint('progress: $progress');
    });
  }

  @override
  void dispose() {
    super.dispose();
    controller.close();
    _subscription?.unsubscribe();
  }

  _compressVideo() async {
    _isVideoCompressed = false;
    var file;
    if (Platform.isMacOS) {
      final typeGroup = XTypeGroup(label: 'videos', extensions: ['mov', 'mp4']);
      file = await openFile(acceptedTypeGroups: [typeGroup]);
    } else {
      final picker = ImagePicker();
      PickedFile? pickedFile = await picker.getVideo(source: ImageSource.gallery);
      file = File(pickedFile!.path);
    }
    if (file == null) {
      return;
    }

    _filePath = file.path;
    await VideoCompress.setLogLevel(0);
    final Stopwatch stopwatch = Stopwatch()..start();
    final MediaInfo? info = await VideoCompress.compressVideo(
      file.path,
      //frameRate: 24,
      quality: VideoQuality.DefaultQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    stopwatch.stop();
    final Duration duration = Duration(milliseconds: stopwatch.elapsedMilliseconds);
    _duration = duration.inSeconds;
    //print(info!.path);
    if (info != null) {
      setState(() {
        _desFile = info.path!;
        _displayedFile = info.path;
        _isVideoCompressed = true;
      });
    }
  }

  String _getVideoSize({required File file}) => formatBytes(file.lengthSync(), 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compressor Sample'),
        actions: <Widget>[
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            onPressed: () => VideoCompress.cancelCompression(),
          )
        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            if (_filePath != null)
              Text(
                'Original size: ${_getVideoSize(file: File(_filePath!))}',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 8),
            if (_isVideoCompressed)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Size after compression: ${_getVideoSize(file: File(_desFile))}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Duration: $_duration seconds',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Visibility(
              //visible: VideoCompress.isCompressing,
              child: StreamBuilder<double>(
                stream: controller.stream,
                builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                  if (snapshot.data != null && snapshot.data > 0) {
                    return Column(
                      children: <Widget>[
                        LinearProgressIndicator(
                          minHeight: 8,
                          value: snapshot.data / 100,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.data.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 20),
                        )
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            const SizedBox(height: 24),
            if (_displayedFile != null)
              Builder(
                builder: (BuildContext context) => Container(
                  alignment: Alignment.center,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push<dynamic>(
                      context,
                      MaterialPageRoute<dynamic>(
                        builder: (_) => VideoPlayerScreen(_desFile),
                      ),
                    ),
                    child: const Text('Play Video'),
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VideoThumbnail()),
                );
              },
              child: Text('Test thumbnail'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async => _compressVideo(),
        label: const Text('Pick Video'),
        icon: const Icon(Icons.video_library),
        backgroundColor: const Color(0xFFA52A2A),
      ),
    );
  }
}

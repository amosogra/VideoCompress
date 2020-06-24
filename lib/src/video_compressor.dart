import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'video_quality.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'media_info.dart';

class VideoCompress {

  static const _channel = const MethodChannel('video_compress');

  static VideoCompress _instance;

  static VideoCompress get instance => _instance ?? VideoCompress();

  factory VideoCompress() {
    if (_instance == null) _instance = VideoCompress._();
    return _instance;
  }

  StreamController<double> _progressController;

  Stream<double> get compressProgress$ => _progressController.stream;

  static bool _hasProgressListeners = false;

  ///
  /// Flag to check compression state
  ///
  static bool _isCompressing = false;
  static bool get isCompressing => _isCompressing;




  VideoCompress._() {
    _progressController = StreamController.broadcast(onListen: () {
      _hasProgressListeners = true;
    });

    _channel.setMethodCallHandler(_progressCallback);
  }


  Future<void> _progressCallback(MethodCall call) async {
    switch (call.method) {
      case 'updateProgress':
        final progress = double.tryParse(call.arguments.toString());
        if (progress != null) _progressController.add(progress);
        break;
    }
  }

  static Future<T> _invoke<T>(String name,
      [Map<String, dynamic> params]) async {
    T result;
    try {
      result = params != null
          ? await _channel.invokeMethod(name, params)
          : await _channel.invokeMethod(name);
    } on PlatformException catch (e) {
      debugPrint('''Error from VideoCompress: 
      Method: $name
      $e''');
    }
    return result;
  }

  /// getByteThumbnail return [Future<Uint8List>],
  /// quality can be controlled by [quality] from 1 to 100,
  /// select the position unit in the video by [position] is seconds
  static Future<Uint8List> getByteThumbnail(
    String path, {
    int quality = 100,
    int position = -1,
  }) async {
    assert(path != null);
    assert(quality > 1 || quality < 100);

    return await _invoke<Uint8List>('getByteThumbnail', {
      'path': path,
      'quality': quality,
      'position': position,
    });
  }

  /// getFileThumbnail return [Future<File>]
  /// quality can be controlled by [quality] from 1 to 100,
  /// select the position unit in the video by [position] is seconds
  static Future<File> getFileThumbnail(
    String path, {
    int quality = 100,
    int position = -1,
  }) async {
    assert(path != null);
    assert(quality > 1 || quality < 100);

    final filePath = await _invoke<String>('getFileThumbnail', {
      'path': path,
      'quality': quality,
      'position': position,
    });

    final file = File(filePath);

    return file;
  }

  /// get media information from [path]
  ///
  /// get media information from [path] return [Future<MediaInfo>]
  ///
  /// ## example
  /// ```dart
  /// final info = await _flutterVideoCompress.getMediaInfo(file.path);
  /// debugPrint(info.toJson());
  /// ```
  static Future<MediaInfo> getMediaInfo(String path) async {
    assert(path != null);
    final jsonStr = await _invoke<String>('getMediaInfo', {'path': path});
    final jsonMap = json.decode(jsonStr);
    return MediaInfo.fromJson(jsonMap);
  }

  /// compress video from [path]
  /// compress video from [path] return [Future<MediaInfo>]
  ///
  /// you can choose its quality by [quality],
  /// determine whether to delete his source file by [deleteOrigin]
  /// optional parameters [startTime] [duration] [includeAudio] [frameRate]
  ///
  /// ## example
  /// ```dart
  /// final info = await _flutterVideoCompress.compressVideo(
  ///   file.path,
  ///   deleteOrigin: true,
  /// );
  /// debugPrint(info.toJson());
  /// ```
  static Future<MediaInfo> compressVideo(
    String path, {
    VideoQuality quality = VideoQuality.DefaultQuality,
    bool deleteOrigin = false,
    int startTime,
    int duration,
    bool includeAudio,
    int frameRate = 30,
  }) async {
    assert(path != null);
    if (_isCompressing) {
      throw StateError('''VideoCompress Error: 
      Method: compressVideo
      Already have a compression process, you need to wait for the process to finish or stop it''');
    }
    _isCompressing = true;
    if (!_hasProgressListeners) {
      debugPrint('''VideoCompress: You can try to subscribe to the 
      compressProgress\$ stream to know the compressing state.''');
    }
    final jsonStr = await _invoke<String>('compressVideo', {
      'path': path,
      'quality': quality.index,
      'deleteOrigin': deleteOrigin,
      'startTime': startTime,
      'duration': duration,
      'includeAudio': includeAudio,
      'frameRate': frameRate,
    });
    _isCompressing = false;
    final jsonMap = json.decode(jsonStr);
    return MediaInfo.fromJson(jsonMap);
  }

  /// stop compressing the file that is currently being compressed.
  /// If there is no compression process, nothing will happen.
  static Future<void> cancelCompression() async {
    await _invoke<void>('cancelCompression');
  }

  /// delete the cache folder, please do not put other things
  /// in the folder of this plugin, it will be cleared
  static Future<bool> deleteAllCache() async {
    return await _invoke<bool>('deleteAllCache');
  }
}

class ObservableBuilder<T> {
  final StreamController<T> _observable = StreamController();
  bool notSubscribed = true;

  void next(T value) {
    _observable.add(value);
  }

  Subscription subscribe(void onData(T event),
      {Function onError, void onDone(), bool cancelOnError}) {
    notSubscribed = false;
    _observable.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    return Subscription(_observable.close);
  }
}

class Subscription {
  final VoidCallback unsubscribe;
  const Subscription(this.unsubscribe);
}

import 'ggwave_flutter_platform_interface.dart';

class GGWaveFlutter {

  GGWaveFlutter(GGWaveFlutterCallbacks callbacks){
    GGWaveFlutterPlatform.instance.setOnMessageReceivedListener(callbacks.onMessageReceived);
    GGWaveFlutterPlatform.instance.setOnPlaybackStartListener(callbacks.onPlaybackStart);
    GGWaveFlutterPlatform.instance.setOnPlaybackStopListener(callbacks.onPlaybackStop);
    GGWaveFlutterPlatform.instance.setOnPlaybackCompleteListener(callbacks.onPlaybackComplete);
    GGWaveFlutterPlatform.instance.setOnCaptureStartListener(callbacks.onCaptureStart);
    GGWaveFlutterPlatform.instance.setOnCaptureStopListener(callbacks.onCaptureStop);
  }

  Future<void> togglePlayback(
      {required String message, required GGWaveProtocolMode mode, required int volume,}) async {
    final modeIndex = GGWaveProtocolMode.values.indexOf(mode);
    await GGWaveFlutterPlatform.instance.togglePlayback(message, modeIndex, volume);
  }

  Future<void> toggleCapture() async {
    await GGWaveFlutterPlatform.instance.toggleCapture();
  }
}

class GGWaveFlutterCallbacks {
  final Function(String message) onMessageReceived;
  final Function() onPlaybackStart;
  final Function() onPlaybackStop;
  final Function() onPlaybackComplete;
  final Function() onCaptureStart;
  final Function() onCaptureStop;

  GGWaveFlutterCallbacks({
    required this.onMessageReceived,
    required this.onPlaybackStart,
    required this.onPlaybackStop,
    required this.onPlaybackComplete,
    required this.onCaptureStart,
    required this.onCaptureStop,
  });
}

enum GGWaveProtocolMode {
  AUDIBLE_NORMAL,
  AUDIBLE_FAST,
  AUDIBLE_FASTEST,
  ULTRASOUND_NORMAL,
  ULTRASOUND_FAST,
  ULTRASOUND_FASTEST,
  DT_NORMAL,
  DT_FAST,
  DT_FASTEST,
  MT_NORMAL,
  MT_FAST,
  MT_FASTEST,
}
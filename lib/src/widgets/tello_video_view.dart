import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TelloVideoView extends StatelessWidget {
  const TelloVideoView({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('LIVE VIDEO IST DERZEIT NUR AUF ANDROID VERFÜGBAR'),
        ),
      );
    }

    return const AndroidView(viewType: 'de.example.telloapp/video-view');
  }
}

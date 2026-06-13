import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/tello_controller.dart';

final telloControllerProvider = ChangeNotifierProvider<TelloController>(
  (ref) => TelloController(),
);

import 'package:flutter_riverpod/legacy.dart';

import '../controllers/tello_controller.dart';

final telloControllerProvider = ChangeNotifierProvider<TelloController>(
  (ref) => TelloController(),
);

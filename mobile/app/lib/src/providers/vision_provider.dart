import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/vision_api.dart';
import '../app/bootstrap.dart';
import '../config/app_config.dart';

final visionApiProvider = Provider<VisionApi>((ref) {
  final config = ref.watch(envConfigProvider);
  final interceptors = ref.watch(dioInterceptorsProvider);
  final dio = createBaseDio(config: config, interceptors: interceptors);
  return VisionApi(dio);
});

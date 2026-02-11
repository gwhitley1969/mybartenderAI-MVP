import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/vision_api.dart';
import 'backend_provider.dart';

final visionApiProvider = Provider<VisionApi>((ref) {
  final backendService = ref.watch(backendServiceProvider);
  return VisionApi(backendService.dio);
});

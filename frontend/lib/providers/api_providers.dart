import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/api_services.dart';

final apiProvider = Provider<ApiService>((ref) => ApiService());

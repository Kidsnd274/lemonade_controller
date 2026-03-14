import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/services/api_client.dart';

final apiClientProvider = Provider<LemonadeApiClient>((ref) => LemonadeApiClient());


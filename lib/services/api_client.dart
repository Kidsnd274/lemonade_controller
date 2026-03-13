import 'package:dio/dio.dart';
import 'package:lemonade_controller/utils/logger.dart';

final logger = createLogger("api_client");

class LemonadeApiClient {
  static const String baseUrl = 'http://192.168.1.7:8020/api/v1';
  final Dio _dio = Dio();

  Future<Map<String, dynamic>> getSystemInfo() async {
    logger.i('Fetching system info from $baseUrl/system-info');
    try {
      final response = await _dio.get('$baseUrl/system-info');
      logger.i('System info fetched successfully: ${response.data}');
      return response.data;
    } catch (e, stackTrace) {
      logger.e(
        'Failed to load system info: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to load system info: $e');
    }
  }

  Future<Map<String, dynamic>> getHealth() async {
    logger.i('Fetching health status from $baseUrl/health');
    try {
      final response = await _dio.get('$baseUrl/health');
      logger.i('Health status fetched successfully: ${response.data}');
      return response.data;
    } catch (e, stackTrace) {
      logger.e(
        'Failed to load health status: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to load health status: $e');
    }
  }

  Future<List<dynamic>> getModelsList() async {
    logger.i('Fetching models list from $baseUrl/models');
    try {
      final response = await _dio.get('$baseUrl/models');
      logger.i(
        'Models list fetched successfully, data count: ${response.data['data']?.length ?? 0}',
      );
      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e, stackTrace) {
      logger.e(
        'Failed to load models list: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to load models list: $e');
    }
  }
}

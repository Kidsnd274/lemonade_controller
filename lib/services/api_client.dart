import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

final logger = Logger("api_client");

class LemonadeApiClient {
  static const String baseUrl = 'http://192.168.1.7:8020/api/v1';
  final Dio _dio = Dio();

  Future<Map<String, dynamic>> getSystemInfo() async {
    logger.fine('Fetching system info from $baseUrl/system-info');
    try {
      final response = await _dio.get('$baseUrl/system-info');
      logger.fine('System info fetched successfully: ${response.data}');
      return response.data;
    } catch (e, stackTrace) {
      logger.severe('Failed to load system info: $e', e, stackTrace);
      throw Exception('Failed to load system info: $e');
    }
  }

  Future<Map<String, dynamic>> getHealth() async {
    logger.fine('Fetching health status from $baseUrl/health');
    try {
      final response = await _dio.get('$baseUrl/health');
      logger.fine('Health status fetched successfully: ${response.data}');
      return response.data;
    } catch (e, stackTrace) {
      logger.severe('Failed to load health status: $e', e, stackTrace);
      throw Exception('Failed to load health status: $e');
    }
  }

  Future<List<dynamic>> getModelsList() async {
    logger.fine('Fetching models list from $baseUrl/models');
    try {
      final response = await _dio.get('$baseUrl/models');
      logger.fine(
        'Models list fetched successfully, data count: ${response.data['data']?.length ?? 0}',
      );
      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e, stackTrace) {
      logger.severe('Failed to load models list: $e', e, stackTrace);
      throw Exception('Failed to load models list: $e');
    }
  }
}

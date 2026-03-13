import 'package:dio/dio.dart';

class LemonadeApiClient {
  static const String baseUrl = 'http://192.168.1.7:8020/api/v1';
  final Dio _dio = Dio();

  Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      final response = await _dio.get('$baseUrl/system-info');
      return response.data;
    } catch (e) {
      throw Exception('Failed to load system info: $e');
    }
  }

  Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await _dio.get('$baseUrl/health');
      return response.data;
    } catch (e) {
      throw Exception('Failed to load health status: $e');
    }
  }

  Future<List<dynamic>> getModelsList() async {
    try {
      final response = await _dio.get('$baseUrl/models');
      print('Full response: ${response.data}');
      print('response.data type: ${response.data.runtimeType}');
      print('response.data["data"]: ${response.data['data']}');

      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e) {
      throw Exception('Failed to load models list: $e');
    }
  }
}

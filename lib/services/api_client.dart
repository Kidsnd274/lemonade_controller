import 'package:dio/dio.dart';
import 'package:lemonade_controller/models/lemonade_load_options.dart';
import 'package:lemonade_controller/models/lemonade_unload_options.dart';
import 'package:lemonade_controller/models/loaded_model.dart';
import 'package:lemonade_controller/services/settings_service.dart';
import 'package:lemonade_controller/utils/logger.dart';

final logger = createLogger("api_client");

class LemonadeApiClient {
  final Dio _dio = Dio();
  final SettingsService _settingsService = SettingsService();

  Future<String> get baseUrl async {
    return await _settingsService.getBaseUrl();
  }

  Future<Map<String, dynamic>> getSystemInfo() async {
    final baseUrl = await this.baseUrl;
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
    final baseUrl = await this.baseUrl;
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
    final baseUrl = await this.baseUrl;
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

  Future<bool> loadModel(LemonadeLoadOptionsModel options) async {
    final baseUrl = await this.baseUrl;
    logger.i('Sending command to load ${options.modelName}');
    try {
      final response = await _dio.post('$baseUrl/load', data: options.toJson());
      return response.statusCode == 200;
    } on DioException catch (e) {
      logger.e('Failed to load model', error: e, stackTrace: e.stackTrace);
      return false;
    }
  }

  Future<bool> unloadModel(LemonadeUnloadOptionsModel options) async {
    final baseUrl = await this.baseUrl;
    logger.i('Sending command to unload ${options.modelName}');
    try {
      final response = await _dio.post(
        '$baseUrl/unload',
        data: options.toJson(),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      logger.e('Failed to unload model', error: e, stackTrace: e.stackTrace);
      return false;
    }
  }

  Future<List<LoadedModel>> getLoadedModels() async {
    final health = await getHealth();
    final models = health['all_models_loaded'] as List;
    return models.map((json) => LoadedModel.fromJson(json)).toList();
  }
}

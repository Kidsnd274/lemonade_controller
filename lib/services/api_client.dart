import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:lemonade_controller/models/lemonade_load_options.dart';
import 'package:lemonade_controller/models/lemonade_unload_options.dart';
import 'package:lemonade_controller/models/loaded_model.dart';
import 'package:lemonade_controller/models/pull_progress_event.dart';
import 'package:lemonade_controller/models/pull_request_options.dart';
import 'package:lemonade_controller/utils/logger.dart';

final logger = createLogger("api_client");

class LemonadeApiClient {
  final Dio _dio = Dio();
  final String baseUrl;

  LemonadeApiClient({required this.baseUrl});

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

  Future<bool> loadModel(LemonadeLoadOptionsModel options) async {
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

  Future<bool> deleteModel(String modelName) async {
    logger.i('Sending command to delete $modelName');
    try {
      final response = await _dio.post(
        '$baseUrl/delete',
        data: {'model_name': modelName},
      );
      final status = response.data['status'];
      if (status == 'error') {
        throw Exception(response.data['message'] ?? 'Delete failed');
      }
      return response.statusCode == 200;
    } on DioException catch (e) {
      logger.e('Failed to delete model', error: e, stackTrace: e.stackTrace);
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to delete model: $message');
    }
  }

  Stream<PullProgressEvent> pullModel(PullRequestOptions options) async* {
    logger.i('Pulling model ${options.modelName}');
    try {
      final response = await _dio.post<ResponseBody>(
        '$baseUrl/pull',
        data: options.toJson(),
        options: Options(responseType: ResponseType.stream),
      );

      String buffer = '';
      String currentEvent = 'progress';

      final stream = response.data!.stream.cast<List<int>>();
      await for (final chunk in stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.last;

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          if (line.startsWith('event:')) {
            currentEvent = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            final jsonStr = line.substring(5).trim();
            if (jsonStr.isEmpty) continue;
            try {
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              yield PullProgressEvent.fromSse(currentEvent, data);
            } catch (e) {
              logger.w('Failed to parse SSE data: $jsonStr');
            }
          }
        }
      }

      if (buffer.trim().isNotEmpty) {
        final line = buffer.trim();
        if (line.startsWith('data:')) {
          final jsonStr = line.substring(5).trim();
          if (jsonStr.isNotEmpty) {
            try {
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              yield PullProgressEvent.fromSse(currentEvent, data);
            } catch (_) {}
          }
        }
      }
    } catch (e, stackTrace) {
      logger.e('Failed to pull model', error: e, stackTrace: stackTrace);
      yield PullProgressEvent(
        eventType: PullEventType.error,
        errorMessage: 'Failed to pull model: $e',
      );
    }
  }

  Future<List<LoadedModel>> getLoadedModels() async {
    final health = await getHealth();
    final models = health['all_models_loaded'] as List;
    return models.map((json) => LoadedModel.fromJson(json)).toList();
  }
}

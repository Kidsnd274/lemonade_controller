import 'package:dio/dio.dart';
import 'package:lemonade_controller/models/api_error.dart';
import 'package:lemonade_controller/models/download_job.dart';
import 'package:lemonade_controller/models/lemonade_load_options.dart';
import 'package:lemonade_controller/models/lemonade_unload_options.dart';
import 'package:lemonade_controller/models/loaded_model.dart';
import 'package:lemonade_controller/models/model_files.dart';
import 'package:lemonade_controller/models/pull_request_options.dart';
import 'package:lemonade_controller/models/pull_variants.dart';
import 'package:lemonade_controller/models/request_stats.dart';
import 'package:lemonade_controller/models/server_profile.dart';
import 'package:lemonade_controller/models/system_stats.dart';
import 'package:lemonade_controller/utils/logger.dart';

final logger = createLogger('api_client');

class LemonadeApiClient {
  final Dio _dio;
  final String baseUrl;

  LemonadeApiClient({
    required this.baseUrl,
    Dio? dio,
    Map<String, String> headers = const {},
  }) : _dio = dio ?? Dio() {
    _dio.options.headers.addAll(headers);
  }

  factory LemonadeApiClient.forProfile(ServerProfile profile, {Dio? dio}) {
    final headers = <String, String>{};
    for (final entry in profile.customHeaders.entries) {
      final existing = headers.keys.where(
        (key) => key.toLowerCase() == entry.key.toLowerCase(),
      );
      if (existing.isNotEmpty) headers.remove(existing.first);
      headers[entry.key] = entry.value;
    }
    if (profile.bearerToken?.trim().isNotEmpty == true) {
      headers.removeWhere((key, _) => key.toLowerCase() == 'authorization');
      headers['Authorization'] = 'Bearer ${profile.bearerToken!.trim()}';
    }
    return LemonadeApiClient(
      baseUrl: profile.baseUrl.replaceAll(RegExp(r'/$'), ''),
      dio: dio,
      headers: headers,
    );
  }

  Future<Map<String, dynamic>> getSystemInfo() => _getMap('/system-info');
  Future<Map<String, dynamic>> getHealth() => _getMap('/health');

  Future<List<dynamic>> getModelsList() async {
    final response = await _request(
      () => _dio.get('$baseUrl/models'),
      'load models',
    );
    final data = (response.data as Map?)?['data'] as List? ?? const [];
    return data.cast<dynamic>();
  }

  Future<SystemStats> getSystemStats() async =>
      SystemStats.fromJson(await _getMap('/system-stats'));

  Future<RequestStats> getRequestStats() async =>
      RequestStats.fromJson(await _getMap('/stats'));

  Future<ModelFiles> getModelFiles(String modelId) async {
    final encoded = Uri.encodeComponent(modelId);
    return ModelFiles.fromJson(await _getMap('/models/$encoded/files'));
  }

  Future<List<DownloadJob>> getDownloads() async {
    final response = await _request(
      () => _dio.get('$baseUrl/downloads'),
      'load downloads',
    );
    return (response.data as List? ?? const [])
        .map(
          (item) => DownloadJob.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<DownloadJob?> controlDownload(String id, String action) async {
    final response = await _request(
      () => _dio.post(
        '$baseUrl/downloads/control',
        data: {'id': id, 'action': action},
      ),
      '$action download',
    );
    if (action == 'remove') return null;
    return DownloadJob.fromJson((response.data as Map).cast<String, dynamic>());
  }

  Future<DownloadJob> startPull(PullRequestOptions options) async {
    final response = await _request(
      () => _dio.post('$baseUrl/pull', data: options.toJson()),
      'start model download',
    );
    return DownloadJob.fromJson((response.data as Map).cast<String, dynamic>());
  }

  Future<DownloadJob> resumePull(String modelName) async {
    final response = await _request(
      () => _dio.post(
        '$baseUrl/pull',
        data: {'model_name': modelName, 'stream': true, 'subscribe': false},
      ),
      'resume model download',
    );
    return DownloadJob.fromJson((response.data as Map).cast<String, dynamic>());
  }

  Future<PullVariants> getPullVariants(String checkpoint) async {
    final response = await _request(
      () => _dio.get(
        '$baseUrl/pull/variants',
        queryParameters: {'checkpoint': checkpoint},
      ),
      'load pull variants',
    );
    return PullVariants.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }

  Future<bool> loadModel(LemonadeLoadOptionsModel options) async {
    await _request(
      () => _dio.post('$baseUrl/load', data: options.toJson()),
      'load ${options.modelName}',
    );
    return true;
  }

  Future<bool> unloadModel(LemonadeUnloadOptionsModel options) async {
    await _request(
      () => _dio.post('$baseUrl/unload', data: options.toJson()),
      'unload ${options.modelName}',
    );
    return true;
  }

  Future<bool> deleteModel(String modelName) async {
    final response = await _request(
      () => _dio.post('$baseUrl/delete', data: {'model_name': modelName}),
      'delete $modelName',
    );
    final data = response.data;
    if (data is Map && data['status'] == 'error') {
      throw LemonadeApiException(
        data['message']?.toString() ?? 'Delete failed',
        statusCode: response.statusCode,
      );
    }
    return true;
  }

  Future<List<LoadedModel>> getLoadedModels() async {
    final health = await getHealth();
    final models = health['all_models_loaded'] as List? ?? const [];
    return models
        .map(
          (json) => LoadedModel.fromJson((json as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final response = await _request(
      () => _dio.get('$baseUrl$path'),
      'load ${path.substring(1)}',
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() request,
    String operation,
  ) async {
    logger.i('Lemonade API: $operation');
    try {
      return await request();
    } on DioException catch (error, stackTrace) {
      final exception = _toApiException(error, operation);
      logger.e(
        'Lemonade API failed: $operation (${exception.statusCode ?? 'network'})',
        error: exception.message,
        stackTrace: stackTrace,
      );
      throw exception;
    } catch (error, stackTrace) {
      logger.e(
        'Lemonade API failed: $operation',
        error: error,
        stackTrace: stackTrace,
      );
      if (error is LemonadeApiException) rethrow;
      throw LemonadeApiException('Failed to $operation');
    }
  }

  LemonadeApiException _toApiException(DioException error, String operation) {
    final response = error.response;
    final data = response?.data;
    String? code;
    String? message;
    if (data is Map) {
      final nested = data['error'];
      if (nested is Map) {
        code = nested['code']?.toString() ?? nested['type']?.toString();
        message = nested['message']?.toString();
      } else {
        code = data['code']?.toString();
        message = data['message']?.toString() ?? data['error']?.toString();
      }
    }
    final status = response?.statusCode;
    message ??= switch (status) {
      401 => 'Authentication required. Check this server profile token.',
      403 => 'This credential is not allowed to perform that action.',
      404 || 405 => 'Not supported by this server version.',
      409 when code == 'slots_pinned_error' =>
        'All model slots are pinned. Unload a pinned model or load without pinning.',
      _ => error.message ?? 'Failed to $operation',
    };
    return LemonadeApiException(message, statusCode: status, code: code);
  }
}

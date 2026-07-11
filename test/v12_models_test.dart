import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/download_job.dart';
import 'package:lemonade_controller/models/health_info.dart';
import 'package:lemonade_controller/models/lemonade_load_options.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/models/pull_request_options.dart';
import 'package:lemonade_controller/models/server_profile.dart';
import 'package:lemonade_controller/models/system_stats.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/providers/service_providers.dart';

void main() {
  group('Lemonade Server 10.10 response models', () {
    test('parses nullable system telemetry without turning null into zero', () {
      final stats = SystemStats.fromJson({
        'cpu_percent': 12.3,
        'memory_gb': 8.4,
        'gpu_percent': null,
        'vram_gb': null,
        'npu_percent': 9,
      });

      expect(stats.cpuPercent, 12.3);
      expect(stats.memoryGb, 8.4);
      expect(stats.gpuPercent, isNull);
      expect(stats.vramGb, isNull);
      expect(stats.npuPercent, 9);
    });

    test('parses pinned models and fractional last_use', () {
      final health = HealthInfo.fromJson({
        'status': 'ok',
        'version': '10.10.0',
        'all_models_loaded': [
          {
            'model_name': 'Qwen',
            'last_use': 1732123456.789,
            'pinned': true,
            'pid': 123,
            'type': 'llm',
          },
        ],
        'pinned_models': {'llm': 1},
        'max_models': {'llm': -1},
        'update_check_done': true,
      });

      expect(health.allModelsLoaded.single.lastUse, 1732123456.789);
      expect(health.allModelsLoaded.single.pinned, isTrue);
      expect(health.allModelsLoaded.single.pid, 123);
      expect(health.pinnedModels['llm'], 1);
      expect(health.maxModels['llm'], -1);
      expect(health.updateCheckDone, isTrue);
      expect(health.isOlderThanRecommended, isFalse);
    });

    test('recognizes an older server only as a warning condition', () {
      final health = HealthInfo.fromJson({'status': 'ok', 'version': '10.6.0'});
      expect(health.isOlderThanRecommended, isTrue);
      expect(health.isHealthy, isTrue);
    });

    test('parses server-owned download snapshots', () {
      final job = DownloadJob.fromJson({
        'id': 'model:Qwen',
        'type': 'model',
        'model_name': 'Qwen',
        'status': 'downloading',
        'running': true,
        'file_index': 1,
        'total_files': 2,
        'bytes_downloaded': 50,
        'bytes_total': 100,
        'total_download_size': 200,
        'cumulative_bytes_downloaded': 90,
        'percent': 50,
      });

      expect(job.status, DownloadStatus.downloading);
      expect(job.canPause, isTrue);
      expect(job.cumulativeBytesDownloaded, 90);
      expect(job.canResume, isFalse);
    });

    test('starts pulls as detached server-owned download jobs', () {
      final json = const PullRequestOptions(
        modelName: 'user.Qwen',
        checkpoint: 'org/Qwen-GGUF:Q4_K_M',
        recipe: 'llamacpp',
      ).toJson();

      expect(json['stream'], isTrue);
      expect(json['subscribe'], isFalse);
    });

    test('scopes fast download polling to the Pull page container', () {
      final root = ProviderContainer(
        overrides: [appForegroundProvider.overrideWith((ref) => false)],
      );
      addTearDown(root.dispose);
      final pullPage = ProviderContainer(
        parent: root,
        overrides: [
          downloadsPollingIntervalProvider.overrideWithValue(
            const Duration(milliseconds: 500),
          ),
        ],
      );
      addTearDown(pullPage.dispose);

      expect(
        pullPage.read(downloadsProvider.notifier).activePollingInterval,
        const Duration(milliseconds: 500),
      );
      expect(
        root.read(downloadsProvider.notifier).activePollingInterval,
        const Duration(seconds: 2),
      );
    });

    test('persists credentials and WebSocket override in profiles', () {
      final profile = ServerProfile(
        id: 'remote',
        name: 'Remote',
        baseUrl: 'https://example.test/api/v1',
        bearerToken: 'secret',
        customHeaders: {'X-Proxy-Key': 'proxy-secret'},
        webSocketUrlOverride: 'wss://example.test/logs/stream',
      );
      final decoded = ServerProfile.decodeList(
        ServerProfile.encodeList([profile]),
      );

      expect(decoded.single, profile);
      expect(decoded.single.customHeaders['X-Proxy-Key'], 'proxy-secret');
      expect(decoded.single.webSocketUrlOverride, contains('wss://'));
    });

    test('serializes advanced load options and model update fields', () {
      final options = LemonadeLoadOptionsModel(
        modelName: 'Qwen',
        ctxSize: -1,
        pinned: true,
        autoEvict: true,
        downsizeIdleTimeout: 60,
        evictIdleTimeout: 300,
        evictWeightFactor: 1.5,
        cfgScale: 7.0,
      );
      final model = LemonadeModel.fromJson({
        'id': 'Qwen',
        'owned_by': 'lemonade',
        'update_available': true,
        'max_context_window': 32768,
      });

      expect(options.toJson()['ctx_size'], -1);
      expect(options.toJson()['pinned'], isTrue);
      expect(options.toJson()['evict_weight_factor'], 1.5);
      expect(model.ownedBy, 'lemonade');
      expect(model.updateAvailable, isTrue);
      expect(model.maxContextWindow, 32768);
    });
  });
}

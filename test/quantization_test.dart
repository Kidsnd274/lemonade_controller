import 'package:flutter_test/flutter_test.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/utils/quantization.dart';
import 'package:lemonade_controller/utils/vram_estimator.dart';

void main() {
  group('extractQuantization', () {
    const cases = <String, String>{
      'unsloth/GLM-4.5-Air-GGUF:UD-Q5_K_XL': 'UD-Q5_K_XL',
      'paperscarecrow/Gemma-4:Q4_K_M': 'Q4_K_M',
      'Abiray/Huihui-Qwen-GGUF:Q6_K': 'Q6_K',
      'unsloth/Llama-GGUF:Llama-UD-Q4_K_XL.gguf': 'UD-Q4_K_XL',
      'unsloth/MiniMax-GGUF:UD-IQ3_S': 'UD-IQ3_S',
      'pqnet/bge-reranker-v2-m3-Q8_0-GGUF': 'Q8_0',
      'owner/model:model-q4_k_l.gguf': 'Q4_K_L',
      'owner/model:bf16': 'BF16',
    };

    for (final entry in cases.entries) {
      test('extracts ${entry.value}', () {
        expect(extractQuantization(entry.key), entry.value);
      });
    }

    test('uses the last valid bounded token', () {
      expect(extractQuantization('owner/Q4_0-model:UD-Q6_K_XL'), 'UD-Q6_K_XL');
    });

    test('does not guess from arbitrary model names', () {
      expect(extractQuantization('owner/Qwen3.5-Model-GGUF'), 'Unknown');
    });
  });

  test('LemonadeModel uses the shared extractor', () {
    final model = LemonadeModel.fromJson({
      'id': 'Llama-3.2-3B-Instruct-GGUF',
      'checkpoint':
          'unsloth/Llama-3.2-3B-Instruct-GGUF:'
          'Llama-3.2-3B-Instruct-UD-Q4_K_XL.gguf',
    });

    expect(model.quantization, 'UD-Q4_K_XL');
    expect(model.quantizationLevel, 4);
  });

  test('VRAM estimation accepts quantization embedded in a filename', () {
    final estimate = estimateVramFromModelName(
      'unsloth/Llama-3.2-3B-Instruct-GGUF:'
      'Llama-3.2-3B-Instruct-UD-Q4_K_XL.gguf',
    );

    expect(estimate, isNotNull);
  });
}

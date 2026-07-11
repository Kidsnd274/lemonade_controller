class RequestStats {
  final double? timeToFirstToken;
  final double? tokensPerSecond;
  final int? inputTokens;
  final int? outputTokens;
  final int? promptTokens;

  const RequestStats({
    this.timeToFirstToken,
    this.tokensPerSecond,
    this.inputTokens,
    this.outputTokens,
    this.promptTokens,
  });

  factory RequestStats.fromJson(Map<String, dynamic> json) => RequestStats(
    timeToFirstToken: (json['time_to_first_token'] as num?)?.toDouble(),
    tokensPerSecond: (json['tokens_per_second'] as num?)?.toDouble(),
    inputTokens: (json['input_tokens'] as num?)?.toInt(),
    outputTokens: (json['output_tokens'] as num?)?.toInt(),
    promptTokens: (json['prompt_tokens'] as num?)?.toInt(),
  );

  bool get isEmpty =>
      timeToFirstToken == null &&
      tokensPerSecond == null &&
      inputTokens == null &&
      outputTokens == null &&
      promptTokens == null;
}

class PullRequestOptions {
  final String modelName;
  final String checkpoint;
  final String recipe;
  final bool reasoning;
  final bool vision;
  final bool embedding;
  final bool reranking;
  final String? mmproj;

  const PullRequestOptions({
    required this.modelName,
    required this.checkpoint,
    required this.recipe,
    this.reasoning = false,
    this.vision = false,
    this.embedding = false,
    this.reranking = false,
    this.mmproj,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'model_name': modelName,
      'checkpoint': checkpoint,
      'recipe': recipe,
      'stream': true,
    };
    if (reasoning) json['reasoning'] = true;
    if (vision) json['vision'] = true;
    if (embedding) json['embedding'] = true;
    if (reranking) json['reranking'] = true;
    if (mmproj != null && mmproj!.isNotEmpty) json['mmproj'] = mmproj;
    return json;
  }
}

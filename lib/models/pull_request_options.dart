class PullRequestOptions {
  final String modelName;
  final String checkpoint;
  final String recipe;
  final bool? reasoning;
  final bool? vision;
  final bool? embedding;
  final bool? reranking;
  final String? mmproj;

  const PullRequestOptions({
    required this.modelName,
    required this.checkpoint,
    required this.recipe,
    this.reasoning,
    this.vision,
    this.embedding,
    this.reranking,
    this.mmproj,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'model_name': modelName,
      'checkpoint': checkpoint,
      'recipe': recipe,
      'stream': true,
    };
    if (reasoning != null) json['reasoning'] = reasoning;
    if (vision != null) json['vision'] = vision;
    if (embedding != null) json['embedding'] = embedding;
    if (reranking != null) json['reranking'] = reranking;
    if (mmproj != null && mmproj!.isNotEmpty) json['mmproj'] = mmproj;
    return json;
  }
}

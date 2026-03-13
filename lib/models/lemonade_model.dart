class LemonadeModel {
    final String id;
    final String checkpoint;
    final bool downloaded;
    final List<String> labels;
    final String recipe;
    final Map<String, dynamic> recipeOptions;
    final bool suggested;
    final String ownedBy;

    // Derived properties
    String get displayName => id.replaceFirst('user.', '')
    String get quantization => checkpoint.split(":").length > 1
        ? checkpoint.split(':').last
        : 'Unknown';
    bool get isUserModel => id.startsWith('user.');
}
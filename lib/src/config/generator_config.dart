/// Configuration for the feature generator
class GeneratorConfig {
  final String projectRoot;
  final String swaggerFilePath;
  final String featuresPath;
  final List<String> restrictedNames;
  final bool useCleanArchitecture;
  
  const GeneratorConfig({
    required this.projectRoot,
    this.swaggerFilePath = 'swagger.json',
    this.featuresPath = 'lib/features',
    this.restrictedNames = const ['test', 'build', 'lib', 'android', 'ios', 'web', 'windows', 'linux', 'macos'],
    this.useCleanArchitecture = true,
  });
  
  /// Create config from a config file
  factory GeneratorConfig.fromFile(String configPath) {
    // TODO: Implement config file loading
    throw UnimplementedError('Config file loading not yet implemented');
  }
  
  /// Validate if a feature name is allowed
  bool isValidFeatureName(String name) {
    // Check if name is in restricted list
    if (restrictedNames.contains(name.toLowerCase())) {
      return false;
    }
    
    // Check if name follows snake_case convention
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      return false;
    }
    
    return true;
  }
  
  /// Get the full path for a feature
  String getFeaturePath(String featureName) {
    return '$projectRoot/$featuresPath/$featureName';
  }
  
  /// Get the full path for swagger file
  String getSwaggerPath() {
    return '$projectRoot/$swaggerFilePath';
  }
}

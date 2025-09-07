import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

// Import templates
import 'templates/shared.dart';
import 'templates/model_template.dart';
import 'templates/service_template.dart';
import 'templates/source_template.dart';
import 'templates/repository_template.dart';
import 'templates/usecase_template.dart';
import 'templates/bloc_template.dart';
import 'templates/screen_template.dart';

class FeatureGenerator {
  late Map<String, dynamic> swaggerSpec;
  final String projectRoot;
  late String projectName;

  FeatureGenerator(this.projectRoot);

  /// Run the feature generator with command line arguments
  Future<void> run(List<String> arguments) async {
    print('🎯 Flutter Feature Generator');
    print('=' * 30);

    try {
      // Load swagger specification
      await loadSwaggerSpec();

      // Check if running with command line arguments
      if (arguments.isNotEmpty) {
        await _runNonInteractiveMode(arguments);
        return;
      }

      // Use hybrid mode: show options first, then guide user to use command line
      print('📋 Here are your options:');
      print('');
      
      await _showAvailableEndpoints();
      
      print('\n🚀 To generate a feature, use this format:');
      print('   dart bin/flutter_feature_generator.dart <feature_name> <endpoint_numbers>');
      print('');
      print('💡 Examples:');
      print('   dart bin/flutter_feature_generator.dart compliment 15');
      print('   dart bin/flutter_feature_generator.dart user_management 1,3,5');
      print('   dart bin/flutter_feature_generator.dart api_features all');
      print('');
      print('ℹ️  Feature name should be in snake_case (e.g., user_management, products, etc.)');
      
      return; // Exit here instead of hanging

    } catch (e) {
      print('❌ Error: $e');
      exit(1);
    }
  }

  /// Get the models folder path, checking for existing 'models' folder first
  String _getModelsFolderPath(String featureName) {
    final dataPath = path.join(projectRoot, 'lib', 'features', featureName, 'data');
    final modelsPath = path.join(dataPath, 'models');
    final modelPath = path.join(dataPath, 'model');
    
    // Check if 'models' (plural) folder exists
    if (Directory(modelsPath).existsSync()) {
      print('🔍 Found existing "models" folder, using: $modelsPath');
      return modelsPath;
    }
    
    // Default to 'model' (singular)
    return modelPath;
  }

  /// Get the model folder name for imports
  String _getModelFolderName(String featureName) {
    final dataPath = path.join(projectRoot, 'lib', 'features', featureName, 'data');
    final modelsPath = path.join(dataPath, 'models');
    
    // Check if 'models' (plural) folder exists
    if (Directory(modelsPath).existsSync()) {
      return 'models';
    }
    
    // Default to 'model' (singular)
    return 'model';
  }

  /// Get the model folder name for creation (always prefer 'model' unless 'models' exists)
  String _getModelFolderNameForCreation(String featureName) {
    final dataPath = path.join(projectRoot, 'lib', 'features', featureName, 'data');
    final modelsPath = path.join(dataPath, 'models');
    
    // Only use 'models' if it already exists
    if (Directory(modelsPath).existsSync()) {
      print('🔍 Using existing "models" folder');
      return 'models';
    }
    
    // Always create 'model' (singular) for new features
    return 'model';
  }

  /// Show available endpoints in a clean format
  Future<void> _showAvailableEndpoints() async {
    final allEndpoints = getAvailableEndpoints();

    print('🔍 Available API endpoints by category:');
    print('=' * 50);

    int index = 1;
    for (final tagEntry in allEndpoints.entries) {
      final tag = tagEntry.key;
      final endpoints = tagEntry.value;

      print('\n📁 $tag:');
      for (final endpoint in endpoints) {
        print('  $index. ${endpoint.method.toUpperCase()} ${endpoint.path}');
        if (endpoint.summary.isNotEmpty) {
          print('     📝 ${endpoint.summary}');
        }
        index++;
      }
    }
    print('\n' + '=' * 50);
  }

  /// Run in non-interactive mode using command line arguments
  Future<void> _runNonInteractiveMode(List<String> arguments) async {
    if (arguments.length < 2) {
      _printUsage();
      return;
    }

    final featureName = arguments[0];
    final endpointIndicesStr = arguments[1];

    print('📝 Feature name: $featureName');
    print('📝 Endpoint indices: $endpointIndicesStr');

    // Validate feature name
    if (!_isValidFeatureName(featureName)) {
      print('❌ Invalid feature name: $featureName');
      print('   Feature name should be in snake_case (e.g., user_management)');
      return;
    }

    // Get all available endpoints first
    final allEndpoints = getAvailableEndpoints();
    final indexToEndpoint = <int, ApiEndpoint>{};
    
    int index = 1;
    for (final tagEntry in allEndpoints.entries) {
      final endpoints = tagEntry.value;
      for (final endpoint in endpoints) {
        indexToEndpoint[index] = endpoint;
        index++;
      }
    }

    // Parse endpoint indices
    List<ApiEndpoint> selectedEndpoints = [];
    if (endpointIndicesStr.toLowerCase() == 'all') {
      selectedEndpoints.addAll(indexToEndpoint.values);
    } else {
      try {
        final indices = endpointIndicesStr
            .split(',')
            .map((s) => int.parse(s.trim()))
            .toList();
            
        for (final i in indices) {
          if (indexToEndpoint.containsKey(i)) {
            selectedEndpoints.add(indexToEndpoint[i]!);
          } else {
            print('⚠️ Warning: Invalid endpoint index $i (max: ${indexToEndpoint.length})');
          }
        }
      } catch (e) {
        print('❌ Invalid endpoint indices: $endpointIndicesStr');
        print('   Use comma-separated numbers (e.g., 1,3,5) or "all"');
        return;
      }
    }
    
    if (selectedEndpoints.isEmpty) {
      print('❌ No valid endpoints found for indices: $endpointIndicesStr');
      return;
    }

    print('\n✅ Selected ${selectedEndpoints.length} endpoints:');
    for (final endpoint in selectedEndpoints) {
      print('  • ${endpoint.method.toUpperCase()} ${endpoint.path}');
    }

    // Generate the feature
    await generateFeature(featureName, selectedEndpoints);
    
    print('\n🎉 Generation completed!');
    print('📋 Next steps:');
    print('  1. Run "flutter packages pub run build_runner build" to generate .g.dart files');
    print('  2. Add the repository to your DI container');
    print('  3. Import and use the generated BLoC in your screens');
  }

  /// Print usage instructions
  void _printUsage() {
    print('📖 Usage:');
    print('  Show endpoints:     dart bin/flutter_feature_generator.dart');
    print('  Generate feature:   dart bin/flutter_feature_generator.dart <feature_name> <endpoint_indices>');
    print('');
    print('💡 Examples:');
    print('  dart bin/flutter_feature_generator.dart user_management 1,3,5');
    print('  dart bin/flutter_feature_generator.dart products all');
    print('  dart bin/flutter_feature_generator.dart chat 15');
    print('');
    print('📋 Feature name should be in snake_case (e.g., user_management, products, etc.)');
  }

  /// Validate feature name format
  bool _isValidFeatureName(String featureName) {
    final restrictedNames = ['test', 'build', 'lib', 'android', 'ios', 'web', 'windows', 'linux', 'macos'];
    
    if (restrictedNames.contains(featureName.toLowerCase())) {
      return false;
    }
    
    return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(featureName);
  }

  /// Get a valid feature name with validation
  Future<String?> _getValidFeatureName() async {
    print('🔍 DEBUG: Entered _getValidFeatureName() method');
    stdout.flush();
    
    final restrictedNames = ['test', 'build', 'lib', 'android', 'ios', 'web', 'windows', 'linux', 'macos'];
    
    print('🔍 DEBUG: About to add delay...');
    stdout.flush();
    
    // Add a small delay to ensure previous output is processed
    await Future.delayed(Duration(milliseconds: 100));
    
    print('🔍 DEBUG: Delay completed, entering while loop...');
    stdout.flush();
    
    while (true) {
      print('🔍 DEBUG: Inside while loop, about to print prompt...');
      stdout.flush();
      
      print('\n📝 Enter the feature name (e.g., user_management, products, etc.):');
      stdout.flush();
      
      print('🔍 DEBUG: Prompt printed, about to call readLineSync...');
      stdout.flush();
      
      String? featureName;
      
      // Windows PowerShell fix: Add a small delay and try multiple times
      for (int attempt = 1; attempt <= 3; attempt++) {
        print('🔍 DEBUG: Input attempt $attempt...');
        stdout.flush();
        
        featureName = stdin.readLineSync()?.trim();
        
        if (featureName != null && featureName.isNotEmpty) {
          break; // Got valid input
        }
        
        print('🔍 DEBUG: Attempt $attempt returned null/empty, trying again...');
        await Future.delayed(Duration(milliseconds: 500)); // Short delay
      }
      
      // If still null after 3 attempts, try byte reading as fallback
      if (featureName == null || featureName.isEmpty) {
        print('🔍 DEBUG: All attempts failed, trying byte-by-byte reading...');
        stdout.flush();
        
        final buffer = <int>[];
        try {
          int consecutiveNewlines = 0;
          while (consecutiveNewlines < 2) { // Stop after 2 consecutive newlines
            final byte = stdin.readByteSync();
            if (byte == 10 || byte == 13) { // newline or carriage return
              consecutiveNewlines++;
              if (buffer.isNotEmpty) break; // Got some input, stop here
              continue;
            }
            consecutiveNewlines = 0;
            if (byte >= 32 && byte <= 126) { // Printable ASCII characters only
              buffer.add(byte);
            }
          }
          if (buffer.isNotEmpty) {
            featureName = String.fromCharCodes(buffer).trim();
          }
        } catch (e) {
          print('🔍 DEBUG: Byte reading failed: $e');
          // Last resort: ask user to restart script
          print('❌ Input system not working properly. Please restart the script.');
          return null;
        }
      }
      
      print('🔍 DEBUG: readLineSync completed');
      stdout.flush();
      
      print('📝 Received feature name: "$featureName"');
      stdout.flush();
      
      print('🔍 DEBUG: Checking if featureName is null or empty...');
      stdout.flush();
      
      if (featureName == null || featureName.isEmpty) {
        print('❌ Feature name is required');
        print('🔍 DEBUG: Feature name was null/empty, continuing loop...');
        stdout.flush();
        continue;
      }
      
      print('🔍 DEBUG: Validating feature name against restricted names...');
      stdout.flush();
      
      // Validate feature name
      if (restrictedNames.contains(featureName.toLowerCase())) {
        print('❌ "$featureName" is a restricted name. Please choose a different name.');
        print('🔍 DEBUG: Feature name was restricted, continuing loop...');
        stdout.flush();
        continue;
      }
      
      print('🔍 DEBUG: Checking regex pattern...');
      stdout.flush();
      
      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(featureName)) {
        print('❌ Feature name should be in snake_case (e.g., user_management)');
        print('🔍 DEBUG: Feature name failed regex, continuing loop...');
        stdout.flush();
        continue;
      }
      
      print('🔍 DEBUG: Feature name validation passed, returning: "$featureName"');
      stdout.flush();
      
      return featureName;
    }
  }

  /// Load and parse the swagger.json file
  Future<void> loadSwaggerSpec() async {
    // First, detect the project name
    await _detectProjectName();
    
    final swaggerFile = File(path.join(projectRoot, 'swagger.json'));
    if (!await swaggerFile.exists()) {
      throw Exception('swagger.json not found in project root');
    }
    
    final content = await swaggerFile.readAsString();
    swaggerSpec = json.decode(content);
    print('✅ Swagger specification loaded successfully');
    
    // Ensure core error class exists
    await _ensureErrorClassExists();
  }

  /// Detect the project name from pubspec.yaml
  Future<void> _detectProjectName() async {
    final pubspecFile = File(path.join(projectRoot, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      throw Exception('pubspec.yaml not found in project root. Make sure you\'re running this from a Flutter project directory.');
    }
    
    final content = await pubspecFile.readAsString();
    final lines = content.split('\n');
    
    for (final line in lines) {
      if (line.trim().startsWith('name:')) {
        projectName = line.split(':')[1].trim();
        print('📦 Detected project name: $projectName');
        return;
      }
    }
    
    throw Exception('Could not find project name in pubspec.yaml');
  }

  /// Ensure the core Error class exists in the project
  Future<void> _ensureErrorClassExists() async {
    final errorPath = path.join(projectRoot, 'lib', 'core', 'error', 'error.dart');
    final errorFile = File(errorPath);
    
    if (!await errorFile.exists()) {
      print('📝 Creating core Error class...');
      
      // Create core/error directory if it doesn't exist
      await Directory(path.dirname(errorPath)).create(recursive: true);
      
      // Generate the error class
      final errorContent = '''import 'package:freezed_annotation/freezed_annotation.dart';

part 'error.freezed.dart';

@freezed
class Error with _\$Error {
  const factory Error.httpInternalServerError(String errorBody) =
      HttpInternalServerError;

  const factory Error.httpUnAuthorizedError() = HttpUnAuthorizedError;

  const factory Error.httpUnknownError(String message) = HttpUnknownError;

  const factory Error.firebaseAuthError(String message) = FirebaseAuthError;

  const factory Error.auth0AuthError(String message) = Auth0AuthError;

  const factory Error.customErrorType(String message) = CustomErrorType;

  const factory Error.fileNotFoundError(String filePath) = FileNotFoundError;
  
  const factory Error.decryptionFailed(String message) = DecryptionFailedError;
  
  const factory Error.fileAlreadyExists(String filePath) =
      FileAlreadyExistsError;
  
  const factory Error.none() = NoError;
}
''';
      
      await errorFile.writeAsString(errorContent);
      print('✅ Core Error class created at lib/core/error/error.dart');
    } else {
      print('✅ Core Error class already exists');
    }
  }

  /// Get all available API endpoints grouped by tags
  Map<String, List<ApiEndpoint>> getAvailableEndpoints() {
    final Map<String, List<ApiEndpoint>> taggedEndpoints = {};
    final paths = swaggerSpec['paths'] as Map<String, dynamic>;

    for (final pathEntry in paths.entries) {
      final pathUrl = pathEntry.key;
      final pathData = pathEntry.value as Map<String, dynamic>;

      for (final methodEntry in pathData.entries) {
        final method = methodEntry.key.toLowerCase();
        if (!['get', 'post', 'put', 'delete', 'patch'].contains(method)) continue;

        final methodData = methodEntry.value as Map<String, dynamic>;
        final tags = (methodData['tags'] as List?)?.cast<String>() ?? ['default'];
        final summary = methodData['summary'] as String? ?? '';
        
        final endpoint = ApiEndpoint(
          path: pathUrl,
          method: method,
          summary: summary,
          operationId: methodData['operationId'] as String?,
          parameters: _extractParameters(methodData),
          requestBody: _extractRequestBody(methodData),
          responses: _extractResponses(methodData),
        );

        for (final tag in tags) {
          taggedEndpoints.putIfAbsent(tag, () => []).add(endpoint);
        }
      }
    }

    return taggedEndpoints;
  }

  /// Display available endpoints and let user choose
  Future<List<ApiEndpoint>> selectEndpointsInteractively() async {
    final allEndpoints = getAvailableEndpoints();
    final selectedEndpoints = <ApiEndpoint>[];

    print('\n🔍 Available API endpoints by category:');
    print('=' * 50);

    int index = 1;
    final indexToEndpoint = <int, ApiEndpoint>{};

    for (final tagEntry in allEndpoints.entries) {
      final tag = tagEntry.key;
      final endpoints = tagEntry.value;

      print('\n📁 $tag:');
      for (final endpoint in endpoints) {
        print('  $index. ${endpoint.method.toUpperCase()} ${endpoint.path}');
        if (endpoint.summary.isNotEmpty) {
          print('     📝 ${endpoint.summary}');
        }
        indexToEndpoint[index] = endpoint;
        index++;
      }
    }

    print('\n' + '=' * 50);
    print('Enter the numbers of endpoints you want to generate (comma-separated):');
    print('Example: 1,3,5 or "all" for all endpoints');
    
    // Flush output to ensure prompt is displayed
    stdout.flush();
    
    final input = stdin.readLineSync()?.trim();
    
    // Debug: Print what was received
    print('📝 Received input: "$input"');
    
    if (input == null || input.isEmpty) {
      print('❌ No selection made');
      return [];
    }

    if (input.toLowerCase() == 'all') {
      selectedEndpoints.addAll(indexToEndpoint.values);
    } else {
      final selectedIndices = input.split(',')
          .map((s) => int.tryParse(s.trim()))
          .where((i) => i != null && indexToEndpoint.containsKey(i))
          .cast<int>();

      for (final i in selectedIndices) {
        selectedEndpoints.add(indexToEndpoint[i]!);
      }
    }

    if (selectedEndpoints.isEmpty) {
      print('❌ No valid endpoints selected');
      return [];
    }

    print('\n✅ Selected ${selectedEndpoints.length} endpoints:');
    for (final endpoint in selectedEndpoints) {
      print('  • ${endpoint.method.toUpperCase()} ${endpoint.path}');
    }

    // Clear any remaining input buffer
    stdout.flush();
    
    return selectedEndpoints;
  }

  /// Generate feature for selected endpoints with layer selection
  Future<void> generateFeatureWithLayers(String featureName, List<dynamic> endpoints, Map<String, dynamic> layers, {bool append = false}) async {
    // Convert dynamic endpoints to ApiEndpoint
    final apiEndpoints = endpoints.cast<ApiEndpoint>();
    
    if (append) {
      print('\n🔄 Updating existing feature: $featureName');
      await _appendToFeatureWithLayers(featureName, apiEndpoints, layers);
    } else {
      print('\n🚀 Generating new feature: $featureName');
      await _generateCompleteFeatureWithLayers(featureName, apiEndpoints, layers);
    }
    
    print('✅ Feature "$featureName" completed successfully!');
    print('📁 Location: lib/features/$featureName/');
  }

  /// Generate feature for selected endpoints (legacy method for CLI)
  Future<void> generateFeature(String featureName, List<ApiEndpoint> endpoints) async {
    final featurePath = path.join(projectRoot, 'lib', 'features', featureName);
    final featureExists = await Directory(featurePath).exists();
    
    if (featureExists) {
      print('\n📁 Feature "$featureName" already exists!');
      print('🔧 Choose an option:');
      print('  1. Append new APIs to existing feature');
      print('  2. Overwrite entire feature');
      print('  3. Cancel generation');
      
      stdout.flush();
      final choice = stdin.readLineSync()?.trim();
      print('📝 Received choice: "$choice"');
      
      switch (choice) {
        case '1':
          print('\n🔄 Appending to existing feature: $featureName');
          await _appendToFeature(featureName, endpoints);
          break;
        case '2':
          print('\n🚀 Overwriting feature: $featureName');
          await _generateCompleteFeature(featureName, endpoints);
          break;
        case '3':
        default:
          print('❌ Generation cancelled');
          return;
      }
    } else {
      print('\n🚀 Generating new feature: $featureName');
      await _generateCompleteFeature(featureName, endpoints);
    }
    
    print('✅ Feature "$featureName" updated successfully!');
    print('📁 Location: lib/features/$featureName/');
  }

  /// Generate a complete new feature with layer selection
  Future<void> _generateCompleteFeatureWithLayers(String featureName, List<ApiEndpoint> endpoints, Map<String, dynamic> layers) async {
    // Create folder structure based on selected layers
    await _createFolderStructureWithLayers(featureName, layers);
    
    // Generate selected layers
    if (layers['data'] == true) {
      await _generateDataLayer(featureName, endpoints);
      print('📦 Data layer generated');
    }
    
    if (layers['domain'] == true) {
      await _generateDomainLayer(featureName, endpoints);
      print('🏛️ Domain layer generated');
    }
    
    if (layers['presentation'] == true) {
      await _generatePresentationLayerWithComponents(featureName, endpoints, layers);
      print('🎨 Presentation layer generated');
    }
  }

  /// Append to existing feature with layer selection
  Future<void> _appendToFeatureWithLayers(String featureName, List<ApiEndpoint> endpoints, Map<String, dynamic> layers) async {
    // Extract existing endpoints from current service file
    final existingEndpoints = await _extractExistingEndpoints(featureName);
    
    // Filter out endpoints that already exist
    final newEndpoints = endpoints.where((endpoint) {
      return !existingEndpoints.any((existing) => 
        existing.path == endpoint.path && existing.method == endpoint.method);
    }).toList();
    
    if (newEndpoints.isEmpty) {
      print('⚠️ All selected endpoints already exist in this feature');
      return;
    }
    
    print('📋 Adding ${newEndpoints.length} new endpoints:');
    for (final endpoint in newEndpoints) {
      print('  • ${endpoint.method.toUpperCase()} ${endpoint.path}');
    }
    
    // Ensure folder structure exists for selected layers
    await _createFolderStructureWithLayers(featureName, layers);
    
    // Update selected layers
    if (layers['data'] == true) {
      await _appendModels(featureName, newEndpoints);
      await _appendToService(featureName, newEndpoints);
      await _appendToSource(featureName, newEndpoints);
      await _appendToRepository(featureName, newEndpoints);
      print('🔄 Updated data layer');
    }
    
    if (layers['domain'] == true) {
      await _appendToUseCases(featureName, newEndpoints);
      // Also regenerate repository interface if needed
      if (layers['data'] != true) {
        await _generateRepositoryInterface(featureName, newEndpoints);
      }
      print('🔄 Updated domain layer');
    }
    
    if (layers['presentation'] == true) {
      await _appendToPresentationLayerWithComponents(featureName, newEndpoints, layers);
      print('🔄 Updated presentation layer');
    }
    
    print('🔄 Updated all selected layers with new endpoints');
  }

  /// Generate a complete new feature (legacy method for CLI)
  Future<void> _generateCompleteFeature(String featureName, List<ApiEndpoint> endpoints) async {
    // Create folder structure
    await _createFolderStructure(featureName);
    
    // Generate data layer
    await _generateDataLayer(featureName, endpoints);
    
    // Generate domain layer
    await _generateDomainLayer(featureName, endpoints);
    
    // Generate presentation layer
    await _generatePresentationLayer(featureName, endpoints);
  }

  /// Append new APIs to an existing feature
  Future<void> _appendToFeature(String featureName, List<ApiEndpoint> endpoints) async {
    // Extract existing endpoints from current service file
    final existingEndpoints = await _extractExistingEndpoints(featureName);
    
    // Filter out endpoints that already exist
    final newEndpoints = endpoints.where((endpoint) {
      return !existingEndpoints.any((existing) => 
        existing.path == endpoint.path && existing.method == endpoint.method);
    }).toList();
    
    if (newEndpoints.isEmpty) {
      print('⚠️ All selected endpoints already exist in this feature');
      return;
    }
    
    print('📋 Adding ${newEndpoints.length} new endpoints:');
    for (final endpoint in newEndpoints) {
      print('  • ${endpoint.method.toUpperCase()} ${endpoint.path}');
    }
    
    // Generate models for new endpoints only
    await _appendModels(featureName, newEndpoints);
    
    // Update service with new methods
    await _appendToService(featureName, newEndpoints);
    
    // Update source with new methods
    await _appendToSource(featureName, newEndpoints);
    
    // Update repository with new methods  
    await _appendToRepository(featureName, newEndpoints);
    
    // Update use cases with new methods
    await _appendToUseCases(featureName, newEndpoints);
    
    // Update BLoC with new events and states
    await _appendToBloc(featureName, newEndpoints);
    
    print('🔄 Updated all layers with new endpoints');
  }

  /// Create the folder structure with layer selection
  Future<void> _createFolderStructureWithLayers(String featureName, Map<String, dynamic> layers) async {
    final basePath = path.join(projectRoot, 'lib', 'features', featureName);
    
    // Determine which model folder to use
    final modelFolderName = _getModelFolderNameForCreation(featureName);
    
    final folders = <String>[];
    
    // Data layer folders
    if (layers['data'] == true) {
      folders.addAll([
        '$basePath/data/$modelFolderName',
        '$basePath/data/remote/service',
        '$basePath/data/remote/source',
        '$basePath/data/repository',
      ]);
    }
    
    // Domain layer folders
    if (layers['domain'] == true) {
      folders.addAll([
        '$basePath/domain/repository',
        '$basePath/domain/usecase',
      ]);
    }
    
    // Presentation layer folders
    if (layers['presentation'] == true) {
      final presentationComponents = layers['presentationComponents'] as Map<String, dynamic>? ?? {
        'bloc': true,
        'screens': true,
        'widgets': true,
      };
      
      if (presentationComponents['bloc'] == true) {
        folders.add('$basePath/presentation/bloc');
      }
      if (presentationComponents['screens'] == true) {
        folders.add('$basePath/presentation/screen');
      }
      if (presentationComponents['widgets'] == true) {
        folders.add('$basePath/presentation/widget');
      }
    }

    for (final folder in folders) {
      await Directory(folder).create(recursive: true);
    }
    
    print('📁 Folder structure created for selected layers');
  }

  /// Create the folder structure (legacy method for CLI)
  Future<void> _createFolderStructure(String featureName) async {
    final basePath = path.join(projectRoot, 'lib', 'features', featureName);
    
    // Determine which model folder to use
    final modelFolderName = _getModelFolderNameForCreation(featureName);
    
    final folders = [
      '$basePath/data/$modelFolderName',
      '$basePath/data/remote/service',
      '$basePath/data/remote/source',
      '$basePath/data/repository',
      '$basePath/domain/repository',
      '$basePath/domain/usecase',
      '$basePath/presentation/bloc',
      '$basePath/presentation/screen',
      '$basePath/presentation/widget',
    ];

    for (final folder in folders) {
      await Directory(folder).create(recursive: true);
    }
    
    print('📁 Folder structure created');
  }

  /// Generate data layer files
  Future<void> _generateDataLayer(String featureName, List<ApiEndpoint> endpoints) async {
    // Generate models
    await _generateModels(featureName, endpoints);
    
    // Generate service
    await _generateService(featureName, endpoints);
    
    // Generate source and source implementation
    await _generateSource(featureName, endpoints);
    
    // Generate repository implementation
    await _generateRepositoryImpl(featureName, endpoints);
    
    print('📦 Data layer generated');
  }

  /// Generate domain layer files
  Future<void> _generateDomainLayer(String featureName, List<ApiEndpoint> endpoints) async {
    // Generate repository interface
    await _generateRepositoryInterface(featureName, endpoints);
    
    // Generate use cases
    await _generateUseCases(featureName, endpoints);
    
    print('🏛️ Domain layer generated');
  }

  /// Generate presentation layer files with component selection
  Future<void> _generatePresentationLayerWithComponents(String featureName, List<ApiEndpoint> endpoints, Map<String, dynamic> layers) async {
    final presentationComponents = layers['presentationComponents'] as Map<String, dynamic>? ?? {
      'bloc': true,
      'screens': true,
      'widgets': true,
    };
    
    if (presentationComponents['bloc'] == true) {
      // Generate bloc, events, and states
      await _generateBloc(featureName, endpoints);
      print('  🎯 BLoC generated');
    }
    
    if (presentationComponents['screens'] == true) {
      // Generate basic screen
      await _generateScreen(featureName);
      print('  📱 Screens generated');
    }
    
    if (presentationComponents['widgets'] == true) {
      // Create widgets folder (no default widgets generated)
      final widgetsPath = path.join(projectRoot, 'lib', 'features', featureName, 'presentation', 'widget');
      await Directory(widgetsPath).create(recursive: true);
      print('  🧩 Widgets folder created');
    }
  }

  /// Append to presentation layer with component selection
  Future<void> _appendToPresentationLayerWithComponents(String featureName, List<ApiEndpoint> endpoints, Map<String, dynamic> layers) async {
    final presentationComponents = layers['presentationComponents'] as Map<String, dynamic>? ?? {
      'bloc': true,
      'screens': true,
      'widgets': true,
    };
    
    if (presentationComponents['bloc'] == true) {
      await _appendToBloc(featureName, endpoints);
      print('  🎯 BLoC updated');
    }
    
    if (presentationComponents['screens'] == true) {
      // Generate screen if it doesn't exist
      final screenPath = path.join(projectRoot, 'lib', 'features', featureName, 'presentation', 'screen', '${featureName}_screen.dart');
      if (!await File(screenPath).exists()) {
        await _generateScreen(featureName);
        print('  📱 Screen generated');
      } else {
        print('  📱 Screen already exists (no changes)');
      }
    }
    
    if (presentationComponents['widgets'] == true) {
      // Ensure widgets folder exists
      final widgetsPath = path.join(projectRoot, 'lib', 'features', featureName, 'presentation', 'widget');
      if (!await Directory(widgetsPath).exists()) {
        await Directory(widgetsPath).create(recursive: true);
        print('  🧩 Widgets folder created');
      } else {
        print('  🧩 Widgets folder already exists');
      }
    }
  }

  /// Generate presentation layer files (legacy method for CLI)
  Future<void> _generatePresentationLayer(String featureName, List<ApiEndpoint> endpoints) async {
    // Generate bloc, events, and states
    await _generateBloc(featureName, endpoints);
    
    // Generate basic screen
    await _generateScreen(featureName);
    
    print('🎨 Presentation layer generated');
  }

  // Helper methods for extracting data from swagger spec
  List<Parameter> _extractParameters(Map<String, dynamic> methodData) {
    final parameters = <Parameter>[];
    final paramsList = methodData['parameters'] as List?;
    
    if (paramsList != null) {
      for (final param in paramsList) {
        final paramMap = param as Map<String, dynamic>;
        parameters.add(Parameter(
          name: paramMap['name'] as String,
          location: paramMap['in'] as String,
          required: paramMap['required'] as bool? ?? false,
          type: _extractParameterType(paramMap['schema'] as Map<String, dynamic>?),
          description: paramMap['description'] as String?,
        ));
      }
    }
    
    return parameters;
  }

  String _extractParameterType(Map<String, dynamic>? schema) {
    if (schema == null) return 'String';
    
    final type = schema['type'] as String?;
    switch (type) {
      case 'integer':
        return 'int';
      case 'number':
        return 'double';
      case 'boolean':
        return 'bool';
      case 'array':
        return 'List<String>'; // Simplified
      default:
        return 'String';
    }
  }

  RequestBody? _extractRequestBody(Map<String, dynamic> methodData) {
    final requestBody = methodData['requestBody'] as Map<String, dynamic>?;
    if (requestBody == null) return null;
    
    final content = requestBody['content'] as Map<String, dynamic>?;
    final jsonContent = content?['application/json'] as Map<String, dynamic>?;
    final schema = jsonContent?['schema'] as Map<String, dynamic>?;
    
    Map<String, dynamic>? resolvedSchema;
    if (schema != null) {
      resolvedSchema = _resolveSchemaRef(schema);
    }
    
    return RequestBody(
      required: requestBody['required'] as bool? ?? false,
      schema: resolvedSchema,
    );
  }

  Map<String, ResponseDef> _extractResponses(Map<String, dynamic> methodData) {
    final responses = <String, ResponseDef>{};
    final responsesMap = methodData['responses'] as Map<String, dynamic>? ?? {};
    
    for (final entry in responsesMap.entries) {
      final statusCode = entry.key;
      final responseData = entry.value as Map<String, dynamic>;
      
      responses[statusCode] = ResponseDef(
        description: responseData['description'] as String? ?? '',
        schema: _extractResponseSchema(responseData),
      );
    }
    
    return responses;
  }

  Map<String, dynamic>? _extractResponseSchema(Map<String, dynamic> responseData) {
    final content = responseData['content'] as Map<String, dynamic>?;
    final jsonContent = content?['application/json'] as Map<String, dynamic>?;
    final schema = jsonContent?['schema'] as Map<String, dynamic>?;
    
    if (schema != null) {
      return _resolveSchemaRef(schema);
    }
    
    return null;
  }

  /// Resolve $ref references to actual schema definitions
  Map<String, dynamic>? _resolveSchemaRef(Map<String, dynamic> schema) {
    final ref = schema['\$ref'] as String?;
    if (ref != null && ref.startsWith('#/components/schemas/')) {
      final schemaName = ref.substring('#/components/schemas/'.length);
      final components = swaggerSpec['components'] as Map<String, dynamic>?;
      final schemas = components?['schemas'] as Map<String, dynamic>?;
      return schemas?[schemaName] as Map<String, dynamic>?;
    }
    
    // If no $ref, return the schema as is
    return schema;
  }

  // Template generation methods
  Future<void> _generateModels(String featureName, List<ApiEndpoint> endpoints) async {
    final modelsPath = _getModelsFolderPath(featureName);
    final generatedModels = <String>{};

    for (final endpoint in endpoints) {
      // Generate request model if needed
      if (endpoint.requestBody != null) {
        final requestModelName = _generateRequestModelName(endpoint, featureName);
        if (!generatedModels.contains(requestModelName)) {
          final content = ModelTemplate.generateRequestModel(requestModelName, endpoint.requestBody?.schema);
          final fileName = '${_toSnakeCase(requestModelName)}.dart';
          await File(path.join(modelsPath, fileName)).writeAsString(content);
          generatedModels.add(requestModelName);
        }
      }

      // Generate response model
      final responseSchema = endpoint.responses['200']?.schema ?? 
                            endpoint.responses['201']?.schema ?? 
                            endpoint.responses['204']?.schema;
      final responseModelName = _generateResponseModelName(endpoint, featureName);
      if (!generatedModels.contains(responseModelName) && responseSchema != null) {
        final content = ModelTemplate.generateResponseModel(responseModelName, responseSchema);
        final fileName = '${_toSnakeCase(responseModelName)}.dart';
        await File(path.join(modelsPath, fileName)).writeAsString(content);
        generatedModels.add(responseModelName);
      }
    }
  }

  Future<void> _generateService(String featureName, List<ApiEndpoint> endpoints) async {
    final servicePath = path.join(projectRoot, 'lib', 'features', featureName, 'data', 'remote', 'service');
    final content = ServiceTemplate.generateService(featureName, endpoints, projectName);
    await File(path.join(servicePath, '${featureName}_service.dart')).writeAsString(content);
  }

  Future<void> _generateSource(String featureName, List<ApiEndpoint> endpoints) async {
    final sourcePath = path.join(projectRoot, 'lib', 'features', featureName, 'data', 'remote', 'source');
    
    // Generate source interface
    final sourceInterface = SourceTemplate.generateSourceInterface(featureName, endpoints, projectName);
    await File(path.join(sourcePath, '${featureName}_source.dart')).writeAsString(sourceInterface);
    
    // Generate source implementation
    final sourceImpl = SourceTemplate.generateSourceImplementation(featureName, endpoints, projectName);
    await File(path.join(sourcePath, '${featureName}_source_impl.dart')).writeAsString(sourceImpl);
  }

  Future<void> _generateRepositoryImpl(String featureName, List<ApiEndpoint> endpoints) async {
    final repositoryPath = path.join(projectRoot, 'lib', 'features', featureName, 'data', 'repository');
    final content = RepositoryTemplate.generateRepositoryImplementation(featureName, endpoints, projectName);
    await File(path.join(repositoryPath, '${featureName}_repository_impl.dart')).writeAsString(content);
  }

  Future<void> _generateRepositoryInterface(String featureName, List<ApiEndpoint> endpoints) async {
    final repositoryPath = path.join(projectRoot, 'lib', 'features', featureName, 'domain', 'repository');
    final content = RepositoryTemplate.generateRepositoryInterface(featureName, endpoints, projectName);
    await File(path.join(repositoryPath, '${featureName}_repository.dart')).writeAsString(content);
  }

  Future<void> _generateUseCases(String featureName, List<ApiEndpoint> endpoints) async {
    final useCasePath = path.join(projectRoot, 'lib', 'features', featureName, 'domain', 'usecase');
    final content = UseCaseTemplate.generateUseCases(featureName, endpoints, projectName);
    await File(path.join(useCasePath, '${featureName}_usecase.dart')).writeAsString(content);
  }

  Future<void> _generateBloc(String featureName, List<ApiEndpoint> endpoints) async {
    final blocPath = path.join(projectRoot, 'lib', 'features', featureName, 'presentation', 'bloc');
    
    // Generate bloc
    final blocContent = BlocTemplate.generateBloc(featureName, endpoints, projectName);
    await File(path.join(blocPath, '${featureName}_bloc.dart')).writeAsString(blocContent);
    
    // Generate event
    final eventContent = BlocTemplate.generateEvent(featureName, endpoints, projectName);
    await File(path.join(blocPath, '${featureName}_event.dart')).writeAsString(eventContent);
    
    // Generate state
    final stateContent = BlocTemplate.generateState(featureName, endpoints, projectName);
    await File(path.join(blocPath, '${featureName}_state.dart')).writeAsString(stateContent);
  }

  Future<void> _generateScreen(String featureName) async {
    final screenPath = path.join(projectRoot, 'lib', 'features', featureName, 'presentation', 'screen');
    final content = ScreenTemplate.generateScreen(featureName, projectName);
    await File(path.join(screenPath, '${featureName}_screen.dart')).writeAsString(content);
  }

  // Helper methods for generating names
  String _generateRequestModelName(ApiEndpoint endpoint, String featureName) {
    final methodName = _generateMethodName(endpoint);
    return '${_toPascalCase(methodName)}Request';
  }

  String _generateResponseModelName(ApiEndpoint endpoint, String featureName) {
    final methodName = _generateMethodName(endpoint);
    return '${_toPascalCase(methodName)}Response';
  }

  String _generateMethodName(ApiEndpoint endpoint) {
    if (endpoint.operationId != null && endpoint.operationId!.isNotEmpty) {
      return _toCamelCase(endpoint.operationId!);
    }
    
    final pathParts = endpoint.path.split('/').where((p) => p.isNotEmpty && !p.startsWith('{')).toList();
    final method = endpoint.method.toLowerCase();
    
    if (pathParts.isEmpty) {
      return method;
    }
    
    final baseName = pathParts.last;
    
    switch (method) {
      case 'get':
        return pathParts.length > 1 ? 'get${_toPascalCase(baseName)}' : 'get${_toPascalCase(baseName)}';
      case 'post':
        return 'create${_toPascalCase(baseName)}';
      case 'put':
        return 'update${_toPascalCase(baseName)}';
      case 'delete':
        return 'delete${_toPascalCase(baseName)}';
      case 'patch':
        return 'patch${_toPascalCase(baseName)}';
      default:
        return _toCamelCase(baseName);
    }
  }

  String _toPascalCase(String input) {
    return input
        .split(RegExp(r'[-_\s]+'))
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join('');
  }

  String _toCamelCase(String input) {
    final pascalCase = _toPascalCase(input);
    return pascalCase.isEmpty ? '' : pascalCase[0].toLowerCase() + pascalCase.substring(1);
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => '_${match.group(1)?.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }

  // Append methods for existing features
  
  /// Extract existing endpoints from service file
  Future<List<ApiEndpoint>> _extractExistingEndpoints(String featureName) async {
    final servicePath = path.join(projectRoot, 'lib', 'features', featureName, 'data', 'remote', 'service', '${featureName}_service.dart');
    final serviceFile = File(servicePath);
    
    if (!await serviceFile.exists()) {
      return [];
    }
    
    final content = await serviceFile.readAsString();
    final endpoints = <ApiEndpoint>[];
    
    // Parse existing service methods to extract endpoints
    // This is a simplified parser - in production you might want a more robust solution
    final methodRegex = RegExp(r'@(GET|POST|PUT|DELETE|PATCH)\("([^"]+)"\)');
    final matches = methodRegex.allMatches(content);
    
    for (final match in matches) {
      final method = match.group(1)?.toLowerCase() ?? '';
      final path = match.group(2) ?? '';
      
      endpoints.add(ApiEndpoint(
        path: path,
        method: method,
        summary: '',
        parameters: [],
        requestBody: null,
        responses: {},
      ));
    }
    
    return endpoints;
  }

  /// Append new models only
  Future<void> _appendModels(String featureName, List<ApiEndpoint> endpoints) async {
    final modelsPath = _getModelsFolderPath(featureName);
    final generatedModels = <String>{};

    for (final endpoint in endpoints) {
      // Generate request model if needed
      if (endpoint.requestBody != null) {
        final requestModelName = _generateRequestModelName(endpoint, featureName);
        if (!generatedModels.contains(requestModelName)) {
          final fileName = '${_toSnakeCase(requestModelName)}.dart';
          final filePath = path.join(modelsPath, fileName);
          
          // Only generate if file doesn't exist
          if (!await File(filePath).exists()) {
            final content = ModelTemplate.generateRequestModel(requestModelName, endpoint.requestBody?.schema);
            await File(filePath).writeAsString(content);
            generatedModels.add(requestModelName);
          }
        }
      }

      // Generate response model
      final responseSchema = endpoint.responses['200']?.schema ?? 
                            endpoint.responses['201']?.schema ?? 
                            endpoint.responses['204']?.schema;
      final responseModelName = _generateResponseModelName(endpoint, featureName);
      if (!generatedModels.contains(responseModelName) && responseSchema != null) {
        final fileName = '${_toSnakeCase(responseModelName)}.dart';
        final filePath = path.join(modelsPath, fileName);
        
        // Only generate if file doesn't exist
        if (!await File(filePath).exists()) {
          final content = ModelTemplate.generateResponseModel(responseModelName, responseSchema);
          await File(filePath).writeAsString(content);
          generatedModels.add(responseModelName);
        }
      }
    }
  }

  /// Append new methods to service
  Future<void> _appendToService(String featureName, List<ApiEndpoint> endpoints) async {
    final servicePath = path.join(projectRoot, 'lib', 'features', featureName, 'data', 'remote', 'service', '${featureName}_service.dart');
    final serviceFile = File(servicePath);
    
    if (!await serviceFile.exists()) {
      // If service doesn't exist, generate it normally
      await _generateService(featureName, endpoints);
      return;
    }
    
    final existingContent = await serviceFile.readAsString();
    final newMethods = <String>[];
    final newImports = <String>{};
    
    // Generate new methods
    for (final endpoint in endpoints) {
      final models = _getRequiredModels(endpoint, featureName);
      final modelFolderName = _getModelFolderName(featureName);
      for (final model in models) {
        newImports.add('package:$projectName/features/$featureName/data/$modelFolderName/${_toSnakeCase(model)}.dart');
      }
      newMethods.add(_generateServiceMethod(endpoint, featureName));
    }
    
    // Update existing imports if model folder name changed
    String updatedContent = existingContent;
    final modelFolderName = _getModelFolderName(featureName);
    
    // Fix existing imports to use correct model folder name
    final correctFolderName = modelFolderName == 'models' ? 'model' : 'models';
    final incorrectPattern = "package:$projectName/features/$featureName/data/$correctFolderName/";
    final correctPattern = "package:$projectName/features/$featureName/data/$modelFolderName/";
    
    if (updatedContent.contains(incorrectPattern)) {
      print('🔄 Updating imports to use "$modelFolderName" folder...');
      updatedContent = updatedContent.replaceAll(incorrectPattern, correctPattern);
    }

    // Add new imports
    final lastImportIndex = updatedContent.lastIndexOf("import '");
    if (lastImportIndex != -1) {
      final nextLineIndex = updatedContent.indexOf('\n', lastImportIndex);
      if (nextLineIndex != -1) {
        for (final import in newImports) {
          if (!updatedContent.contains(import)) {
            updatedContent = updatedContent.substring(0, nextLineIndex + 1) +
                            "import '$import';\n" +
                            updatedContent.substring(nextLineIndex + 1);
          }
        }
      }
    }
    
    // Add new methods before the closing brace
    final lastBraceIndex = updatedContent.lastIndexOf('}');
    if (lastBraceIndex != -1) {
      updatedContent = updatedContent.substring(0, lastBraceIndex) +
                      '\n${newMethods.join('\n\n')}\n' +
                      updatedContent.substring(lastBraceIndex);
    }
    
    await serviceFile.writeAsString(updatedContent);
  }

  /// Generate a single service method
  String _generateServiceMethod(ApiEndpoint endpoint, String featureName) {
    final methodName = _generateMethodName(endpoint);
    final pathAnnotation = _generatePathAnnotation(endpoint);
    final parameters = _generateMethodParameters(endpoint, featureName);
    final returnType = _generateReturnType(endpoint, featureName);
    
    return '  $pathAnnotation\n  Future<$returnType> $methodName($parameters);';
  }

  String _generatePathAnnotation(ApiEndpoint endpoint) {
    final method = endpoint.method.toUpperCase();
    final path = endpoint.path;
    
    // Convert path parameters to retrofit format
    final retrofitPath = path.replaceAllMapped(
      RegExp(r'\{([^}]+)\}'),
      (match) => '{${match.group(1)}}',
    );
    
    switch (method) {
      case 'GET':
        return '@GET("$retrofitPath")';
      case 'POST':
        return '@POST("$retrofitPath")';
      case 'PUT':
        return '@PUT("$retrofitPath")';
      case 'DELETE':
        return '@DELETE("$retrofitPath")';
      case 'PATCH':
        return '@PATCH("$retrofitPath")';
      default:
        return '@GET("$retrofitPath")';
    }
  }

  String _generateMethodParameters(ApiEndpoint endpoint, String featureName) {
    final parameters = <String>[];
    
    // Add path parameters
    for (final param in endpoint.parameters) {
      if (param.location == 'path') {
        parameters.add('@Path("${param.name}") ${param.type} ${param.name}');
      }
    }
    
    // Add query parameters
    for (final param in endpoint.parameters) {
      if (param.location == 'query') {
        parameters.add('@Query("${param.name}") ${param.type}? ${param.name}');
      }
    }
    
    // Add request body if exists
    if (endpoint.requestBody != null) {
      final requestModelName = _generateRequestModelName(endpoint, featureName);
      parameters.add('@Body() $requestModelName params');
    }
    
    return parameters.join(', ');
  }

  String _generateReturnType(ApiEndpoint endpoint, String featureName) {
    // Try to get the success response (200, 201, etc.)
    final successResponse = endpoint.responses['200'] ?? 
                           endpoint.responses['201'] ?? 
                           endpoint.responses['204'];
    
    if (successResponse?.schema != null) {
      final responseModelName = _generateResponseModelName(endpoint, featureName);
      return responseModelName;
    }
    
    return 'dynamic';
  }

  Set<String> _getRequiredModels(ApiEndpoint endpoint, String featureName) {
    final models = <String>{};
    
    // Add request model if exists
    if (endpoint.requestBody != null) {
      models.add(_generateRequestModelName(endpoint, featureName));
    }
    
    // Add response model
    models.add(_generateResponseModelName(endpoint, featureName));
    
    return models;
  }

  /// Append to source layers
  Future<void> _appendToSource(String featureName, List<ApiEndpoint> endpoints) async {
    // Append to both source interface and implementation
    await _appendToSourceInterface(featureName, endpoints);
    await _appendToSourceImpl(featureName, endpoints);
  }

  /// Append new methods to source interface
  Future<void> _appendToSourceInterface(String featureName, List<ApiEndpoint> endpoints) async {
    final sourcePath = path.join(projectRoot, 'lib', 'features', featureName, 'data', 'remote', 'source', '${featureName}_source.dart');
    final sourceFile = File(sourcePath);
    
    if (!await sourceFile.exists()) {
      // If source interface doesn't exist, generate it normally
      final sourceInterface = SourceTemplate.generateSourceInterface(featureName, endpoints, projectName);
      await sourceFile.writeAsString(sourceInterface);
      return;
    }
    
    final existingContent = await sourceFile.readAsString();
    final newMethods = <String>[];
    final newImports = <String>{};
    
    // Generate new methods
    for (final endpoint in endpoints) {
      final methodName = _generateMethodName(endpoint);
      
      // Check if method already exists
      if (!existingContent.contains('Future<') || !existingContent.contains('$methodName(')) {
        final returnType = _generateReturnType(endpoint, featureName);
        final parameters = _generateRepositoryMethodParameters(endpoint, featureName);
        
        // Add import for return type if needed
        if (returnType != 'dynamic') {
          final modelFolderName = _getModelFolderName(featureName);
          newImports.add('package:$projectName/features/$featureName/data/$modelFolderName/${_toSnakeCase(returnType)}.dart');
        }
        
        newMethods.add('  Future<$returnType> $methodName($parameters);');
      }
    }
    
    if (newMethods.isEmpty) {
      print('  🔗 No new source interface methods to add');
      return;
    }
    
    // Add new imports
    String updatedContent = existingContent;
    final lastImportIndex = updatedContent.lastIndexOf("import '");
    if (lastImportIndex != -1) {
      final nextLineIndex = updatedContent.indexOf('\n', lastImportIndex);
      if (nextLineIndex != -1) {
        for (final import in newImports) {
          if (!updatedContent.contains(import)) {
            updatedContent = updatedContent.substring(0, nextLineIndex + 1) +
                            "import '$import';\n" +
                            updatedContent.substring(nextLineIndex + 1);
          }
        }
      }
    }
    
    // Add new methods before the closing brace
    final lastBraceIndex = updatedContent.lastIndexOf('}');
    if (lastBraceIndex != -1) {
      updatedContent = updatedContent.substring(0, lastBraceIndex) +
                      '\n${newMethods.join('\n')}\n' +
                      updatedContent.substring(lastBraceIndex);
    }
    
    await sourceFile.writeAsString(updatedContent);
    print('  🔗 Added ${newMethods.length} new source interface methods');
  }

  /// Append new methods to source implementation
  Future<void> _appendToSourceImpl(String featureName, List<ApiEndpoint> endpoints) async {
    final sourcePath = path.join(projectRoot, 'lib', 'features', featureName, 'data', 'remote', 'source', '${featureName}_source_impl.dart');
    final sourceFile = File(sourcePath);
    
    if (!await sourceFile.exists()) {
      // If source implementation doesn't exist, generate it normally
      final sourceImpl = SourceTemplate.generateSourceImplementation(featureName, endpoints, projectName);
      await sourceFile.writeAsString(sourceImpl);
      return;
    }
    
    final existingContent = await sourceFile.readAsString();
    final newMethods = <String>[];
    final newImports = <String>{};
    
    // Generate new methods
    for (final endpoint in endpoints) {
      final methodName = _generateMethodName(endpoint);
      
      // Check if method already exists
      if (!existingContent.contains('Future<') || !existingContent.contains('$methodName(')) {
        final returnType = _generateReturnType(endpoint, featureName);
        final parameters = _generateRepositoryMethodParameters(endpoint, featureName);
        
        // Add import for return type if needed
        if (returnType != 'dynamic') {
          final modelFolderName = _getModelFolderName(featureName);
          newImports.add('package:$projectName/features/$featureName/data/$modelFolderName/${_toSnakeCase(returnType)}.dart');
        }
        
        newMethods.add('''  @override
  Future<$returnType> $methodName($parameters) async {
    return await service.$methodName($parameters);
  }''');
      }
    }
    
    if (newMethods.isEmpty) {
      print('  ⚡ No new source implementation methods to add');
      return;
    }
    
    // Add new imports
    String updatedContent = existingContent;
    final lastImportIndex = updatedContent.lastIndexOf("import '");
    if (lastImportIndex != -1) {
      final nextLineIndex = updatedContent.indexOf('\n', lastImportIndex);
      if (nextLineIndex != -1) {
        for (final import in newImports) {
          if (!updatedContent.contains(import)) {
            updatedContent = updatedContent.substring(0, nextLineIndex + 1) +
                            "import '$import';\n" +
                            updatedContent.substring(nextLineIndex + 1);
          }
        }
      }
    }
    
    // Add new methods before the closing brace
    final lastBraceIndex = updatedContent.lastIndexOf('}');
    if (lastBraceIndex != -1) {
      updatedContent = updatedContent.substring(0, lastBraceIndex) +
                      '\n${newMethods.join('\n\n')}\n' +
                      updatedContent.substring(lastBraceIndex);
    }
    
    await sourceFile.writeAsString(updatedContent);
    print('  ⚡ Added ${newMethods.length} new source implementation methods');
  }

  Future<void> _appendToRepository(String featureName, List<ApiEndpoint> endpoints) async {
    // Append to both repository interface and implementation
    await _appendToRepositoryInterface(featureName, endpoints);
    await _appendToRepositoryImpl(featureName, endpoints);
  }

  /// Append new methods to repository interface
  Future<void> _appendToRepositoryInterface(String featureName, List<ApiEndpoint> endpoints) async {
    final repositoryPath = path.join(projectRoot, 'lib', 'features', featureName, 'domain', 'repository', '${featureName}_repository.dart');
    final repositoryFile = File(repositoryPath);
    
    if (!await repositoryFile.exists()) {
      // If repository interface doesn't exist, generate it normally
      await _generateRepositoryInterface(featureName, endpoints);
      return;
    }
    
    final existingContent = await repositoryFile.readAsString();
    final newMethods = <String>[];
    final newImports = <String>{};
    
    // Generate new methods
    for (final endpoint in endpoints) {
      final methodName = _generateMethodName(endpoint);
      
      // Check if method already exists
      if (!existingContent.contains('Future<') || !existingContent.contains('$methodName(')) {
        final returnType = _generateReturnType(endpoint, featureName);
        final parameters = _generateRepositoryMethodParameters(endpoint, featureName);
        
        // Add import for return type if needed
        if (returnType != 'dynamic') {
          final modelFolderName = _getModelFolderName(featureName);
          newImports.add('package:$projectName/features/$featureName/data/$modelFolderName/${_toSnakeCase(returnType)}.dart');
        }
        
        newMethods.add('  Future<$returnType> $methodName($parameters);');
      }
    }
    
    if (newMethods.isEmpty) {
      print('  🏛️ No new repository interface methods to add');
      return;
    }
    
    // Add new imports
    String updatedContent = existingContent;
    final lastImportIndex = updatedContent.lastIndexOf("import '");
    if (lastImportIndex != -1) {
      final nextLineIndex = updatedContent.indexOf('\n', lastImportIndex);
      if (nextLineIndex != -1) {
        for (final import in newImports) {
          if (!updatedContent.contains(import)) {
            updatedContent = updatedContent.substring(0, nextLineIndex + 1) +
                            "import '$import';\n" +
                            updatedContent.substring(nextLineIndex + 1);
          }
        }
      }
    }
    
    // Add new methods before the closing brace
    final lastBraceIndex = updatedContent.lastIndexOf('}');
    if (lastBraceIndex != -1) {
      updatedContent = updatedContent.substring(0, lastBraceIndex) +
                      '\n${newMethods.join('\n')}\n' +
                      updatedContent.substring(lastBraceIndex);
    }
    
    await repositoryFile.writeAsString(updatedContent);
    print('  🏛️ Added ${newMethods.length} new repository interface methods');
  }

  /// Append new methods to repository implementation
  Future<void> _appendToRepositoryImpl(String featureName, List<ApiEndpoint> endpoints) async {
    final repositoryPath = path.join(projectRoot, 'lib', 'features', featureName, 'data', 'repository', '${featureName}_repository_impl.dart');
    final repositoryFile = File(repositoryPath);
    
    if (!await repositoryFile.exists()) {
      // If repository implementation doesn't exist, generate it normally
      await _generateRepositoryImpl(featureName, endpoints);
      return;
    }
    
    final existingContent = await repositoryFile.readAsString();
    final newMethods = <String>[];
    final newImports = <String>{};
    
    // Generate new methods
    for (final endpoint in endpoints) {
      final methodName = _generateMethodName(endpoint);
      
      // Check if method already exists
      if (!existingContent.contains('Future<') || !existingContent.contains('$methodName(')) {
        final returnType = _generateReturnType(endpoint, featureName);
        final parameters = _generateRepositoryMethodParameters(endpoint, featureName);
        
        // Add import for return type if needed
        if (returnType != 'dynamic') {
          final modelFolderName = _getModelFolderName(featureName);
          newImports.add('package:$projectName/features/$featureName/data/$modelFolderName/${_toSnakeCase(returnType)}.dart');
        }
        
        newMethods.add('''  @override
  Future<$returnType> $methodName($parameters) async {
    return await source.$methodName($parameters);
  }''');
      }
    }
    
    if (newMethods.isEmpty) {
      print('  📦 No new repository implementation methods to add');
      return;
    }
    
    // Add new imports
    String updatedContent = existingContent;
    final lastImportIndex = updatedContent.lastIndexOf("import '");
    if (lastImportIndex != -1) {
      final nextLineIndex = updatedContent.indexOf('\n', lastImportIndex);
      if (nextLineIndex != -1) {
        for (final import in newImports) {
          if (!updatedContent.contains(import)) {
            updatedContent = updatedContent.substring(0, nextLineIndex + 1) +
                            "import '$import';\n" +
                            updatedContent.substring(nextLineIndex + 1);
          }
        }
      }
    }
    
    // Add new methods before the closing brace
    final lastBraceIndex = updatedContent.lastIndexOf('}');
    if (lastBraceIndex != -1) {
      updatedContent = updatedContent.substring(0, lastBraceIndex) +
                      '\n${newMethods.join('\n\n')}\n' +
                      updatedContent.substring(lastBraceIndex);
    }
    
    await repositoryFile.writeAsString(updatedContent);
    print('  📦 Added ${newMethods.length} new repository implementation methods');
  }

  /// Generate parameters for repository methods
  String _generateRepositoryMethodParameters(ApiEndpoint endpoint, String featureName) {
    final parameters = <String>[];
    
    // Add path parameters
    for (final param in endpoint.parameters) {
      if (param.location == 'path') {
        parameters.add('${param.type} ${param.name}');
      }
    }
    
    // Add query parameters
    for (final param in endpoint.parameters) {
      if (param.location == 'query') {
        parameters.add('${param.type}? ${param.name}');
      }
    }
    
    // Add request body if exists
    if (endpoint.requestBody != null) {
      final requestModelName = _generateRequestModelName(endpoint, featureName);
      parameters.add('$requestModelName params');
    }
    
    return parameters.join(', ');
  }

  Future<void> _appendToUseCases(String featureName, List<ApiEndpoint> endpoints) async {
    final useCasePath = path.join(projectRoot, 'lib', 'features', featureName, 'domain', 'usecase', '${featureName}_usecase.dart');
    final useCaseFile = File(useCasePath);
    
    if (!await useCaseFile.exists()) {
      // If use case file doesn't exist, generate it normally
      await _generateUseCases(featureName, endpoints);
      return;
    }
    
    final existingContent = await useCaseFile.readAsString();
    final newMethods = <String>[];
    final newImports = <String>{};
    
    // Generate new methods for the main UseCases class
    for (final endpoint in endpoints) {
      final methodName = _generateMethodName(endpoint);
      
      // Check if method already exists in the main UseCases class
      if (!existingContent.contains('Future<') || !existingContent.contains('$methodName(')) {
        final returnType = _generateReturnType(endpoint, featureName);
        final parameters = _generateRepositoryMethodParameters(endpoint, featureName);
        
        // Add import for return type if needed
        if (returnType != 'dynamic') {
          final modelFolderName = _getModelFolderName(featureName);
          newImports.add('package:$projectName/features/$featureName/data/$modelFolderName/${_toSnakeCase(returnType)}.dart');
        }
        
        // Generate the method based on the pattern (with Either<Error, T> or direct Future<T>)
        if (existingContent.contains('Either<Error,')) {
          // Use Either pattern like existing methods
          newMethods.add('  Future<Either<Error, $returnType>> $methodName($parameters) =>\n      repository.$methodName($parameters);');
        } else {
          // Use direct Future pattern
          newMethods.add('  Future<$returnType> $methodName($parameters) =>\n      repository.$methodName($parameters);');
        }
      }
    }
    
    if (newMethods.isEmpty) {
      print('  🎯 No new use case methods to add');
      return;
    }
    
    // Add new imports
    String updatedContent = existingContent;
    final lastImportIndex = updatedContent.lastIndexOf("import '");
    if (lastImportIndex != -1) {
      final nextLineIndex = updatedContent.indexOf('\n', lastImportIndex);
      if (nextLineIndex != -1) {
        for (final import in newImports) {
          if (!updatedContent.contains(import)) {
            updatedContent = updatedContent.substring(0, nextLineIndex + 1) +
                            "import '$import';\n" +
                            updatedContent.substring(nextLineIndex + 1);
          }
        }
      }
    }
    
    // Find the main UseCases class and add methods before its closing brace
    final useCasesClassName = '${_toPascalCase(featureName)}UseCases';
    final classIndex = updatedContent.indexOf('class $useCasesClassName');
    if (classIndex != -1) {
      // Find the closing brace of the main UseCases class (before any other classes)
      int braceCount = 0;
      int closingBraceIndex = -1;
      bool foundOpenBrace = false;
      
      for (int i = classIndex; i < updatedContent.length; i++) {
        if (updatedContent[i] == '{') {
          foundOpenBrace = true;
          braceCount++;
        } else if (updatedContent[i] == '}') {
          braceCount--;
          if (foundOpenBrace && braceCount == 0) {
            closingBraceIndex = i;
            break;
          }
        }
      }
      
      if (closingBraceIndex != -1) {
        updatedContent = updatedContent.substring(0, closingBraceIndex) +
                        '\n${newMethods.join('\n\n')}\n' +
                        updatedContent.substring(closingBraceIndex);
      }
    }
    
    await useCaseFile.writeAsString(updatedContent);
    print('  🎯 Added ${newMethods.length} new use case methods');
  }

  Future<void> _appendToBloc(String featureName, List<ApiEndpoint> endpoints) async {
    // Append to existing BLoC files
    await _appendToBlocEvents(featureName, endpoints);
    await _appendToBlocStates(featureName, endpoints);
    await _appendToBlocClass(featureName, endpoints);
  }

  /// Append new events to existing bloc events file
  Future<void> _appendToBlocEvents(String featureName, List<ApiEndpoint> endpoints) async {
    final eventPath = path.join(projectRoot, 'lib', 'features', featureName, 'presentation', 'bloc', '${featureName}_event.dart');
    final eventFile = File(eventPath);
    
    if (!await eventFile.exists()) {
      // If event file doesn't exist, generate it normally
      final eventContent = BlocTemplate.generateEvent(featureName, endpoints, projectName);
      await eventFile.writeAsString(eventContent);
      return;
    }
    
    final existingContent = await eventFile.readAsString();
    final newEvents = <String>[];
    
    // Check if using freezed pattern or simple class pattern
    if (existingContent.contains('@freezed') && existingContent.contains('const factory')) {
      // Generate new factory methods for freezed pattern
      for (final endpoint in endpoints) {
        final methodName = _generateMethodName(endpoint);
        final eventMethodName = '${methodName}Requested';
        
        // Check if event method already exists
        if (!existingContent.contains('const factory') || !existingContent.contains('$eventMethodName()')) {
          newEvents.add('  const factory ${_toPascalCase(featureName)}Event.$eventMethodName() = $eventMethodName;');
        }
      }
      
      if (newEvents.isEmpty) {
        print('  📝 No new events to add');
        return;
      }
      
      // Find the closing brace of the freezed class (before the last closing brace)
      final factoryPattern = RegExp(r'const factory.*?=.*?;');
      final matches = factoryPattern.allMatches(existingContent);
      if (matches.isNotEmpty) {
        final lastMatch = matches.last;
        final insertIndex = lastMatch.end;
        final updatedContent = existingContent.substring(0, insertIndex) +
                              '\n\n${newEvents.join('\n')}' +
                              existingContent.substring(insertIndex);
        await eventFile.writeAsString(updatedContent);
        print('  📝 Added ${newEvents.length} new event methods');
      }
    } else {
      // Generate simple event classes for non-freezed pattern
      for (final endpoint in endpoints) {
        final methodName = _generateMethodName(endpoint);
        final eventName = '${_toPascalCase(methodName)}Event';
        
        // Check if event already exists
        if (!existingContent.contains('class $eventName')) {
          newEvents.add('class $eventName extends ${_toPascalCase(featureName)}Event {}');
        }
      }
      
      if (newEvents.isEmpty) {
        print('  📝 No new events to add');
        return;
      }
      
      // Add new events before the closing brace
      final lastBraceIndex = existingContent.lastIndexOf('}');
      if (lastBraceIndex != -1) {
        final updatedContent = existingContent.substring(0, lastBraceIndex) +
                              '\n${newEvents.join('\n\n')}\n' +
                              existingContent.substring(lastBraceIndex);
        await eventFile.writeAsString(updatedContent);
        print('  📝 Added ${newEvents.length} new events');
      }
    }
  }

  /// Append new states to existing bloc states file
  Future<void> _appendToBlocStates(String featureName, List<ApiEndpoint> endpoints) async {
    final statePath = path.join(projectRoot, 'lib', 'features', featureName, 'presentation', 'bloc', '${featureName}_state.dart');
    final stateFile = File(statePath);
    
    if (!await stateFile.exists()) {
      // If state file doesn't exist, generate it normally
      final stateContent = BlocTemplate.generateState(featureName, endpoints, projectName);
      await stateFile.writeAsString(stateContent);
      return;
    }
    
    final existingContent = await stateFile.readAsString();
    final newStateFields = <String>[];
    
    // Check if using freezed pattern
    if (existingContent.contains('@freezed') && existingContent.contains('const factory')) {
      // Generate new fields for the main freezed state class
      for (final endpoint in endpoints) {
        final methodName = _generateMethodName(endpoint);
        final responseModelName = _generateResponseModelName(endpoint, featureName);
        final fieldName = '${methodName}Response';
        
        // Check if field already exists
        if (!existingContent.contains('@Default(null) $responseModelName?') && !existingContent.contains('$fieldName,')) {
          newStateFields.add('    @Default(null) $responseModelName? $fieldName,');
        }
      }
      
      if (newStateFields.isEmpty) {
        print('  🏛️ No new state fields to add');
        return;
      }
      
      // Find the constructor parameters and add new fields before the closing parenthesis
      final constructorPattern = RegExp(r'const factory.*?\{([^}]+)\}');
      final match = constructorPattern.firstMatch(existingContent);
      if (match != null) {
        final constructorEnd = match.end - 2; // Before the closing }
        final updatedContent = existingContent.substring(0, constructorEnd) +
                              '\n${newStateFields.join('\n')}' +
                              existingContent.substring(constructorEnd);
        await stateFile.writeAsString(updatedContent);
        print('  🏛️ Added ${newStateFields.length} new state fields');
      }
    } else {
      // Generate simple state classes for non-freezed pattern (fallback)
      final newStates = <String>[];
      
      for (final endpoint in endpoints) {
        final methodName = _generateMethodName(endpoint);
        final pascalMethodName = _toPascalCase(methodName);
        
        final loadingState = '${pascalMethodName}LoadingState';
        final successState = '${pascalMethodName}SuccessState';
        final errorState = '${pascalMethodName}ErrorState';
        
        // Check if states already exist and add missing ones
        if (!existingContent.contains('class $loadingState')) {
          newStates.add('class $loadingState extends ${_toPascalCase(featureName)}State {}');
        }
        
        final responseModelName = _generateResponseModelName(endpoint, featureName);
        if (!existingContent.contains('class $successState')) {
          newStates.add('''class $successState extends ${_toPascalCase(featureName)}State {
  final $responseModelName data;
  $successState(this.data);
}''');
        }
        
        if (!existingContent.contains('class $errorState')) {
          newStates.add('''class $errorState extends ${_toPascalCase(featureName)}State {
  final String message;
  $errorState(this.message);
}''');
        }
      }
      
      if (newStates.isEmpty) {
        print('  🏛️ No new states to add');
        return;
      }
      
      // Add new states before the closing brace
      final lastBraceIndex = existingContent.lastIndexOf('}');
      if (lastBraceIndex != -1) {
        final updatedContent = existingContent.substring(0, lastBraceIndex) +
                              '\n${newStates.join('\n\n')}\n' +
                              existingContent.substring(lastBraceIndex);
        await stateFile.writeAsString(updatedContent);
        print('  🏛️ Added ${newStates.length} new states');
      }
    }
  }

  /// Append new methods to existing bloc class
  Future<void> _appendToBlocClass(String featureName, List<ApiEndpoint> endpoints) async {
    final blocPath = path.join(projectRoot, 'lib', 'features', featureName, 'presentation', 'bloc', '${featureName}_bloc.dart');
    final blocFile = File(blocPath);
    
    if (!await blocFile.exists()) {
      // If bloc file doesn't exist, generate it normally
      final blocContent = BlocTemplate.generateBloc(featureName, endpoints, projectName);
      await blocFile.writeAsString(blocContent);
      return;
    }
    
    final existingContent = await blocFile.readAsString();
    final newMethods = <String>[];
    final newImports = <String>{};
    
    // Generate new event handlers
    for (final endpoint in endpoints) {
      final methodName = _generateMethodName(endpoint);
      final eventName = '${_toPascalCase(methodName)}Event';
      
      // Check if handler already exists
      if (!existingContent.contains('_on$eventName')) {
        final pascalMethodName = _toPascalCase(methodName);
        final useCaseName = '${methodName}UseCase';
        
        // Add import for model if needed
        final responseModelName = _generateResponseModelName(endpoint, featureName);
        final modelFolderName = _getModelFolderName(featureName);
        newImports.add('package:$projectName/features/$featureName/data/$modelFolderName/${_toSnakeCase(responseModelName)}.dart');
        
        newMethods.add('''  void _on$eventName($eventName event, Emitter<${_toPascalCase(featureName)}State> emit) async {
    emit(${pascalMethodName}LoadingState());
    try {
      final result = await $useCaseName();
      emit(${pascalMethodName}SuccessState(result));
    } catch (e) {
      emit(${pascalMethodName}ErrorState(e.toString()));
    }
  }''');
      }
    }
    
    if (newMethods.isEmpty) {
      print('  🎯 No new BLoC methods to add');
      return;
    }
    
    // Add new imports
    String updatedContent = existingContent;
    final lastImportIndex = updatedContent.lastIndexOf("import '");
    if (lastImportIndex != -1) {
      final nextLineIndex = updatedContent.indexOf('\n', lastImportIndex);
      if (nextLineIndex != -1) {
        for (final import in newImports) {
          if (!updatedContent.contains(import)) {
            updatedContent = updatedContent.substring(0, nextLineIndex + 1) +
                            "import '$import';\n" +
                            updatedContent.substring(nextLineIndex + 1);
          }
        }
      }
    }
    
    // Add new methods before the closing brace
    final lastBraceIndex = updatedContent.lastIndexOf('}');
    if (lastBraceIndex != -1) {
      updatedContent = updatedContent.substring(0, lastBraceIndex) +
                      '\n${newMethods.join('\n\n')}\n' +
                      updatedContent.substring(lastBraceIndex);
    }
    
    await blocFile.writeAsString(updatedContent);
    print('  🎯 Added ${newMethods.length} new BLoC methods');
  }
}
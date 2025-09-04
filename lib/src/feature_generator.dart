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

  FeatureGenerator(this.projectRoot);

  /// Run the feature generator with command line arguments
  Future<void> run(List<String> arguments) async {
    print('🎯 Flutter Feature Generator');
    print('=' * 30);

    try {
      // Load swagger specification
      await loadSwaggerSpec();

      // Select endpoints interactively
      final selectedEndpoints = await selectEndpointsInteractively();
      
      if (selectedEndpoints.isEmpty) {
        print('❌ No endpoints selected. Exiting.');
        return;
      }

      // Get feature name with validation
      final featureName = await _getValidFeatureName();
      
      if (featureName == null) {
        print('❌ Feature name is required');
        return;
      }

      // Generate the feature
      await generateFeature(featureName, selectedEndpoints);
      
      print('\n🎉 Generation completed!');
      print('📋 Next steps:');
      print('  1. Run "flutter packages pub run build_runner build" to generate .g.dart files');
      print('  2. Add the repository to your DI container');
      print('  3. Import and use the generated BLoC in your screens');

    } catch (e) {
      print('❌ Error: $e');
      exit(1);
    }
  }

  /// Get a valid feature name with validation
  Future<String?> _getValidFeatureName() async {
    final restrictedNames = ['test', 'build', 'lib', 'android', 'ios', 'web', 'windows', 'linux', 'macos'];
    
    while (true) {
      print('\n📝 Enter the feature name (e.g., user_management, products, etc.):');
      final featureName = stdin.readLineSync()?.trim();
      
      if (featureName == null || featureName.isEmpty) {
        print('❌ Feature name is required');
        continue;
      }
      
      // Validate feature name
      if (restrictedNames.contains(featureName.toLowerCase())) {
        print('❌ "$featureName" is a restricted name. Please choose a different name.');
        continue;
      }
      
      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(featureName)) {
        print('❌ Feature name should be in snake_case (e.g., user_management)');
        continue;
      }
      
      return featureName;
    }
  }

  /// Load and parse the swagger.json file
  Future<void> loadSwaggerSpec() async {
    final swaggerFile = File(path.join(projectRoot, 'swagger.json'));
    if (!await swaggerFile.exists()) {
      throw Exception('swagger.json not found in project root');
    }
    
    final content = await swaggerFile.readAsString();
    swaggerSpec = json.decode(content);
    print('✅ Swagger specification loaded successfully');
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
    
    final input = stdin.readLineSync()?.trim();
    
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

    return selectedEndpoints;
  }

  /// Generate feature for selected endpoints
  Future<void> generateFeature(String featureName, List<ApiEndpoint> endpoints) async {
    final featurePath = path.join(projectRoot, 'lib', 'features', featureName);
    final featureExists = await Directory(featurePath).exists();
    
    if (featureExists) {
      print('\n📁 Feature "$featureName" already exists!');
      print('🔧 Choose an option:');
      print('  1. Append new APIs to existing feature');
      print('  2. Overwrite entire feature');
      print('  3. Cancel generation');
      
      final choice = stdin.readLineSync()?.trim();
      
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

  /// Generate a complete new feature
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

  /// Create the folder structure
  Future<void> _createFolderStructure(String featureName) async {
    final basePath = path.join(projectRoot, 'lib', 'features', featureName);
    
    final folders = [
      '$basePath/data/model',
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

  /// Generate presentation layer files
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
    final modelsPath = path.join(projectRoot, 'lib', 'features', featureName, 'data', 'model');
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
    final content = ServiceTemplate.generateService(featureName, endpoints);
    await File(path.join(servicePath, '${featureName}_service.dart')).writeAsString(content);
  }

  Future<void> _generateSource(String featureName, List<ApiEndpoint> endpoints) async {
    final sourcePath = path.join(projectRoot, 'lib', 'features', featureName, 'data', 'remote', 'source');
    
    // Generate source interface
    final sourceInterface = SourceTemplate.generateSourceInterface(featureName, endpoints);
    await File(path.join(sourcePath, '${featureName}_source.dart')).writeAsString(sourceInterface);
    
    // Generate source implementation
    final sourceImpl = SourceTemplate.generateSourceImplementation(featureName, endpoints);
    await File(path.join(sourcePath, '${featureName}_source_impl.dart')).writeAsString(sourceImpl);
  }

  Future<void> _generateRepositoryImpl(String featureName, List<ApiEndpoint> endpoints) async {
    final repositoryPath = path.join(projectRoot, 'lib', 'features', featureName, 'data', 'repository');
    final content = RepositoryTemplate.generateRepositoryImplementation(featureName, endpoints);
    await File(path.join(repositoryPath, '${featureName}_repository_impl.dart')).writeAsString(content);
  }

  Future<void> _generateRepositoryInterface(String featureName, List<ApiEndpoint> endpoints) async {
    final repositoryPath = path.join(projectRoot, 'lib', 'features', featureName, 'domain', 'repository');
    final content = RepositoryTemplate.generateRepositoryInterface(featureName, endpoints);
    await File(path.join(repositoryPath, '${featureName}_repository.dart')).writeAsString(content);
  }

  Future<void> _generateUseCases(String featureName, List<ApiEndpoint> endpoints) async {
    final useCasePath = path.join(projectRoot, 'lib', 'features', featureName, 'domain', 'usecase');
    final content = UseCaseTemplate.generateUseCases(featureName, endpoints);
    await File(path.join(useCasePath, '${featureName}_usecase.dart')).writeAsString(content);
  }

  Future<void> _generateBloc(String featureName, List<ApiEndpoint> endpoints) async {
    final blocPath = path.join(projectRoot, 'lib', 'features', featureName, 'presentation', 'bloc');
    
    // Generate bloc
    final blocContent = BlocTemplate.generateBloc(featureName, endpoints);
    await File(path.join(blocPath, '${featureName}_bloc.dart')).writeAsString(blocContent);
    
    // Generate event
    final eventContent = BlocTemplate.generateEvent(featureName, endpoints);
    await File(path.join(blocPath, '${featureName}_event.dart')).writeAsString(eventContent);
    
    // Generate state
    final stateContent = BlocTemplate.generateState(featureName, endpoints);
    await File(path.join(blocPath, '${featureName}_state.dart')).writeAsString(stateContent);
  }

  Future<void> _generateScreen(String featureName) async {
    final screenPath = path.join(projectRoot, 'lib', 'features', featureName, 'presentation', 'screen');
    final content = ScreenTemplate.generateScreen(featureName);
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
    final modelsPath = path.join(projectRoot, 'lib', 'features', featureName, 'data', 'model');
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
      for (final model in models) {
        newImports.add('package:creamati_mobile/features/$featureName/data/model/${_toSnakeCase(model)}.dart');
      }
      newMethods.add(_generateServiceMethod(endpoint, featureName));
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

  /// Append to other layers (simplified implementations)
  Future<void> _appendToSource(String featureName, List<ApiEndpoint> endpoints) async {
    // For now, regenerate source files - in production you might want to append
    await _generateSource(featureName, endpoints);
  }

  Future<void> _appendToRepository(String featureName, List<ApiEndpoint> endpoints) async {
    // For now, regenerate repository files - in production you might want to append
    await _generateRepositoryImpl(featureName, endpoints);
  }

  Future<void> _appendToUseCases(String featureName, List<ApiEndpoint> endpoints) async {
    // For now, regenerate use case files - in production you might want to append
    await _generateUseCases(featureName, endpoints);
  }

  Future<void> _appendToBloc(String featureName, List<ApiEndpoint> endpoints) async {
    // For now, regenerate BLoC files - in production you might want to append
    await _generateBloc(featureName, endpoints);
  }
}
import 'shared.dart';

class ServiceTemplate {
  static String generateService(String featureName, List<ApiEndpoint> endpoints) {
    final className = '${_toPascalCase(featureName)}RemoteService';
    final methods = <String>[];
    final imports = <String>{
      'package:creamati_mobile/core/utils/api_constant.dart',
      'package:creamati_mobile/di/interceptors.dart',
      'package:dio/dio.dart',
      'package:injectable/injectable.dart',
      'package:retrofit/retrofit.dart',
    };

    // Generate model imports
    for (final endpoint in endpoints) {
      final models = _getRequiredModels(endpoint, featureName);
      
      for (final model in models) {
        imports.add('package:creamati_mobile/features/$featureName/data/model/${_toSnakeCase(model)}.dart');
      }
    }

    // Generate methods
    for (final endpoint in endpoints) {
      methods.add(_generateServiceMethod(endpoint, featureName));
    }

    return '''
${imports.map((i) => "import '$i';").join('\n')}

part '${featureName}_service.g.dart';

/// The contract for the $featureName remote service.
/// This represent the blue print for the service.
@RestApi()
@injectable
abstract class $className {
  @factoryMethod
  factory $className(Dio dio) {
    dio.interceptors.add(AuthInterceptor());
    return _$className(dio);
  }

${methods.join('\n\n')}
}
''';
  }

  static String _generateServiceMethod(ApiEndpoint endpoint, String featureName) {
    final methodName = _generateMethodName(endpoint);
    final httpMethod = endpoint.method.toUpperCase();
    final pathAnnotation = _generatePathAnnotation(endpoint);
    final parameters = _generateMethodParameters(endpoint, featureName);
    final returnType = _generateReturnType(endpoint, featureName);
    
    return '''  $pathAnnotation
  Future<$returnType> $methodName($parameters);''';
  }

  static String _generatePathAnnotation(ApiEndpoint endpoint) {
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

  static String _generateMethodParameters(ApiEndpoint endpoint, String featureName) {
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

  static String _generateReturnType(ApiEndpoint endpoint, String featureName) {
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

  static String _generateMethodName(ApiEndpoint endpoint) {
    if (endpoint.operationId != null && endpoint.operationId!.isNotEmpty) {
      return _toCamelCase(endpoint.operationId!);
    }
    
    // Generate method name from path and method
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

  static Set<String> _getRequiredModels(ApiEndpoint endpoint, String featureName) {
    final models = <String>{};
    
    // Add request model if exists
    if (endpoint.requestBody != null) {
      models.add(_generateRequestModelName(endpoint, featureName));
    }
    
    // Add response model
    models.add(_generateResponseModelName(endpoint, featureName));
    
    return models;
  }

  static String _generateRequestModelName(ApiEndpoint endpoint, String featureName) {
    final methodName = _generateMethodName(endpoint);
    return '${_toPascalCase(methodName)}Request';
  }

  static String _generateResponseModelName(ApiEndpoint endpoint, String featureName) {
    final methodName = _generateMethodName(endpoint);
    return '${_toPascalCase(methodName)}Response';
  }

  static String _toPascalCase(String input) {
    return input
        .split(RegExp(r'[-_\s]+'))
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join('');
  }

  static String _toCamelCase(String input) {
    final pascalCase = _toPascalCase(input);
    return pascalCase.isEmpty ? '' : pascalCase[0].toLowerCase() + pascalCase.substring(1);
  }

  static String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => '_${match.group(1)?.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }
}

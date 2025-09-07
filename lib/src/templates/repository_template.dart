import 'shared.dart';

class RepositoryTemplate {
  static String generateRepositoryInterface(String featureName, List<ApiEndpoint> endpoints, String projectName) {
    final className = '${_toPascalCase(featureName)}Repository';
    final methods = <String>[];
    final imports = <String>{
      'package:dartz/dartz.dart',
      'package:$projectName/core/error/error.dart',
    };

    // Generate model imports
    for (final endpoint in endpoints) {
      final models = _getRequiredModels(endpoint, featureName);
      for (final model in models) {
        imports.add('package:$projectName/features/$featureName/data/model/${_toSnakeCase(model)}.dart');
      }
    }

    // Generate methods
    for (final endpoint in endpoints) {
      methods.add(_generateRepositoryMethod(endpoint, featureName));
    }

    return '''
${imports.map((i) => "import '$i';").join('\n')}

/// The contract for the $featureName repository.
/// This represent the blue print for the repository.
abstract class $className {
${methods.join('\n\n')}
}
''';
  }

  static String generateRepositoryImplementation(String featureName, List<ApiEndpoint> endpoints, String projectName) {
    final className = '${_toPascalCase(featureName)}Repository';
    final implClassName = '${className}Impl';
    final sourceClassName = '${_toPascalCase(featureName)}RemoteDataSource';
    final methods = <String>[];
    final imports = <String>{
      'package:$projectName/core/error/error.dart',
      'package:$projectName/features/$featureName/data/remote/source/${featureName}_source.dart',
      'package:$projectName/features/$featureName/domain/repository/${featureName}_repository.dart',
      'package:dartz/dartz.dart',
      'package:injectable/injectable.dart',
    };

    // Generate model imports
    for (final endpoint in endpoints) {
      final models = _getRequiredModels(endpoint, featureName);
      for (final model in models) {
        imports.add('package:$projectName/features/$featureName/data/model/${_toSnakeCase(model)}.dart');
      }
    }

    // Generate method implementations
    for (final endpoint in endpoints) {
      methods.add(_generateRepositoryMethodImpl(endpoint, featureName));
    }

    return '''
${imports.map((i) => "import '$i';").join('\n')}

@Injectable(as: $className)
class $implClassName implements $className {
  $implClassName(this.remoteDataSource);

  final $sourceClassName remoteDataSource;

${methods.join('\n\n')}
}
''';
  }

  static String _generateRepositoryMethod(ApiEndpoint endpoint, String featureName) {
    final methodName = _generateMethodName(endpoint);
    final parameters = _generateMethodParameters(endpoint, featureName);
    final returnType = _generateReturnType(endpoint, featureName);
    
    return '''  Future<Either<Error, $returnType>> $methodName($parameters);''';
  }

  static String _generateRepositoryMethodImpl(ApiEndpoint endpoint, String featureName) {
    final methodName = _generateMethodName(endpoint);
    final parameters = _generateMethodParameters(endpoint, featureName);
    final returnType = _generateReturnType(endpoint, featureName);
    final sourceCall = _generateSourceCall(endpoint, featureName);
    
    return '''  @override
  Future<Either<Error, $returnType>> $methodName($parameters) async {
    try {
      final res = await remoteDataSource.$sourceCall;
      return right(res);
    } catch (e) {
      return left(Error.customErrorType(e.toString()));
    }
  }''';
  }

  static String _generateSourceCall(ApiEndpoint endpoint, String featureName) {
    final methodName = _generateMethodName(endpoint);
    final paramNames = <String>[];
    
    // Add path parameters
    for (final param in endpoint.parameters) {
      if (param.location == 'path') {
        paramNames.add(param.name);
      }
    }
    
    // Add query parameters
    for (final param in endpoint.parameters) {
      if (param.location == 'query') {
        paramNames.add(param.name);
      }
    }
    
    // Add request body if exists
    if (endpoint.requestBody != null) {
      paramNames.add('params');
    }
    
    return '$methodName(${paramNames.join(', ')})';
  }

  static String _generateMethodParameters(ApiEndpoint endpoint, String featureName) {
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

  static String _generateReturnType(ApiEndpoint endpoint, String featureName) {
    final successResponse = endpoint.responses['200'] ?? 
                           endpoint.responses['201'] ?? 
                           endpoint.responses['204'];
    
    if (successResponse?.schema != null) {
      final responseModelName = _generateResponseModelName(endpoint, featureName);
      return responseModelName;
    }
    
    // For void operations like DELETE
    if (endpoint.method.toLowerCase() == 'delete') {
      return 'void';
    }
    
    return 'dynamic';
  }

  static String _generateMethodName(ApiEndpoint endpoint) {
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

  static Set<String> _getRequiredModels(ApiEndpoint endpoint, String featureName) {
    final models = <String>{};
    
    if (endpoint.requestBody != null) {
      models.add(_generateRequestModelName(endpoint, featureName));
    }
    
    if (endpoint.responses['200']?.schema != null || 
        endpoint.responses['201']?.schema != null) {
      models.add(_generateResponseModelName(endpoint, featureName));
    }
    
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


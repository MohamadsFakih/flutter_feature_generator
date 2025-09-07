import 'shared.dart';

class BlocTemplate {
  static String generateBloc(String featureName, List<ApiEndpoint> endpoints) {
    final className = '${_toPascalCase(featureName)}Bloc';
    final useCaseClassName = '${_toPascalCase(featureName)}UseCases';
    final eventMethods = <String>[];
    final imports = <String>{
      'dart:async',
      'package:creamati_mobile/features/$featureName/domain/usecase/${featureName}_usecase.dart',
      'package:flutter_bloc/flutter_bloc.dart',
      'package:freezed_annotation/freezed_annotation.dart',
      'package:injectable/injectable.dart',
      'package:creamati_mobile/core/error/error.dart',
    };

    // Generate model imports
    for (final endpoint in endpoints) {
      final models = _getRequiredModels(endpoint, featureName);
      for (final model in models) {
        imports.add('package:creamati_mobile/features/$featureName/data/model/${_toSnakeCase(model)}.dart');
      }
    }

    // Generate event handler methods
    for (final endpoint in endpoints) {
      eventMethods.add(_generateEventMethod(endpoint, featureName));
    }

    return '''
${imports.map((i) => "import '$i';").join('\n')}

part '${featureName}_bloc.freezed.dart';
part '${featureName}_event.dart';
part '${featureName}_state.dart';

@injectable
class $className extends Bloc<${_toPascalCase(featureName)}Event, ${_toPascalCase(featureName)}State> {
  $className(this._useCases) : super(const ${_toPascalCase(featureName)}State()) {
    on<${_toPascalCase(featureName)}Event>((event, emit) async {
      await event.when(
${_generateEventWhenCases(endpoints, featureName)}
      );
    });
  }

  final $useCaseClassName _useCases;

${eventMethods.join('\n\n')}
}
''';
  }

  static String generateEvent(String featureName, List<ApiEndpoint> endpoints) {
    final events = <String>[];
    
    for (final endpoint in endpoints) {
      events.add(_generateEventCase(endpoint, featureName));
    }

    return '''
part of '${featureName}_bloc.dart';

@freezed
class ${_toPascalCase(featureName)}Event with _\$${_toPascalCase(featureName)}Event {
${events.join('\n\n')}
}
''';
  }

  static String generateState(String featureName, List<ApiEndpoint> endpoints) {
    final stateFields = <String>[
      '@Default(false) bool isLoading',
      '@Default(Error.none()) Error error',
    ];

    // Add response fields for each endpoint
    for (final endpoint in endpoints) {
      final responseModelName = _generateResponseModelName(endpoint, featureName);
      final fieldName = _generateStateFieldName(endpoint);
      stateFields.add('@Default(null) $responseModelName? $fieldName');
    }

    return '''
part of '${featureName}_bloc.dart';

@freezed
class ${_toPascalCase(featureName)}State with _\$${_toPascalCase(featureName)}State {
  const factory ${_toPascalCase(featureName)}State({
${stateFields.map((field) => '    $field,').join('\n')}
  }) = _${_toPascalCase(featureName)}State;
}
''';
  }

  static String _generateEventWhenCases(List<ApiEndpoint> endpoints, String featureName) {
    final cases = <String>[];
    
    for (final endpoint in endpoints) {
      final eventName = _generateEventName(endpoint);
      final methodName = '_${_generateMethodName(endpoint)}';
      final params = _generateEventParams(endpoint, featureName);
      
      if (params.isNotEmpty) {
        cases.add('        $eventName: ($params) => $methodName($params, emit),');
      } else {
        cases.add('        $eventName: () => $methodName(emit),');
      }
    }
    
    return cases.join('\n');
  }

  static String _generateEventCase(ApiEndpoint endpoint, String featureName) {
    final eventName = _generateEventName(endpoint);
    final params = _generateEventCaseParams(endpoint, featureName);
    
    return '''  const factory ${_toPascalCase(featureName)}Event.$eventName($params) = $eventName;''';
  }

  static String _generateEventMethod(ApiEndpoint endpoint, String featureName) {
    final methodName = '_${_generateMethodName(endpoint)}';
    final eventParams = _generateEventMethodParams(endpoint, featureName);
    final useCaseCall = _generateUseCaseCall(endpoint, featureName);
    final stateFieldName = _generateStateFieldName(endpoint);
    
    return '''  Future $methodName($eventParams, Emitter<${_toPascalCase(featureName)}State> emit) async {
    emit(state.copyWith(isLoading: true, error: const Error.none()));
    
    final result = await _useCases.$useCaseCall;
    
    result.fold(
      (error) => emit(state.copyWith(
        isLoading: false,
        error: error,
      )),
      (response) => emit(state.copyWith(
        isLoading: false,
        $stateFieldName: response,
        error: const Error.none(),
      )),
    );
  }''';
  }

  static String _generateEventName(ApiEndpoint endpoint) {
    final methodName = _generateMethodName(endpoint);
    return '${methodName}Requested';
  }

  static String _generateEventParams(ApiEndpoint endpoint, String featureName) {
    final params = <String>[];
    
    // Add path parameters
    for (final param in endpoint.parameters) {
      if (param.location == 'path') {
        params.add('${param.type} ${param.name}');
      }
    }
    
    // Add query parameters
    for (final param in endpoint.parameters) {
      if (param.location == 'query') {
        params.add('${param.type}? ${param.name}');
      }
    }
    
    // Add request body if exists
    if (endpoint.requestBody != null) {
      final requestModelName = _generateRequestModelName(endpoint, featureName);
      params.add('$requestModelName params');
    }
    
    return params.join(', ');
  }

  static String _generateEventCaseParams(ApiEndpoint endpoint, String featureName) {
    final params = <String>[];
    
    // Add path parameters
    for (final param in endpoint.parameters) {
      if (param.location == 'path') {
        params.add('${param.type} ${param.name}');
      }
    }
    
    // Add query parameters
    for (final param in endpoint.parameters) {
      if (param.location == 'query') {
        params.add('${param.type}? ${param.name}');
      }
    }
    
    // Add request body if exists
    if (endpoint.requestBody != null) {
      final requestModelName = _generateRequestModelName(endpoint, featureName);
      params.add('$requestModelName params');
    }
    
    if (params.isEmpty) return '';
    
    return '{${params.join(', ')}}';
  }

  static String _generateEventMethodParams(ApiEndpoint endpoint, String featureName) {
    return _generateEventParams(endpoint, featureName);
  }

  static String _generateUseCaseCall(ApiEndpoint endpoint, String featureName) {
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

  static String _generateStateFieldName(ApiEndpoint endpoint) {
    final methodName = _generateMethodName(endpoint);
    return '${methodName}Response';
  }

  static String _generateReturnType(ApiEndpoint endpoint, String featureName) {
    final successResponse = endpoint.responses['200'] ?? 
                           endpoint.responses['201'] ?? 
                           endpoint.responses['204'];
    
    if (successResponse?.schema != null) {
      final responseModelName = _generateResponseModelName(endpoint, featureName);
      return responseModelName;
    }
    
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


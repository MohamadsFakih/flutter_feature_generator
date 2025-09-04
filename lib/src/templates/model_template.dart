class ModelTemplate {
  static String generateModel(String className, Map<String, dynamic>? schema) {
    if (schema == null) {
      return _generateSimpleModel(className);
    }

    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    final required = (schema['required'] as List?)?.cast<String>() ?? [];

    return '''
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part '${_toSnakeCase(className)}.freezed.dart';
part '${_toSnakeCase(className)}.g.dart';

@freezed
class $className with _\$$className {
  const factory $className({
${_generateFields(properties, required)}
  }) = _$className;

  factory $className.fromJson(Map<String, dynamic> json) =>
      _\$${className}FromJson(json);
}
''';
  }

  static String generateRequestModel(String className, Map<String, dynamic>? schema) {
    if (schema == null) {
      return _generateSimpleModel(className);
    }

    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    final required = (schema['required'] as List?)?.cast<String>() ?? [];

    return '''
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part '${_toSnakeCase(className)}.freezed.dart';
part '${_toSnakeCase(className)}.g.dart';

@freezed
class $className with _\$$className {
  const factory $className({
${_generateFields(properties, required)}
  }) = _$className;

  factory $className.fromJson(Map<String, dynamic> json) =>
      _\$${className}FromJson(json);
}
''';
  }

  static String generateResponseModel(String className, Map<String, dynamic>? schema) {
    if (schema == null) {
      return _generateSimpleResponseModel(className);
    }

    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    final required = (schema['required'] as List?)?.cast<String>() ?? [];

    return '''
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part '${_toSnakeCase(className)}.freezed.dart';
part '${_toSnakeCase(className)}.g.dart';

@freezed
class $className with _\$$className {
  const factory $className({
${_generateFields(properties, required)}
  }) = _$className;

  factory $className.fromJson(Map<String, dynamic> json) =>
      _\$${className}FromJson(json);
}
''';
  }

  static String _generateFields(Map<String, dynamic> properties, List<String> required) {
    final fields = <String>[];
    
    for (final entry in properties.entries) {
      final fieldName = entry.key;
      final fieldSchema = entry.value as Map<String, dynamic>;
      final isRequired = required.contains(fieldName);
      final dartType = _getDartType(fieldSchema);
      
      if (isRequired) {
        fields.add('    required $dartType $fieldName,');
      } else {
        final defaultValue = _getDefaultValue(dartType);
        fields.add('    @Default($defaultValue) $dartType $fieldName,');
      }
    }
    
    return fields.join('\n');
  }

  static String _getDartType(Map<String, dynamic> schema) {
    // Check for $ref first
    final ref = schema['\$ref'] as String?;
    if (ref != null) {
      // For now, treat nested references as Map<String, dynamic>
      // In a more sophisticated version, you could generate separate models
      return 'Map<String, dynamic>';
    }
    
    final type = schema['type'] as String?;
    final format = schema['format'] as String?;
    
    switch (type) {
      case 'integer':
        return 'int';
      case 'number':
        if (format == 'float') return 'double';
        return 'double';
      case 'boolean':
        return 'bool';
      case 'array':
        final items = schema['items'] as Map<String, dynamic>?;
        if (items != null) {
          final itemType = _getDartType(items);
          return 'List<$itemType>';
        }
        return 'List<dynamic>';
      case 'object':
        return 'Map<String, dynamic>';
      case 'string':
      default:
        return 'String';
    }
  }

  static String _getDefaultValue(String dartType) {
    if (dartType.startsWith('List<')) return '[]';
    if (dartType.startsWith('Map<')) return 'const {}';
    
    switch (dartType) {
      case 'int':
        return '0';
      case 'double':
        return '0.0';
      case 'bool':
        return 'false';
      case 'String':
      default:
        return '""';
    }
  }

  static String _generateSimpleModel(String className) {
    return '''
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part '${_toSnakeCase(className)}.freezed.dart';
part '${_toSnakeCase(className)}.g.dart';

@freezed
class $className with _\$$className {
  const factory $className({
    @Default("") String message,
    @Default(true) bool success,
  }) = _$className;

  factory $className.fromJson(Map<String, dynamic> json) =>
      _\$${className}FromJson(json);
}
''';
  }

  static String _generateSimpleResponseModel(String className) {
    return '''
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part '${_toSnakeCase(className)}.freezed.dart';
part '${_toSnakeCase(className)}.g.dart';

@freezed
class $className with _\$$className {
  const factory $className({
    @Default("") String message,
    @Default(true) bool success,
    @Default(null) dynamic data,
  }) = _$className;

  factory $className.fromJson(Map<String, dynamic> json) =>
      _\$${className}FromJson(json);
}
''';
  }

  static String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => '_${match.group(1)?.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }
}
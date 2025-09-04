import 'dart:io';
import 'package:path/path.dart' as path;

import '../config/generator_config.dart';
import '../models/api_endpoint.dart';

/// Manages template generation for all layers
class TemplateManager {
  final GeneratorConfig config;
  
  TemplateManager(this.config);
  
  /// Generate all files for a feature
  Future<void> generateAllFiles(String featureName, List<ApiEndpoint> endpoints) async {
    // For now, just create placeholder files
    await _generatePlaceholderFiles(featureName);
  }
  
  /// Generate placeholder files (basic implementation)
  Future<void> _generatePlaceholderFiles(String featureName) async {
    final basePath = config.getFeaturePath(featureName);
    
    // Generate basic service file
    final serviceContent = '''
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

part '${featureName}_service.g.dart';

@RestApi()
@injectable
abstract class ${_toPascalCase(featureName)}RemoteService {
  @factoryMethod
  factory ${_toPascalCase(featureName)}RemoteService(Dio dio) {
    return _${_toPascalCase(featureName)}RemoteService(dio);
  }

  // TODO: Add your API endpoints here
}
''';
    
    await File(path.join(basePath, 'data', 'remote', 'service', '${featureName}_service.dart'))
        .writeAsString(serviceContent);
    
    // Generate basic screen file
    final screenContent = '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ${_toPascalCase(featureName)}Screen extends StatelessWidget {
  const ${_toPascalCase(featureName)}Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_toTitleCase(featureName)}'),
      ),
      body: const Center(
        child: Text('${_toPascalCase(featureName)} Feature'),
      ),
    );
  }
}
''';
    
    await File(path.join(basePath, 'presentation', 'screen', '${featureName}_screen.dart'))
        .writeAsString(screenContent);
  }
  
  /// Convert snake_case to PascalCase
  String _toPascalCase(String input) {
    return input
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join('');
  }
  
  /// Convert snake_case to Title Case
  String _toTitleCase(String input) {
    return input
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}

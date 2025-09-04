class ScreenTemplate {
  static String generateScreen(String featureName) {
    final className = '${_toPascalCase(featureName)}Screen';
    final blocClassName = '${_toPascalCase(featureName)}Bloc';
    
    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:creamati_mobile/di/di_container.dart';
import 'package:creamati_mobile/features/$featureName/presentation/bloc/${featureName}_bloc.dart';

class $className extends StatelessWidget {
  const $className({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<$blocClassName>(),
      child: const _${className}View(),
    );
  }
}

class _${className}View extends StatelessWidget {
  const _${className}View();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_toTitleCase(featureName)}'),
      ),
      body: BlocBuilder<$blocClassName, ${_toPascalCase(featureName)}State>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state.error != const Error.none()) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: \${state.error}',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Add retry logic here
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green,
                ),
                SizedBox(height: 16),
                Text(
                  '${_toTitleCase(featureName)} Screen',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Feature generated successfully!',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 32),
                Text(
                  'TODO: Implement your UI here',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
''';
  }

  static String _toPascalCase(String input) {
    return input
        .split(RegExp(r'[-_\s]+'))
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join('');
  }

  static String _toTitleCase(String input) {
    return input
        .split(RegExp(r'[-_\s]+'))
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}

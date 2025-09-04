#!/usr/bin/env dart

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_feature_generator/flutter_feature_generator.dart';

void main(List<String> arguments) async {
  // Auto-detect project root
  final currentDir = Directory.current.path;
  String projectRoot = currentDir;
  
  if (path.basename(currentDir) == 'tool') {
    projectRoot = path.dirname(currentDir);
    print('📁 Detected running from tool directory, using parent as project root');
  }
  
  print('📂 Project root: $projectRoot');
  
  final generator = FeatureGenerator(projectRoot);
  
  try {
    await generator.run(arguments);
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}

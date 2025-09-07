#!/usr/bin/env dart

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_feature_generator/flutter_feature_generator.dart';
import 'package:flutter_feature_generator/src/web_server.dart';

void main(List<String> arguments) async {
  // Auto-detect project root
  final currentDir = Directory.current.path;
  String projectRoot = currentDir;
  
  if (path.basename(currentDir) == 'tool') {
    projectRoot = path.dirname(currentDir);
    print('📁 Detected running from tool directory, using parent as project root');
  }
  
  print('📂 Project root: $projectRoot');
  
  // Check for web server mode flag
  if (arguments.contains('--web') || arguments.contains('-w') || arguments.isEmpty) {
    // Start web interface
    final webServer = WebServer(projectRoot);
    
    // Handle graceful shutdown
    ProcessSignal.sigint.watch().listen((signal) async {
      print('\n🛑 Shutting down...');
      await webServer.stop();
      exit(0);
    });
    
    try {
      await webServer.start();
      
      // Keep the server running
      while (true) {
        await Future.delayed(Duration(seconds: 1));
      }
    } catch (e) {
      print('❌ Error starting web server: $e');
      exit(1);
    }
  } else {
    // Use CLI mode for command line arguments
    final generator = FeatureGenerator(projectRoot);
    
    try {
      await generator.run(arguments);
    } catch (e) {
      print('❌ Error: $e');
      exit(1);
    }
  }
}

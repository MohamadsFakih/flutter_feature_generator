import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as path;
import 'feature_generator.dart';
import 'templates/shared.dart';

class WebServer {
  final String projectRoot;
  late FeatureGenerator generator;
  late Router app;
  HttpServer? server;

  WebServer(this.projectRoot) {
    generator = FeatureGenerator(projectRoot);
    _setupRoutes();
  }

  void _setupRoutes() {
    app = Router();

    // API endpoints
    app.get('/api/endpoints', _getEndpoints);
    app.post('/api/generate', _generateFeature);
    app.get('/api/swagger/raw', _getSwaggerRaw);
    
    // Serve the main page
    app.get('/', _serveIndex);
    app.get('/<ignored|.*>', _serveIndex); // Catch all for SPA routing
  }

  /// Start the web server
  Future<void> start({int port = 8080}) async {
    try {
      // Load swagger spec first
      await generator.loadSwaggerSpec();
      
      // Start the server
      server = await shelf_io.serve(
        app,
        InternetAddress.anyIPv4,
        port,
      );
      
      print('🌐 Web interface started!');
      print('📱 Open your browser and navigate to: http://localhost:$port');
      print('🛑 Press Ctrl+C to stop the server');
      
    } catch (e) {
      print('❌ Error starting web server: $e');
      rethrow;
    }
  }

  /// Stop the web server
  Future<void> stop() async {
    await server?.close();
    print('\n🛑 Web server stopped');
  }

  /// Get all available endpoints
  Future<Response> _getEndpoints(Request request) async {
    try {
      final allEndpoints = generator.getAvailableEndpoints();
      final result = <Map<String, dynamic>>[];
      
      int index = 1;
      for (final tagEntry in allEndpoints.entries) {
        final tag = tagEntry.key;
        final endpoints = tagEntry.value;
        
        for (final endpoint in endpoints) {
          result.add({
            'index': index,
            'tag': tag,
            'method': endpoint.method.toUpperCase(),
            'path': endpoint.path,
            'summary': endpoint.summary,
            'operationId': endpoint.operationId,
            'hasRequestBody': endpoint.requestBody != null,
            'responseCount': endpoint.responses.length,
          });
          index++;
        }
      }
      
      return Response.ok(
        json.encode({'endpoints': result}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': 'Failed to load endpoints: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Generate feature from selected endpoints
  Future<Response> _generateFeature(Request request) async {
    try {
      final body = await request.readAsString();
      final data = json.decode(body) as Map<String, dynamic>;
      
      final featureName = data['featureName'] as String?;
      final selectedIndices = (data['selectedIndices'] as List?)?.cast<int>();
      final layers = data['layers'] as Map<String, dynamic>? ?? {
        'data': true,
        'domain': true,
        'presentation': true,
        'presentationComponents': {
          'bloc': true,
          'screens': true,
          'widgets': true,
        }
      };
      
      if (featureName == null || featureName.isEmpty) {
        return Response.badRequest(
          body: json.encode({'error': 'Feature name is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      if (selectedIndices == null || selectedIndices.isEmpty) {
        return Response.badRequest(
          body: json.encode({'error': 'At least one endpoint must be selected'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      if (!(layers['data'] == true || layers['domain'] == true || layers['presentation'] == true)) {
        return Response.badRequest(
          body: json.encode({'error': 'At least one layer must be selected'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Validate feature name
      if (!_isValidFeatureName(featureName)) {
        return Response.badRequest(
          body: json.encode({
            'error': 'Invalid feature name. Use snake_case (e.g., user_management)'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      // Get all endpoints and map indices to endpoints
      final allEndpoints = generator.getAvailableEndpoints();
      final indexToEndpoint = <int, ApiEndpoint>{};
      
      int index = 1;
      for (final tagEntry in allEndpoints.entries) {
        final endpoints = tagEntry.value;
        for (final endpoint in endpoints) {
          indexToEndpoint[index] = endpoint;
          index++;
        }
      }
      
      // Get selected endpoints
      final selectedEndpoints = <ApiEndpoint>[];
      for (final i in selectedIndices) {
        if (indexToEndpoint.containsKey(i)) {
          selectedEndpoints.add(indexToEndpoint[i]!);
        }
      }
      
      if (selectedEndpoints.isEmpty) {
        return Response.badRequest(
          body: json.encode({'error': 'No valid endpoints found for selected indices'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      // Check if feature already exists
      final featurePath = path.join(projectRoot, 'lib', 'features', featureName);
      final featureExists = await Directory(featurePath).exists();
      
      String message;
      if (featureExists) {
        // Append to existing feature
        await generator.generateFeatureWithLayers(featureName, selectedEndpoints, layers, append: true);
        message = 'Feature "$featureName" updated with new endpoints!';
      } else {
        // Generate new feature
        await generator.generateFeatureWithLayers(featureName, selectedEndpoints, layers, append: false);
        message = 'Feature "$featureName" generated successfully!';
      }
      
      return Response.ok(
        json.encode({
          'success': true,
          'message': message,
          'featureName': featureName,
          'endpointCount': selectedEndpoints.length,
          'location': 'lib/features/$featureName/',
          'isUpdate': featureExists,
          'generatedLayers': layers,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
      
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': 'Failed to generate feature: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Get raw swagger specification
  Future<Response> _getSwaggerRaw(Request request) async {
    try {
      return Response.ok(
        json.encode(generator.swaggerSpec),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': 'Failed to load swagger spec: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Serve the main HTML page
  Future<Response> _serveIndex(Request request) async {
    try {
      final htmlContent = _getHtmlContent();
      return Response.ok(
        htmlContent,
        headers: {'Content-Type': 'text/html'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error serving index: $e');
    }
  }

  /// Validate feature name format
  bool _isValidFeatureName(String featureName) {
    final restrictedNames = ['test', 'build', 'lib', 'android', 'ios', 'web', 'windows', 'linux', 'macos'];
    
    if (restrictedNames.contains(featureName.toLowerCase())) {
      return false;
    }
    
    return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(featureName);
  }

  /// Get the HTML content
  String _getHtmlContent() {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Flutter Feature Generator</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #2196F3 0%, #21CBF3 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
        }
        
        .header p {
            opacity: 0.9;
            font-size: 1.1rem;
        }
        
        .main-content {
            display: grid;
            grid-template-columns: 1fr 300px;
            gap: 0;
            min-height: 600px;
        }
        
        .endpoints-section {
            padding: 30px;
            border-right: 1px solid #e0e0e0;
        }
        
        .sidebar {
            background: #f8f9fa;
            padding: 30px;
        }
        
        .search-bar {
            width: 100%;
            padding: 12px 16px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            margin-bottom: 20px;
            transition: border-color 0.3s;
        }
        
        .search-bar:focus {
            outline: none;
            border-color: #2196F3;
        }
        
        .endpoints-container {
            max-height: 500px;
            overflow-y: auto;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
        }
        
        .endpoint {
            padding: 15px;
            border-bottom: 1px solid #e0e0e0;
            cursor: pointer;
            transition: background 0.2s;
        }
        
        .endpoint:hover {
            background: #f5f5f5;
        }
        
        .endpoint.selected {
            background: #e3f2fd;
            border-left: 4px solid #2196F3;
        }
        
        .endpoint-header {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 5px;
        }
        
        .method-badge {
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
            color: white;
            min-width: 60px;
            text-align: center;
        }
        
        .method-get { background: #4CAF50; }
        .method-post { background: #FF9800; }
        .method-put { background: #2196F3; }
        .method-delete { background: #f44336; }
        .method-patch { background: #9C27B0; }
        
        .endpoint-path {
            font-family: monospace;
            font-weight: 500;
            flex: 1;
        }
        
        .endpoint-tag {
            background: #e0e0e0;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 11px;
            color: #666;
        }
        
        .endpoint-summary {
            color: #666;
            font-size: 14px;
            margin-top: 5px;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #333;
        }
        
        .form-input {
            width: 100%;
            padding: 12px 16px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        
        .form-input:focus {
            outline: none;
            border-color: #2196F3;
        }
        
        .checkbox-group {
            display: flex;
            flex-direction: column;
            gap: 12px;
            margin-top: 8px;
        }
        
        .checkbox-item {
            display: flex;
            align-items: center;
            cursor: pointer;
            font-size: 14px;
            font-weight: normal;
            margin-bottom: 0;
        }
        
        .checkbox-item input[type="checkbox"] {
            margin-right: 10px;
            width: 18px;
            height: 18px;
            cursor: pointer;
        }
        
        .checkbox-item:hover {
            color: #2196F3;
        }
        
        .sub-checkbox-group {
            margin-left: 30px;
            margin-top: 8px;
            padding-left: 15px;
            border-left: 2px solid #e0e0e0;
            transition: all 0.3s ease;
        }
        
        .sub-checkbox-item {
            display: flex;
            align-items: center;
            cursor: pointer;
            font-size: 13px;
            font-weight: normal;
            margin-bottom: 8px;
            color: #666;
        }
        
        .sub-checkbox-item input[type="checkbox"] {
            margin-right: 8px;
            width: 16px;
            height: 16px;
            cursor: pointer;
        }
        
        .sub-checkbox-item:hover {
            color: #2196F3;
        }
        
        .sub-checkbox-group.disabled {
            opacity: 0.4;
            pointer-events: none;
        }
        
        .generate-btn {
            width: 100%;
            padding: 15px;
            background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .generate-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 16px rgba(76, 175, 80, 0.3);
        }
        
        .generate-btn:disabled {
            background: #ccc;
            cursor: not-allowed;
            transform: none;
            box-shadow: none;
        }
        
        .status-message {
            margin-top: 20px;
            padding: 15px;
            border-radius: 8px;
            font-weight: 500;
        }
        
        .status-success {
            background: #e8f5e8;
            color: #2e7d32;
            border: 1px solid #4caf50;
        }
        
        .status-error {
            background: #ffebee;
            color: #c62828;
            border: 1px solid #f44336;
        }
        
        .status-loading {
            background: #e3f2fd;
            color: #1976d2;
            border: 1px solid #2196f3;
        }
        
        .selection-summary {
            background: #f0f8ff;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            border: 1px solid #2196f3;
        }
        
        .selection-count {
            font-weight: 600;
            color: #1976d2;
            margin-bottom: 5px;
        }
        
        .loading-spinner {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #2196f3;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-right: 10px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .no-results {
            text-align: center;
            padding: 40px;
            color: #666;
        }
        
        @media (max-width: 768px) {
            .main-content {
                grid-template-columns: 1fr;
            }
            
            .sidebar {
                border-right: none;
                border-top: 1px solid #e0e0e0;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Flutter Feature Generator</h1>
            <p>Select APIs from your Swagger specification and generate clean architecture features</p>
        </div>
        
        <div class="main-content">
            <div class="endpoints-section">
                <input 
                    type="text" 
                    class="search-bar" 
                    placeholder="🔍 Search endpoints by path, method, or tag..."
                    id="searchInput"
                >
                
                <div class="endpoints-container" id="endpointsContainer">
                    <div class="no-results">
                        <div class="loading-spinner"></div>
                        Loading endpoints...
                    </div>
                </div>
            </div>
            
            <div class="sidebar">
                <div class="selection-summary" id="selectionSummary" style="display: none;">
                    <div class="selection-count" id="selectionCount">0 endpoints selected</div>
                    <div>Click endpoints to select/deselect them</div>
                </div>
                
                <div class="form-group">
                    <label for="featureName">Feature Name</label>
                    <input 
                        type="text" 
                        class="form-input" 
                        id="featureName" 
                        placeholder="e.g., user_management"
                        pattern="^[a-z][a-z0-9_]*\$"
                    >
                    <small style="color: #666; font-size: 12px; margin-top: 5px; display: block;">
                        Use snake_case (lowercase with underscores)
                    </small>
                </div>
                
                <div class="form-group">
                    <label>Layers to Generate</label>
                    <div class="checkbox-group">
                        <label class="checkbox-item">
                            <input type="checkbox" id="layerData" checked>
                            <span class="checkmark"></span>
                            Data Layer (Models, Services, Repository)
                        </label>
                        <label class="checkbox-item">
                            <input type="checkbox" id="layerDomain" checked>
                            <span class="checkmark"></span>
                            Domain Layer (Use Cases, Repository Interface)
                        </label>
                        <label class="checkbox-item">
                            <input type="checkbox" id="layerPresentation" checked>
                            <span class="checkmark"></span>
                            Presentation Layer
                        </label>
                        
                        <!-- Presentation Layer Sub-options -->
                        <div class="sub-checkbox-group" id="presentationSubOptions">
                            <label class="sub-checkbox-item">
                                <input type="checkbox" id="presentationBloc" checked>
                                <span class="checkmark"></span>
                                BLoC (Events, States, Business Logic)
                            </label>
                            <label class="sub-checkbox-item">
                                <input type="checkbox" id="presentationScreens" checked>
                                <span class="checkmark"></span>
                                Screens (UI Screens)
                            </label>
                            <label class="sub-checkbox-item">
                                <input type="checkbox" id="presentationWidgets" checked>
                                <span class="checkmark"></span>
                                Widgets (Custom Widgets)
                            </label>
                        </div>
                    </div>
                    <small style="color: #666; font-size: 12px; margin-top: 5px; display: block;">
                        Select which layers and components you want to generate
                    </small>
                </div>
                
                <button class="generate-btn" id="generateBtn" disabled>
                    Generate Feature
                </button>
                
                <div id="statusMessage"></div>
            </div>
        </div>
    </div>

    <script>
        let allEndpoints = [];
        let selectedEndpoints = new Set();
        
        // Load endpoints on page load
        window.addEventListener('DOMContentLoaded', loadEndpoints);
        
        // Search functionality
        document.getElementById('searchInput').addEventListener('input', filterEndpoints);
        
        // Feature name validation
        document.getElementById('featureName').addEventListener('input', validateForm);
        
        // Presentation layer checkbox interactions
        document.getElementById('layerPresentation').addEventListener('change', togglePresentationSubOptions);
        document.getElementById('presentationBloc').addEventListener('change', validateForm);
        document.getElementById('presentationScreens').addEventListener('change', validateForm);
        document.getElementById('presentationWidgets').addEventListener('change', validateForm);
        
        // Generate button
        document.getElementById('generateBtn').addEventListener('click', generateFeature);
        
        function togglePresentationSubOptions() {
            const presentationLayer = document.getElementById('layerPresentation');
            const subOptions = document.getElementById('presentationSubOptions');
            
            if (presentationLayer.checked) {
                subOptions.classList.remove('disabled');
                // Enable all sub-checkboxes
                document.getElementById('presentationBloc').disabled = false;
                document.getElementById('presentationScreens').disabled = false;
                document.getElementById('presentationWidgets').disabled = false;
            } else {
                subOptions.classList.add('disabled');
                // Disable all sub-checkboxes
                document.getElementById('presentationBloc').disabled = true;
                document.getElementById('presentationScreens').disabled = true;
                document.getElementById('presentationWidgets').disabled = true;
            }
            validateForm();
        }
        
        async function loadEndpoints() {
            try {
                const response = await fetch('/api/endpoints');
                const data = await response.json();
                
                if (data.endpoints) {
                    allEndpoints = data.endpoints;
                    renderEndpoints(allEndpoints);
                } else {
                    showError('Failed to load endpoints');
                }
            } catch (error) {
                showError('Error loading endpoints: ' + error.message);
            }
        }
        
        function renderEndpoints(endpoints) {
            const container = document.getElementById('endpointsContainer');
            
            if (endpoints.length === 0) {
                container.innerHTML = '<div class="no-results">No endpoints found</div>';
                return;
            }
            
            container.innerHTML = endpoints.map(endpoint => 
                '<div class="endpoint" data-index="' + endpoint.index + '" onclick="toggleEndpoint(' + endpoint.index + ')">' +
                    '<div class="endpoint-header">' +
                        '<span class="method-badge method-' + endpoint.method.toLowerCase() + '">' + endpoint.method + '</span>' +
                        '<span class="endpoint-path">' + endpoint.path + '</span>' +
                        '<span class="endpoint-tag">' + endpoint.tag + '</span>' +
                    '</div>' +
                    (endpoint.summary ? '<div class="endpoint-summary">' + endpoint.summary + '</div>' : '') +
                '</div>'
            ).join('');
        }
        
        function filterEndpoints() {
            const searchTerm = document.getElementById('searchInput').value.toLowerCase();
            const filtered = allEndpoints.filter(endpoint => 
                endpoint.path.toLowerCase().includes(searchTerm) ||
                endpoint.method.toLowerCase().includes(searchTerm) ||
                endpoint.tag.toLowerCase().includes(searchTerm) ||
                (endpoint.summary && endpoint.summary.toLowerCase().includes(searchTerm))
            );
            renderEndpoints(filtered);
            
            // Re-apply selection styling
            selectedEndpoints.forEach(index => {
                const element = document.querySelector('[data-index="' + index + '"]');
                if (element) element.classList.add('selected');
            });
        }
        
        function toggleEndpoint(index) {
            const element = document.querySelector('[data-index="' + index + '"]');
            
            if (selectedEndpoints.has(index)) {
                selectedEndpoints.delete(index);
                element.classList.remove('selected');
            } else {
                selectedEndpoints.add(index);
                element.classList.add('selected');
            }
            
            updateSelectionSummary();
            validateForm();
        }
        
        function updateSelectionSummary() {
            const summary = document.getElementById('selectionSummary');
            const count = document.getElementById('selectionCount');
            
            if (selectedEndpoints.size > 0) {
                summary.style.display = 'block';
                count.textContent = selectedEndpoints.size + ' endpoint' + (selectedEndpoints.size === 1 ? '' : 's') + ' selected';
            } else {
                summary.style.display = 'none';
            }
        }
        
        function validateForm() {
            const featureName = document.getElementById('featureName').value.trim();
            const generateBtn = document.getElementById('generateBtn');
            
            const isValidName = /^[a-z][a-z0-9_]*\$/.test(featureName);
            const hasSelection = selectedEndpoints.size > 0;
            
            // Check if at least one layer is selected
            const dataLayer = document.getElementById('layerData').checked;
            const domainLayer = document.getElementById('layerDomain').checked;
            const presentationLayer = document.getElementById('layerPresentation').checked;
            
            // If presentation layer is selected, check if at least one sub-component is selected
            let validPresentationSelection = true;
            if (presentationLayer) {
                const bloc = document.getElementById('presentationBloc').checked;
                const screens = document.getElementById('presentationScreens').checked;
                const widgets = document.getElementById('presentationWidgets').checked;
                validPresentationSelection = bloc || screens || widgets;
            }
            
            const hasValidLayers = (dataLayer || domainLayer || presentationLayer) && validPresentationSelection;
            
            generateBtn.disabled = !isValidName || !hasSelection || !hasValidLayers;
        }
        
        async function generateFeature() {
            const featureName = document.getElementById('featureName').value.trim();
            const selectedIndices = Array.from(selectedEndpoints);
            
            // Get selected layers
            const layers = {
                data: document.getElementById('layerData').checked,
                domain: document.getElementById('layerDomain').checked,
                presentation: document.getElementById('layerPresentation').checked,
                presentationComponents: {
                    bloc: document.getElementById('presentationBloc').checked,
                    screens: document.getElementById('presentationScreens').checked,
                    widgets: document.getElementById('presentationWidgets').checked
                }
            };
            
            if (!featureName || selectedIndices.length === 0) {
                showError('Please enter a feature name and select at least one endpoint');
                return;
            }
            
            if (!layers.data && !layers.domain && !layers.presentation) {
                showError('Please select at least one layer to generate');
                return;
            }
            
            if (layers.presentation && !layers.presentationComponents.bloc && !layers.presentationComponents.screens && !layers.presentationComponents.widgets) {
                showError('Please select at least one presentation component (BLoC, Screens, or Widgets)');
                return;
            }
            
            showLoading('Generating feature...');
            
            try {
                const response = await fetch('/api/generate', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        featureName: featureName,
                        selectedIndices: selectedIndices,
                        layers: layers
                    })
                });
                
                const result = await response.json();
                
                if (response.ok && result.success) {
                    const layerInfo = [];
                    if (result.generatedLayers.data) layerInfo.push('Data');
                    if (result.generatedLayers.domain) layerInfo.push('Domain');
                    if (result.generatedLayers.presentation) layerInfo.push('Presentation');
                    
                    const updateText = result.isUpdate ? ' (updated existing feature)' : '';
                    
                    showSuccess(
                        '✅ ' + result.message + updateText + '<br>' +
                        '📁 Location: ' + result.location + '<br>' +
                        '📊 Generated ' + result.endpointCount + ' endpoint' + (result.endpointCount === 1 ? '' : 's') + '<br>' +
                        '🏗️ Layers: ' + layerInfo.join(', ') + '<br><br>' +
                        '<strong>Next steps:</strong><br>' +
                        '1. Run "flutter packages pub run build_runner build"<br>' +
                        '2. Add the repository to your DI container<br>' +
                        '3. Import and use the generated files in your app'
                    );
                    
                    // Reset form
                    document.getElementById('featureName').value = '';
                    selectedEndpoints.clear();
                    updateSelectionSummary();
                    validateForm();
                    
                    // Remove selection styling
                    document.querySelectorAll('.endpoint.selected').forEach(el => {
                        el.classList.remove('selected');
                    });
                    
                } else {
                    showError(result.error || 'Generation failed');
                }
            } catch (error) {
                showError('Error generating feature: ' + error.message);
            }
        }
        
        function showLoading(message) {
            const statusDiv = document.getElementById('statusMessage');
            statusDiv.className = 'status-message status-loading';
            statusDiv.innerHTML = '<div class="loading-spinner"></div>' + message;
        }
        
        function showSuccess(message) {
            const statusDiv = document.getElementById('statusMessage');
            statusDiv.className = 'status-message status-success';
            statusDiv.innerHTML = message;
        }
        
        function showError(message) {
            const statusDiv = document.getElementById('statusMessage');
            statusDiv.className = 'status-message status-error';
            statusDiv.innerHTML = '❌ ' + message;
        }
    </script>
</body>
</html>
    ''';
  }
}

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.3]

### Critical Bug Fixes
- **BREAKING FIX**: Resolved hardcoded package name in all generated imports
- All generated code now uses the correct project package name instead of hardcoded references
- Fixed imports in data layer, domain layer, presentation layer, and error handling classes

## [2.0.2]

### Code Quality Improvements
- Removed dead code in feature_generator.dart that was unreachable after return statement
- Cleaned up unused imports (shelf_static in web_server.dart, direct web_server import in main)
- Removed unused shelf_static dependency from pubspec.yaml

## [2.0.1]

### Bug Fixes
- Updated documentation with proper image handling instructions for pub.dev

## [2.0.0]

### 🎉 Major Features Added
- **Interactive Web Interface**: Beautiful, modern web UI for API selection and feature generation
- **Granular Layer Control**: Choose specific layers to generate (Data, Domain, Presentation)
- **Presentation Component Selection**: Fine-grained control over BLoC, Screens, and Widgets
- **Smart Appending**: Automatically appends to existing classes instead of overwriting
- **Auto-Generated Core Files**: Automatically creates `core/error/error.dart` if missing
- **Real-time Search**: Filter APIs by path, method, tag, or description
- **Multi-Selection Interface**: Visual selection of multiple endpoints with feedback

### 🌐 Web Interface Features
- Responsive design that works on desktop and mobile
- Real-time API endpoint loading from swagger.json
- Interactive checkboxes for layer and component selection
- Search and filter functionality for large API specifications
- Visual feedback with progress indicators and status messages
- Automatic feature name validation with helpful error messages

### 🏗️ Architecture Improvements
- **Consolidated Classes**: New endpoints are added as methods to existing classes instead of creating separate classes
- **Smart Use Cases**: Adds methods to main `UseCases` class instead of creating individual use case classes
- **Freezed Integration**: Properly adds factory methods to freezed Event classes and fields to State classes
- **BLoC Enhancement**: Adds new event handlers to existing BLoC classes
- **Repository Updates**: Appends methods to existing repository interfaces and implementations
- **Source Layer Updates**: Appends methods to existing source interfaces and implementations

### 🎛️ Granular Control
- **Data Layer**: Models, Services, Repository (can be selected independently)
- **Domain Layer**: Use Cases, Repository Interface (can be selected independently)
- **Presentation Layer**: Now has sub-components:
  - BLoC (Events, States, Business Logic)
  - Screens (UI Screens)
  - Widgets (Custom Widgets folder)

### 🔄 Smart Appending Logic
- Detects existing features automatically
- Only adds new endpoints that don't already exist
- Preserves existing code structure and formatting
- Adds required imports automatically
- Maintains consistent code patterns

### 🚀 Enhanced User Experience
- Layer selection with visual hierarchy
- Presentation sub-component controls
- Real-time validation feedback
- Detailed success messages showing what was generated/updated
- Clear error messages with helpful guidance

### 📦 Technical Improvements
- Auto-generation of core Error class with freezed unions for functional error handling
- Improved error handling and user feedback
- Better code organization with separation of concerns
- Enhanced CLI backward compatibility
- Comprehensive documentation of required dependencies

### 🐛 Bug Fixes
- Improved file path handling across different operating systems
- Better error messages for invalid feature names and selections
- Fixed duplicate endpoint detection logic

### 💔 Breaking Changes
- Default behavior now starts web interface instead of CLI (use specific arguments for CLI mode)
- Minimum Dart SDK version remains 3.0.0
- Generated code structure remains the same, but appending logic is significantly improved

## [1.0.7]
### Added
- Improved error handling for Windows PowerShell input issues
- Better debug output for troubleshooting input problems
- Enhanced user guidance with example commands

### Fixed
- Windows PowerShell stdin reading issues
- Input buffer clearing problems
- Improved cross-platform input handling

## [1.0.0]

### Added
- Initial release of Flutter Feature Generator
- Interactive API endpoint selection from Swagger/OpenAPI specs
- Clean architecture feature generation
- Name validation to prevent conflicts with reserved names
- Support for append mode to add APIs to existing features
- Command line interface with configurable options
- Automatic project root detection when running from tool directory

### Features
- Generate complete feature structure following clean architecture
- Parse OpenAPI/Swagger specifications
- Create data, domain, and presentation layers
- Generate models, services, repositories, use cases, and BLoCs
- Prevent naming conflicts with restricted folder names
- Cross-platform support (Windows, macOS, Linux)

### Technical
- Built with Dart 3.0+
- Uses path package for cross-platform file operations
- Args package for command line argument parsing
- Proper error handling and user feedback
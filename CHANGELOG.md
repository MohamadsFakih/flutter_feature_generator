# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-XX

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

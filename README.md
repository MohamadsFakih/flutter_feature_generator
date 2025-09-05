# Flutter Feature Generator

A powerful code generator for creating clean architecture features in Flutter projects from OpenAPI/Swagger specifications.

## Features

- 🏗️ **Clean Architecture**: Generates complete feature structure following clean architecture principles
- 📄 **Swagger Integration**: Automatically parses OpenAPI/Swagger specifications
- 🔒 **Name Validation**: Prevents conflicts with reserved folder names like "test", "build", etc.
- 🎯 **Interactive Selection**: Choose which API endpoints to include in your feature
- 📁 **Flexible Structure**: Configurable project structure and paths
- 🔄 **Append Mode**: Add new APIs to existing features without overwriting

## Installation

### Global Installation (Recommended)

```bash
dart pub global activate flutter_feature_generator
```

### Local Installation

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_feature_generator: ^1.0.7
```

Then run:

```bash
dart pub get
```

## Usage

### Command Line

```bash
# Run in your Flutter project root
flutter_feature_generator

# Specify custom paths
flutter_feature_generator --project-root /path/to/project --swagger-file api-spec.yaml

# Show help
flutter_feature_generator --help
```

### Options

- `--project-root` (`-p`): Path to the Flutter project root (default: current directory)
- `--swagger-file` (`-s`): Path to the Swagger/OpenAPI specification file (default: `swagger.json`)
- `--features-path` (`-f`): Path to the features directory relative to project root (default: `lib/features`)
- `--help` (`-h`): Show usage information

### Project Structure

The generator creates features following this structure:

```
lib/features/your_feature/
├── data/
│   ├── model/
│   │   ├── request_model.dart
│   │   └── response_model.dart
│   ├── remote/
│   │   ├── service/
│   │   │   └── your_feature_service.dart
│   │   └── source/
│   │       ├── your_feature_source.dart
│   │       └── your_feature_source_impl.dart
│   └── repository/
│       └── your_feature_repository_impl.dart
├── domain/
│   ├── repository/
│   │   └── your_feature_repository.dart
│   └── usecase/
│       └── your_feature_usecase.dart
└── presentation/
    ├── bloc/
    │   ├── your_feature_bloc.dart
    │   ├── your_feature_event.dart
    │   └── your_feature_state.dart
    ├── screen/
    │   └── your_feature_screen.dart
    └── widget/
```

## Requirements

- Dart SDK: >=3.0.0 <4.0.0
- A `swagger.json` or OpenAPI specification file in your project root
- Flutter project with standard structure

## Configuration

### Swagger/OpenAPI File

Place your API specification file (`swagger.json` or `openapi.yaml`) in your project root, or specify a custom path using the `--swagger-file` option.

### Restricted Names

The following names are restricted to prevent conflicts:
- `test`
- `build` 
- `lib`
- `android`
- `ios`
- `web`
- `windows`
- `linux`
- `macos`

## Examples

### Basic Usage

1. Place your `swagger.json` in your Flutter project root
2. Run the generator:
   ```bash
   flutter_feature_generator
   ```
3. Select the API endpoints you want to include
4. Enter a feature name (e.g., `user_management`)
5. Choose whether to create new or append to existing feature

### Custom Configuration

```bash
flutter_feature_generator \\
  --project-root /path/to/my/flutter/app \\
  --swagger-file docs/api-specification.yaml \\
  --features-path lib/modules
```

## Generated Files

After running the generator, you'll need to:

1. **Generate build files**:
   ```bash
   dart run build_runner build
   ```

2. **Add to dependency injection**: Register your repository and BLoC in your DI container

3. **Use in your app**: Import and use the generated BLoC in your screens

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes in each version.

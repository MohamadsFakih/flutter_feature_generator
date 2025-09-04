/// Represents an API endpoint from the Swagger specification
class ApiEndpoint {
  final String path;
  final String method;
  final String summary;
  final String? operationId;
  final List<Parameter> parameters;
  final RequestBody? requestBody;
  final Map<String, ResponseDef> responses;

  ApiEndpoint({
    required this.path,
    required this.method,
    required this.summary,
    this.operationId,
    required this.parameters,
    this.requestBody,
    required this.responses,
  });
}

/// Represents a parameter in an API endpoint
class Parameter {
  final String name;
  final String location; // 'path', 'query', 'header', 'body'
  final bool required;
  final String type;
  final String? description;

  Parameter({
    required this.name,
    required this.location,
    this.required = false,
    required this.type,
    this.description,
  });
}

/// Represents a request body
class RequestBody {
  final bool required;
  final Map<String, dynamic>? schema;

  RequestBody({
    this.required = false,
    this.schema,
  });
}

/// Represents a response definition
class ResponseDef {
  final String description;
  final Map<String, dynamic>? schema;

  ResponseDef({
    required this.description,
    this.schema,
  });
}

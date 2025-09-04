// Shared classes for the feature generator

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

class Parameter {
  final String name;
  final String location; // query, path, header, etc.
  final bool required;
  final String type;
  final String? description;

  Parameter({
    required this.name,
    required this.location,
    required this.required,
    required this.type,
    this.description,
  });
}

class RequestBody {
  final bool required;
  final Map<String, dynamic>? schema;

  RequestBody({
    required this.required,
    this.schema,
  });
}

class ResponseDef {
  final String description;
  final Map<String, dynamic>? schema;

  ResponseDef({
    required this.description,
    this.schema,
  });
}
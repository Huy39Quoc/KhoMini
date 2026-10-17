class PagedResult<T> {
  final List<T> content;
  final int page;
  final bool last;

  const PagedResult({required this.content, required this.page, required this.last});

  factory PagedResult.fromApi(dynamic body, T Function(dynamic) parse) {
    final data = body is Map ? body['data'] : null;
    if (data is! Map || data['content'] is! List || data['last'] is! bool) {
      throw const FormatException('Invalid paginated response');
    }
    return PagedResult(
      content: (data['content'] as List).map(parse).toList(),
      page: (data['page'] as num?)?.toInt() ?? 0,
      last: data['last'] as bool,
    );
  }
}

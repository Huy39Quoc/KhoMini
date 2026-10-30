import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/notification_model.dart';
import '../models/paged_result.dart';

class NotificationApiService {
  final HttpClient _http = HttpClient.instance;

  Future<PagedResult<NotificationModel>> getNotifications({
    bool? unreadOnly,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'size': size,
      };
      if (unreadOnly != null) {
        query['unreadOnly'] = unreadOnly;
      }
      final response = await _http.get(
        ApiEndpoints.notifications,
        queryParameters: query,
      );
      return PagedResult.fromApi(
        response.data,
        (item) => NotificationModel.fromJson(Map<String, dynamic>.from(item as Map)),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _http.get(ApiEndpoints.notificationUnreadCount);
      final data = response.data is Map ? response.data['data'] : null;
      if (data is Map && data['unreadCount'] != null) {
        return (data['unreadCount'] as num).toInt();
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAsRead(String id) async {
    await _http.put(ApiEndpoints.notificationRead(id));
  }

  Future<void> markAllAsRead() async {
    await _http.put(ApiEndpoints.notificationReadAll);
  }
}

class ApiEndpoints {
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';

  // Storage
  static const String myUnits = '/customer/storage/my-units';
  static String smartAccess(String unitId) =>
      '/customer/storage/units/$unitId/access';
  static String updatePin(String unitId) =>
      '/customer/storage/units/$unitId/pin';
  static String extendRental(String contractId) =>
      '/customer/storage/contracts/$contractId/extend';
  static String checkoutRental(String contractId) =>
      '/customer/storage/contracts/$contractId/checkout';

  // Tickets
  static const String tickets = '/customer/tickets';
  static String ticketDetail(String ticketId) => '/customer/tickets/$ticketId';

  // Admin & Users
  static const String users = '/users';
  static String userRole(String userId) => '/users/$userId';
}

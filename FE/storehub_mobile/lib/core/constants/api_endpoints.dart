class ApiEndpoints {
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String changePassword = '/auth/change-password';

  // Storage
  static const String myUnits = '/customer/storage/my-units';
  static String smartAccess(String bookingId) =>
      '/customer/storage/$bookingId/access';
  static String updatePin(String bookingId) =>
      '/customer/storage/$bookingId/access/pin';
  static String extendRental(String bookingId) =>
      '/customer/storage/$bookingId/extend';
  static String checkoutRental(String bookingId) =>
      '/customer/storage/$bookingId/checkout';

  // Tickets
  static const String tickets = '/customer/tickets';
  static String ticketDetail(String ticketId) => '/customer/tickets/$ticketId';

  // Admin & Users
  static const String users = '/users';
  static String userDetail(String userId) => '/users/$userId';
  static String toggleUserActive(String userId) =>
      '/users/$userId/toggle-active';

  // Catalog & Pricing
  static const String catalogOverview = '/catalog/overview';
  static const String facilities = '/catalog/facilities';
  static const String unitTypes = '/catalog/unit-types';
  static const String pricingQuote = '/pricing/quote';
}

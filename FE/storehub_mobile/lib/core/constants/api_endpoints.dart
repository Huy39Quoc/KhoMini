class ApiEndpoints {
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  // --- PHÂN KHU 1: AUTHENTICATION ---
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';

  // --- PHÂN KHU 2: THÀNH VIÊN 1 (ADMIN & OPERATIONS) ---
  static const String users = '$baseUrl/users';
  static String userRole(String userId) => '$baseUrl/users/$userId/role';
  static const String roles = '$baseUrl/roles';

  // --- PHÂN KHU 3: THÀNH VIÊN 3 (ACTIVE STORAGE & SMART KEY) ---
  static const String myUnits = '$baseUrl/customer/my-units';
  static String smartAccess(String bookingId) =>
      '$baseUrl/customer/my-units/$bookingId/access';
  static String updatePin(String bookingId) =>
      '$baseUrl/customer/my-units/$bookingId/access/pin';
  static String extendRental(String bookingId) =>
      '$baseUrl/customer/my-units/$bookingId/extend';
  static String requestCheckout(String bookingId) =>
      '$baseUrl/customer/my-units/$bookingId/checkout';

  // --- PHÂN KHU 4: THÀNH VIÊN 3 (SUPPORT TICKETS) ---
  static const String tickets = '$baseUrl/customer/tickets';
  static String ticketDetail(String ticketId) =>
      '$baseUrl/customer/tickets/$ticketId';
}

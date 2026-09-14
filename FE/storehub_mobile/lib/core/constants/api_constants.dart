class ApiConstants {
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  // Auth (AuthController)
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';

  // User & Roles (UserController, RoleController)
  static const String users = '$baseUrl/users';
  static const String roles = '$baseUrl/roles';

  // Storage & Smart Access (CustomerStorageController)
  static const String myUnits = '$baseUrl/customer/my-units';
  static String smartAccess(int bookingId) =>
      '$baseUrl/customer/my-units/$bookingId/access';
  static String updatePin(int bookingId) =>
      '$baseUrl/customer/my-units/$bookingId/access/pin';
  static String extendRental(int bookingId) =>
      '$baseUrl/customer/my-units/$bookingId/extend';
  static String requestCheckout(int bookingId) =>
      '$baseUrl/customer/my-units/$bookingId/checkout';

  // Tickets (CustomerTicketController)
  static const String tickets = '$baseUrl/customer/tickets';
  static String ticketDetail(String ticketId) =>
      '$baseUrl/customer/tickets/$ticketId';
}

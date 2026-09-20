class ApiEndpoints {
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  // ---- Auth (AuthController) ----
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String changePassword = '/auth/change-password';

  // ---- Customer Storage (CustomerStorageController) ----
  static const String myUnits = '/customer/storage/my-units';
  static String smartAccess(String bookingId) =>
      '/customer/storage/$bookingId/access';
  static String updatePin(String bookingId) =>
      '/customer/storage/$bookingId/access/pin';
  static String extendRental(String bookingId) =>
      '/customer/storage/$bookingId/extend';
  static String checkoutRental(String bookingId) =>
      '/customer/storage/$bookingId/checkout';

  // ---- Customer Tickets (CustomerTicketController) ----
  static const String tickets = '/customer/tickets';
  static String ticketDetail(String ticketId) => '/customer/tickets/$ticketId';

  // ---- Users (UserController) ----
  static const String users = '/users';
  static String userDetail(String userId) => '/users/$userId';
  static String toggleUserActive(String userId) =>
      '/users/$userId/toggle-active';

  // ---- Roles (RoleController) ----
  static const String roles = '/roles';
  static String roleDetail(String roleId) => '/roles/$roleId';

  // ---- Permissions (PermissionController) ----
  static const String permissions = '/permissions';
  static String permissionDetail(String permissionId) =>
      '/permissions/$permissionId';

  // ---- Role <-> Permission assignments (RolePermissionController) ----
  static const String rolePermissions = '/role-permissions';
  static String rolePermissionDetail(String rolePermissionId) =>
      '/role-permissions/$rolePermissionId';
  static const String rolePermissionsBulkAssign =
      '/role-permissions/bulk-assign';
  static String rolePermissionsByRole(String roleId) =>
      '/role-permissions/by-role/$roleId';

  // ---- Catalog (CatalogController) ----
  static const String catalogOverview = '/catalog/overview';
  static const String facilities = '/catalog/facilities';
  static const String unitTypes = '/catalog/unit-types';

  // ---- Pricing (PricingController) ----
  static const String pricingQuote = '/pricing/quote';

  // ---- Bookings (BookingController) ----
  static const String bookings = '/bookings';

  // ---- Payments (PaymentController) ----
  static const String paymentInitiate = '/payments/initiate';
  static const String paymentConfirm = '/payments/confirm';
}

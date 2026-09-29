/// All backend endpoints, relative to [baseUrl]. Kept 1:1 with the
/// @RequestMapping / @GetMapping / @PostMapping paths declared in the
/// Spring Boot controllers under BE/StoreHub/src/main/java/com/storehub/controller.
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
  static String bookingDetail(String id) => '/bookings/$id';

  // ---- Waitlist (WaitlistController) ----
  static const String waitlist = '/waitlist';

  // ---- Payments (PaymentController) ----
  static const String paymentInitiate = '/payments/initiate';
  static const String paymentConfirm = '/payments/confirm';

  // ---- Facilities (FacilityController) ----
  static const String facilitiesAdmin = '/facilities';
  static String facilityDetail(String id) => '/facilities/$id';

  // ---- Facility Policies (FacilityPolicyController) ----
  static const String facilityPolicies = '/facility-policies';
  static String facilityPolicyDetail(String id) => '/facility-policies/$id';
  static String facilityPolicyByFacility(String facilityId) =>
      '/facility-policies/by-facility/$facilityId';

  // ---- Reports (ReportController) ----
  static const String reportRevenue = '/reports/revenue';
  static const String reportOccupancy = '/reports/occupancy';

  // ---- Activity Log (ActivityLogController) ----
  static const String activityLogs = '/activity-logs';
  static String activityLogDetail(String id) => '/activity-logs/$id';
  static const String activityLogLoginHistory = '/activity-logs/login-history';

  // ---- Facility Management (FacilityManagementController) - Facility Manager ----
  static const String myFacility = '/facility/management/my-facility';
  static String facilityUnits(String facilityId) =>
      '/facility/management/$facilityId/units';
  static String facilityUnitDetail(String facilityId, String unitId) =>
      '/facility/management/$facilityId/units/$unitId';
  static String facilityAssignUnit(String facilityId, String bookingId, String unitId) =>
      '/facility/management/$facilityId/bookings/$bookingId/unit/$unitId';
  static String facilityManagerReport(String facilityId) =>
      '/facility/management/$facilityId/report';
  static String facilityStaffList(String facilityId) =>
      '/facility/management/$facilityId/staff';
  static String facilityAssignStaff(String facilityId, String userId) =>
      '/facility/management/$facilityId/staff/$userId';
  static String facilityAssignManager(String facilityId, String userId) =>
      '/facility/management/$facilityId/managers/$userId';

  // ---- Facility Operations (FacilityOperationsController) - Facility Staff ----
  static const String dailySchedule = '/facility/operations/daily-schedule';
  static String checkIn(String bookingId) => '/facility/operations/$bookingId/check-in';
  static String checkOut(String bookingId) => '/facility/operations/$bookingId/check-out';
  static String updateUnitStatus(String unitId) =>
      '/facility/operations/units/$unitId/status';
}

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../admin/admin_dashboard_screen.dart';
import '../operations/operations_dashboard_screen.dart';
import '../customer/customer_home_screen.dart';
import '../staff/staff_dashboard_screen.dart';
import '../manager/manager_dashboard_screen.dart';

class RoleDispatchScreen extends StatelessWidget {
  final UserModel user;

  const RoleDispatchScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final role = user.role.toUpperCase().replaceAll('ROLE_', '');

    // Real role names as seeded on the BE (db/migration/V2__seed_roles.sql):
    // ADMIN, FACILITY_MANAGER, BUSINESS_MANAGER, STAFF, CUSTOMER.
    // The extra aliases below are kept just in case a differently-named
    // role is ever added on the BE side without updating this screen.
    if (role == 'ADMIN' || role == 'SYSTEM_ADMIN') {
      return const AdminDashboardScreen();
    } else if (role == 'BUSINESS_MANAGER' ||
        role == 'BUSINESS_OPERATIONS_MANAGER' ||
        role == 'OPERATIONS_MANAGER') {
      return const OperationsDashboardScreen();
    } else if (role == 'FACILITY_MANAGER') {
      return const ManagerDashboardScreen();
    } else if (role == 'FACILITY_STAFF' || role == 'STAFF') {
      return const StaffDashboardScreen();
    } else {
      return CustomerHomeScreen(user: user);
    }
  }
}

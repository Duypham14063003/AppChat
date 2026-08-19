const hrManagerRoleId = '4a5ce6f3-25e9-462a-b161-439a6a4e3e99';
const employeeManagementRoleIds = <String>{
  '4a5ce6f3-25e9-462a-b161-439a6a4e3e99',
};

bool canApproveLeavesForRoles(List<String> roles) {
  return roles.contains('admin') ||
      roles.contains('manager') ||
      roles.contains(hrManagerRoleId);
}

bool canManageEmployeesForRoles(List<String> roles) {
  return roles.contains('admin') ||
      roles.contains('manager') ||
      roles.any(employeeManagementRoleIds.contains);
}

bool canViewEmployeeAttendanceForRoles(List<String> roles) {
  return canManageEmployeesForRoles(roles);
}

bool canEditOwnHrProfileForRoles(List<String> roles) {
  return roles.isNotEmpty;
}

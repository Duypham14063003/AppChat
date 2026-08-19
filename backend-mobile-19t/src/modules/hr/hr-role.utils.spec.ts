import {
  HR_MANAGER_ROLE_ID,
  canManageEmployeeRoles,
  canViewEmployeeAttendanceRoles,
} from './hr-role.utils';

describe('HR employee role predicates', () => {
  it.each(['admin', 'manager', HR_MANAGER_ROLE_ID])(
    'allows %s to manage employees and view attendance',
    (role) => {
      expect(canManageEmployeeRoles([role])).toBe(true);
      expect(canViewEmployeeAttendanceRoles([role])).toBe(true);
    },
  );

  it('rejects regular employees', () => {
    expect(canManageEmployeeRoles(['employee'])).toBe(false);
    expect(canViewEmployeeAttendanceRoles(['employee'])).toBe(false);
  });

  it('rejects roles outside the configured HR authorization matrix', () => {
    const employeeManagerRoleId = '80c32170-fcea-494d-8c40-54bfcfad32ec';
    expect(canManageEmployeeRoles([employeeManagerRoleId])).toBe(false);
    expect(canViewEmployeeAttendanceRoles([employeeManagerRoleId])).toBe(false);
  });
});

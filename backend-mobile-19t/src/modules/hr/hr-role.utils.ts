export const HR_MANAGER_ROLE_ID = '4a5ce6f3-25e9-462a-b161-439a6a4e3e99';

export const EMPLOYEE_MANAGEMENT_ROLES = [
  'admin',
  'manager',
  HR_MANAGER_ROLE_ID,
] as const;

export const SUPPORTED_VIETQR_BANK_CODES = new Set([
  'ICB',
  'VCB',
  'BIDV',
  'VBA',
  'OCB',
  'MB',
  'TCB',
  'ACB',
  'VPB',
  'TPB',
  'STB',
  'HDB',
  'VIB',
  'SHB',
  'EIB',
  'MSB',
  'SCB',
  'ABB',
  'BAB',
  'PVCB',
  'NCB',
  'SHBVN',
  'VAB',
  'NAB',
  'PGB',
  'VIETBANK',
  'BVB',
  'SEAB',
  'LPB',
  'KLB',
  'COOPBANK',
  'SGICB',
  'MBV',
  'WVN',
]);

const HR_LEAVE_APPROVER_ROLES = new Set([
  'admin',
  'manager',
  HR_MANAGER_ROLE_ID,
]);
const HR_EMPLOYEE_MANAGEMENT_ROLES = new Set<string>(EMPLOYEE_MANAGEMENT_ROLES);

export function canApproveLeaveRoles(roles?: string[] | null): boolean {
  return (roles ?? []).some((role) => HR_LEAVE_APPROVER_ROLES.has(role));
}

export function canManageEmployeeRoles(roles?: string[] | null): boolean {
  return (roles ?? []).some((role) => HR_EMPLOYEE_MANAGEMENT_ROLES.has(role));
}

export const canViewEmployeeAttendanceRoles = canManageEmployeeRoles;

export function matchesManagerRole(role?: string | null): boolean {
  return role === 'manager' || role === HR_MANAGER_ROLE_ID;
}

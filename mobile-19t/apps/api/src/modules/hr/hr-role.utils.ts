export const HR_MANAGER_ROLE_ID = '4a5ce6f3-25e9-462a-b161-439a6a4e3e99';

const HR_LEAVE_APPROVER_ROLES = new Set(['admin', 'manager', HR_MANAGER_ROLE_ID]);

export function canApproveLeaveRoles(roles?: string[] | null): boolean {
  return (roles ?? []).some((role) => HR_LEAVE_APPROVER_ROLES.has(role));
}

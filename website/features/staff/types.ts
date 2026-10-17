export const STAFF_STATUSES = ["ACTIVE", "INVITED", "SUSPENDED"] as const;
export type StaffStatus = (typeof STAFF_STATUSES)[number];

export type StaffListItem = {
  name: string;
  email: string;
  letters: string;
  role: string;
  scope: string;
  status: StaffStatus;
  seen: string;
  selected: boolean;
};

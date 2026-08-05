import { apiRequest } from "./api-client";
import type {
  AdminFeedbackRow,
  AdminListResponse,
  AdminMe,
  AdminOverview,
  AdminProjectDetail,
  AdminProjectRow,
  AdminTestSwap,
  AdminUserDetail,
  AdminUserRow,
} from "./admin-types";

type ListParams = {
  token: string;
  q?: string;
  status?: string;
  limit?: number;
  offset?: number;
};

function listQuery({ q, status, limit = 50, offset = 0 }: Omit<ListParams, "token">) {
  const params = new URLSearchParams();
  params.set("limit", String(limit));
  params.set("offset", String(offset));
  if (q?.trim()) params.set("q", q.trim());
  if (status?.trim()) params.set("status", status.trim());
  return params.toString();
}

export function fetchAdminMe(token: string) {
  return apiRequest<AdminMe>("/v1/admin/me", { token });
}

export function fetchAdminOverview(token: string) {
  return apiRequest<AdminOverview>("/v1/admin/overview", { token });
}

export function fetchAdminUsers(params: ListParams) {
  return apiRequest<AdminListResponse<AdminUserRow>>(
    `/v1/admin/users?${listQuery(params)}`,
    { token: params.token },
  );
}

export function fetchAdminUser(token: string, id: string) {
  return apiRequest<AdminUserDetail>(`/v1/admin/users/${id}`, { token });
}

export function fetchAdminProjects(params: ListParams) {
  return apiRequest<AdminListResponse<AdminProjectRow>>(
    `/v1/admin/projects?${listQuery(params)}`,
    { token: params.token },
  );
}

export function fetchAdminProject(token: string, id: string) {
  return apiRequest<AdminProjectDetail>(`/v1/admin/projects/${id}`, { token });
}

export function fetchAdminFeedback(params: ListParams) {
  return apiRequest<AdminListResponse<AdminFeedbackRow>>(
    `/v1/admin/feedback?${listQuery(params)}`,
    { token: params.token },
  );
}

export function fetchAdminSwaps(params: ListParams) {
  return apiRequest<AdminListResponse<AdminTestSwap>>(
    `/v1/admin/swaps?${listQuery(params)}`,
    { token: params.token },
  );
}

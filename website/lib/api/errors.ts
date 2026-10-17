export type ApiErrorCode =
  | "NETWORK"
  | "UNAUTHORIZED"
  | "FORBIDDEN"
  | "NOT_FOUND"
  | "CONFLICT"
  | "VALIDATION"
  | "RATE_LIMITED"
  | "SERVER"
  | "UNKNOWN";

export class ApiError extends Error {
  readonly code: ApiErrorCode;
  readonly status: number;
  readonly details?: unknown;

  constructor(
    message: string,
    options: { code: ApiErrorCode; status: number; details?: unknown },
  ) {
    super(message);
    this.name = "ApiError";
    this.code = options.code;
    this.status = options.status;
    this.details = options.details;
  }
}

export function isForbiddenError(error: unknown): boolean {
  return error instanceof ApiError && error.code === "FORBIDDEN";
}

export function apiErrorFromStatus(
  status: number,
  message: string,
  details?: unknown,
): ApiError {
  if (status === 401) {
    return new ApiError(message, { code: "UNAUTHORIZED", status, details });
  }
  if (status === 403) {
    return new ApiError(message, { code: "FORBIDDEN", status, details });
  }
  if (status === 404) {
    return new ApiError(message, { code: "NOT_FOUND", status, details });
  }
  if (status === 409) {
    return new ApiError(message, { code: "CONFLICT", status, details });
  }
  if (status === 422) {
    return new ApiError(message, { code: "VALIDATION", status, details });
  }
  if (status === 429) {
    return new ApiError(message, { code: "RATE_LIMITED", status, details });
  }
  if (status >= 500) {
    return new ApiError(message, { code: "SERVER", status, details });
  }
  return new ApiError(message, { code: "UNKNOWN", status, details });
}

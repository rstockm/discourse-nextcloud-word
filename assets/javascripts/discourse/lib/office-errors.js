import { i18n } from "discourse-i18n";

// Codes the dialog can explain itself. Anything else falls back to the
// server message, so the client never invents text for an unknown failure.
const CLIENT_ERROR_CODES = [
  "operation_unknown",
  "operation_conflict",
  "operation_failed",
  "operation_unavailable",
  "rate_limited",
  "too_many_concurrent",
  "file_too_large",
  "unsupported_file_type",
  "invalid_file_name",
  "invalid_share_password",
  "not_configured",
];

export function officeErrorMessage(
  error,
  fallbackKey = "nextcloud_office.retry"
) {
  const body = error?.jqXHR?.responseJSON;
  if (CLIENT_ERROR_CODES.includes(body?.error_code)) {
    return i18n(`nextcloud_office.errors.${body.error_code}`);
  }
  return body?.error || i18n(fallbackKey);
}

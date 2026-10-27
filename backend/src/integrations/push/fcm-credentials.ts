import { existsSync, readFileSync } from 'node:fs';
import { isAbsolute, resolve } from 'node:path';
import {
  normalizeFcmPrivateKey,
  type FcmCredentials,
} from './fcm-push-sender.js';

export type FcmCredentialSource = {
  projectId?: string;
  clientEmail?: string;
  privateKey?: string;
  serviceAccountPath?: string;
  googleApplicationCredentials?: string;
};

/**
 * Prefer explicit FCM_* fields. Otherwise load project_id / client_email / private_key
 * from a Google service-account JSON via FCM_SERVICE_ACCOUNT_PATH or
 * GOOGLE_APPLICATION_CREDENTIALS (relative paths resolve from process.cwd()).
 */
export function resolveFcmCredentials(
  source: FcmCredentialSource,
): FcmCredentials | null {
  const fromEnv = credentialsFromFields(source);
  if (fromEnv) {
    return fromEnv;
  }

  const pathHint =
    blank(source.serviceAccountPath) ??
    blank(source.googleApplicationCredentials);
  if (!pathHint) {
    return null;
  }

  return credentialsFromServiceAccountFile(resolveCredentialPath(pathHint));
}

export function credentialsFromServiceAccountFile(
  absolutePath: string,
): FcmCredentials | null {
  if (!existsSync(absolutePath)) {
    return null;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(readFileSync(absolutePath, 'utf8')) as unknown;
  } catch {
    return null;
  }

  if (!parsed || typeof parsed !== 'object') {
    return null;
  }

  const record = parsed as Record<string, unknown>;
  const projectId =
    typeof record.project_id === 'string' ? record.project_id.trim() : '';
  const clientEmail =
    typeof record.client_email === 'string' ? record.client_email.trim() : '';
  // Do not trim PEM: trailing newlines are part of typical service-account JSON.
  const privateKey =
    typeof record.private_key === 'string' ? record.private_key : '';

  if (!projectId || !clientEmail || !privateKey.trim()) {
    return null;
  }

  return {
    projectId,
    clientEmail,
    privateKey: normalizeFcmPrivateKey(privateKey),
  };
}

function credentialsFromFields(
  source: FcmCredentialSource,
): FcmCredentials | null {
  const projectId = blank(source.projectId);
  const clientEmail = blank(source.clientEmail);
  const privateKey = pemField(source.privateKey);
  if (!projectId || !clientEmail || !privateKey) {
    return null;
  }
  return {
    projectId,
    clientEmail,
    privateKey: normalizeFcmPrivateKey(privateKey),
  };
}

function resolveCredentialPath(pathHint: string): string {
  return isAbsolute(pathHint) ? pathHint : resolve(process.cwd(), pathHint);
}

function blank(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed === '' ? undefined : trimmed;
}

function pemField(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined;
  }
  return value.trim() === '' ? undefined : value;
}

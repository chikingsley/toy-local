import type { Env } from "../bindings";
import { newId } from "../lib/ids";
import { newSecret, sha256Hex } from "./crypto";

export interface AuthSession {
  activationId: string | null;
  credentialId: string;
  email: string;
  userId: string;
}

interface UserRow {
  email: string;
  id: string;
}

interface LicenseRow {
  email: string;
  expires_at: string | null;
  id: string;
  max_activations: number;
  status: string;
  user_id: string | null;
}

interface ActivationRow {
  id: string;
  status: string;
}

interface CredentialRow {
  activation_id: string | null;
  credential_id: string;
  credential_status: string;
  email: string;
  license_status: string | null;
  user_id: string;
}

const nowIso = (): string => new Date().toISOString();

const bearerPattern = /^Bearer\s+(.+)$/i;

const normalizeEmail = (email: string): string => email.trim().toLowerCase();

const requireActiveStatus = (status: string, label: string): void => {
  if (status !== "active" && status !== "issued") {
    throw new Error(`${label} is ${status}`);
  }
};

const ensureUser = async (
  env: Env,
  input: { displayName?: string | null; email: string }
): Promise<UserRow> => {
  const email = normalizeEmail(input.email);
  const existing = await env.DB.prepare(
    "SELECT id, email FROM users WHERE email = ?"
  )
    .bind(email)
    .first<UserRow>();
  if (existing) {
    return existing;
  }

  const id = newId("usr");
  const now = nowIso();
  await env.DB.prepare(
    `INSERT INTO users (id, email, display_name, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?)`
  )
    .bind(id, email, input.displayName ?? null, now, now)
    .run();
  return { email, id };
};

export const createLicense = async (
  env: Env,
  input: {
    displayName?: string | null;
    email: string;
    expiresAt?: string | null;
    maxActivations?: number;
    notes?: string | null;
  }
): Promise<{
  email: string;
  licenseId: string;
  licenseKey: string;
  maxActivations: number;
  status: string;
  userId: string;
}> => {
  const user = await ensureUser(env, {
    displayName: input.displayName,
    email: input.email,
  });
  const licenseId = newId("lic");
  const licenseKey = newSecret("tl_license");
  const now = nowIso();
  const maxActivations = input.maxActivations ?? 2;
  await env.DB.prepare(
    `INSERT INTO license_keys
      (id, key_hash, user_id, email, status, max_activations, created_at, expires_at, notes)
     VALUES (?, ?, ?, ?, 'issued', ?, ?, ?, ?)`
  )
    .bind(
      licenseId,
      await sha256Hex(licenseKey),
      user.id,
      user.email,
      maxActivations,
      now,
      input.expiresAt ?? null,
      input.notes ?? null
    )
    .run();

  return {
    email: user.email,
    licenseId,
    licenseKey,
    maxActivations,
    status: "issued",
    userId: user.id,
  };
};

const getLicenseByKey = async (
  env: Env,
  licenseKey: string
): Promise<LicenseRow | null> =>
  env.DB.prepare(
    `SELECT id, user_id, email, status, max_activations, expires_at
       FROM license_keys
      WHERE key_hash = ?`
  )
    .bind(await sha256Hex(licenseKey))
    .first<LicenseRow>();

const activeActivationCount = async (
  env: Env,
  licenseId: string
): Promise<number> => {
  const row = await env.DB.prepare(
    `SELECT COUNT(*) AS count
       FROM license_activations
      WHERE license_id = ?
        AND status = 'active'`
  )
    .bind(licenseId)
    .first<{ count: number }>();
  return row?.count ?? 0;
};

const getActivation = (
  env: Env,
  input: { deviceId: string; licenseId: string }
): Promise<ActivationRow | null> =>
  env.DB.prepare(
    `SELECT id, status
       FROM license_activations
      WHERE license_id = ?
        AND device_id = ?`
  )
    .bind(input.licenseId, input.deviceId)
    .first<ActivationRow>();

const createActivation = async (
  env: Env,
  input: {
    appVersion?: string | null;
    deviceId: string;
    deviceName?: string | null;
    licenseId: string;
    userId: string;
  }
): Promise<string> => {
  const activationId = newId("act");
  const now = nowIso();
  await env.DB.prepare(
    `INSERT INTO license_activations
      (id, license_id, user_id, device_id, device_name, app_version, status, created_at, last_seen_at)
     VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?)`
  )
    .bind(
      activationId,
      input.licenseId,
      input.userId,
      input.deviceId,
      input.deviceName ?? null,
      input.appVersion ?? null,
      now,
      now
    )
    .run();
  return activationId;
};

const issueCredential = async (
  env: Env,
  input: {
    activationId: string;
    label?: string | null;
    userId: string;
  }
): Promise<{ credential: string; credentialId: string }> => {
  const credential = newSecret("tlc");
  const credentialId = newId("cred");
  await env.DB.prepare(
    `UPDATE api_credentials
        SET status = 'revoked',
            revoked_at = COALESCE(revoked_at, ?)
      WHERE activation_id = ?
        AND status = 'active'`
  )
    .bind(nowIso(), input.activationId)
    .run();
  await env.DB.prepare(
    `INSERT INTO api_credentials
      (id, user_id, activation_id, label, credential_hash, status, created_at)
     VALUES (?, ?, ?, ?, ?, 'active', ?)`
  )
    .bind(
      credentialId,
      input.userId,
      input.activationId,
      input.label ?? null,
      await sha256Hex(credential),
      nowIso()
    )
    .run();
  return { credential, credentialId };
};

export const activateLicense = async (
  env: Env,
  input: {
    appVersion?: string | null;
    deviceId: string;
    deviceName?: string | null;
    email: string;
    licenseKey: string;
  }
): Promise<{
  activationId: string;
  credential: string;
  credentialId: string;
  email: string;
  licenseId: string;
  userId: string;
}> => {
  const email = normalizeEmail(input.email);
  const license = await getLicenseByKey(env, input.licenseKey);
  if (!license) {
    throw new Error("license not found");
  }
  requireActiveStatus(license.status, "license");
  if (license.email !== email) {
    throw new Error("license email mismatch");
  }
  if (license.expires_at && Date.parse(license.expires_at) <= Date.now()) {
    throw new Error("license expired");
  }

  const user =
    license.user_id === null
      ? await ensureUser(env, { email })
      : { email: license.email, id: license.user_id };
  const existingActivation = await getActivation(env, {
    deviceId: input.deviceId,
    licenseId: license.id,
  });
  if (existingActivation?.status === "revoked") {
    throw new Error("activation revoked");
  }

  const activationId =
    existingActivation?.id ??
    (await createActivation(env, {
      appVersion: input.appVersion,
      deviceId: input.deviceId,
      deviceName: input.deviceName,
      licenseId: license.id,
      userId: user.id,
    }));
  if (!existingActivation) {
    const activeCount = await activeActivationCount(env, license.id);
    if (activeCount > license.max_activations) {
      await revokeActivation(env, activationId);
      throw new Error("activation limit exceeded");
    }
  }

  await env.DB.prepare(
    `UPDATE license_keys
        SET status = 'active',
            activated_at = COALESCE(activated_at, ?),
            user_id = COALESCE(user_id, ?)
      WHERE id = ?`
  )
    .bind(nowIso(), user.id, license.id)
    .run();
  await env.DB.prepare(
    `UPDATE license_activations
        SET last_seen_at = ?,
            device_name = COALESCE(?, device_name),
            app_version = COALESCE(?, app_version)
      WHERE id = ?`
  )
    .bind(
      nowIso(),
      input.deviceName ?? null,
      input.appVersion ?? null,
      activationId
    )
    .run();

  const issued = await issueCredential(env, {
    activationId,
    label: input.deviceName,
    userId: user.id,
  });
  return {
    activationId,
    credential: issued.credential,
    credentialId: issued.credentialId,
    email: user.email,
    licenseId: license.id,
    userId: user.id,
  };
};

export const authenticateCredential = async (
  env: Env,
  authorization: string | null | undefined
): Promise<AuthSession | null> => {
  const token = authorization?.match(bearerPattern)?.[1];
  if (!token) {
    return null;
  }
  const row = await env.DB.prepare(
    `SELECT
       api_credentials.id AS credential_id,
       api_credentials.status AS credential_status,
       api_credentials.activation_id,
       users.id AS user_id,
       users.email,
       license_keys.status AS license_status
     FROM api_credentials
     JOIN users ON users.id = api_credentials.user_id
     LEFT JOIN license_activations
       ON license_activations.id = api_credentials.activation_id
     LEFT JOIN license_keys
       ON license_keys.id = license_activations.license_id
     WHERE api_credentials.credential_hash = ?`
  )
    .bind(await sha256Hex(token))
    .first<CredentialRow>();
  if (row?.credential_status !== "active") {
    return null;
  }
  if (row.license_status && row.license_status !== "active") {
    return null;
  }
  await env.DB.prepare(
    "UPDATE api_credentials SET last_seen_at = ? WHERE id = ?"
  )
    .bind(nowIso(), row.credential_id)
    .run();
  if (row.activation_id) {
    await env.DB.prepare(
      "UPDATE license_activations SET last_seen_at = ? WHERE id = ?"
    )
      .bind(nowIso(), row.activation_id)
      .run();
  }
  return {
    activationId: row.activation_id,
    credentialId: row.credential_id,
    email: row.email,
    userId: row.user_id,
  };
};

const revokeActivation = async (
  env: Env,
  activationId: string
): Promise<void> => {
  const now = nowIso();
  await env.DB.prepare(
    `UPDATE license_activations
        SET status = 'revoked',
            revoked_at = COALESCE(revoked_at, ?)
      WHERE id = ?`
  )
    .bind(now, activationId)
    .run();
  await env.DB.prepare(
    `UPDATE api_credentials
        SET status = 'revoked',
            revoked_at = COALESCE(revoked_at, ?)
      WHERE activation_id = ?`
  )
    .bind(now, activationId)
    .run();
};

export const revokeLicense = async (
  env: Env,
  licenseId: string
): Promise<void> => {
  const now = nowIso();
  await env.DB.prepare(
    `UPDATE license_keys
        SET status = 'revoked',
            revoked_at = COALESCE(revoked_at, ?)
      WHERE id = ?`
  )
    .bind(now, licenseId)
    .run();
  await env.DB.prepare(
    `UPDATE license_activations
        SET status = 'revoked',
            revoked_at = COALESCE(revoked_at, ?)
      WHERE license_id = ?`
  )
    .bind(now, licenseId)
    .run();
  await env.DB.prepare(
    `UPDATE api_credentials
        SET status = 'revoked',
            revoked_at = COALESCE(revoked_at, ?)
      WHERE activation_id IN (
        SELECT id FROM license_activations WHERE license_id = ?
      )`
  )
    .bind(now, licenseId)
    .run();
};

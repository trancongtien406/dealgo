import { createHash, generateKeyPairSync, randomBytes, sign, type KeyObject } from 'node:crypto';
import type { AuthenticationResponseJSON } from '@simplewebauthn/server';
import { isoBase64URL, isoCBOR } from '@simplewebauthn/server/helpers';

/** UP (user present) + UV (user verified). */
const FLAGS_UP_UV = 0x05;

/**
 * In-memory ES256 platform authenticator for HTTP specs: produces real WebAuthn assertions
 * that @simplewebauthn/server verifies, without any device.
 */
export class SoftwarePasskey {
  readonly credentialId = isoBase64URL.fromBuffer(randomBytes(16));
  /** COSE public key, as stored by `savePasskey`. */
  readonly publicKey: Uint8Array;
  private readonly privateKey: KeyObject;
  private counter = 0;

  constructor(
    private readonly rpId: string,
    private readonly origin: string,
  ) {
    const pair = generateKeyPairSync('ec', { namedCurve: 'P-256' });
    this.privateKey = pair.privateKey;
    const jwk = pair.publicKey.export({ format: 'jwk' });
    const cose = new Map<number, number | Uint8Array>([
      [1, 2], // kty: EC2
      [3, -7], // alg: ES256
      [-1, 1], // crv: P-256
      [-2, isoBase64URL.toBuffer(jwk.x!)],
      [-3, isoBase64URL.toBuffer(jwk.y!)],
    ]);
    this.publicKey = isoCBOR.encode(cose);
  }

  /** Arguments for `IdentityRepository.savePasskey` / `createPasskeyUser`. */
  record() {
    return {
      credentialId: this.credentialId,
      publicKey: this.publicKey,
      counter: 0,
      transports: ['internal'],
      deviceType: 'multiDevice',
      backedUp: true,
    };
  }

  /** Signs an assertion over [challenge] (base64url, as in the request options). */
  assert(challenge: string): AuthenticationResponseJSON {
    this.counter += 1;
    const authenticatorData = Buffer.concat([
      createHash('sha256').update(this.rpId).digest(),
      Buffer.from([FLAGS_UP_UV]),
      Buffer.from([0, 0, 0, this.counter]),
    ]);
    const clientDataJSON = Buffer.from(
      JSON.stringify({ type: 'webauthn.get', challenge, origin: this.origin, crossOrigin: false }),
    );
    const signature = sign(
      'sha256',
      Buffer.concat([authenticatorData, createHash('sha256').update(clientDataJSON).digest()]),
      this.privateKey,
    );
    return {
      id: this.credentialId,
      rawId: this.credentialId,
      type: 'public-key',
      clientExtensionResults: {},
      response: {
        clientDataJSON: isoBase64URL.fromBuffer(clientDataJSON),
        authenticatorData: isoBase64URL.fromBuffer(authenticatorData),
        signature: isoBase64URL.fromBuffer(signature),
      },
    };
  }
}

import { generateKeyPairSync, createSign } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { isSnsUrl, parseSnsMessage, sesSuppressions, snsStringToSign, SnsSignatureVerifier, type SnsMessage } from './sns-message.js';

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const pem = publicKey.export({ type: 'spki', format: 'pem' }).toString();
const certUrl = 'https://sns.ap-southeast-1.amazonaws.com/SimpleNotificationService-abc.pem';

function signed(patch: Partial<SnsMessage> = {}): SnsMessage {
  const msg: SnsMessage = {
    Type: 'Notification',
    MessageId: 'm1',
    TopicArn: 'arn:aws:sns:ap-southeast-1:123:ses-events',
    Message: JSON.stringify({
      notificationType: 'Bounce',
      bounce: { bounceType: 'Permanent', bounceSubType: 'General', bouncedRecipients: [{ emailAddress: 'gone@x.vn' }] },
    }),
    Timestamp: new Date().toISOString(),
    SignatureVersion: '2',
    Signature: '',
    SigningCertURL: certUrl,
    ...patch,
  };
  msg.Signature = createSign('RSA-SHA256').update(snsStringToSign(msg)).sign(privateKey, 'base64');
  return msg;
}

describe('SNS messages', () => {
  const verifier = new SnsSignatureVerifier(async () => pem);

  it('verifies signed messages and rejects tampering, foreign hosts and stale timestamps', async () => {
    const msg = signed();
    expect(await verifier.verify(msg)).toBe(true);
    expect(await verifier.verify({ ...msg, Message: '{}' })).toBe(false);
    expect(await verifier.verify(signed({ SigningCertURL: 'https://evil.example.com/x.pem' }))).toBe(false);
    expect(await verifier.verify(signed({ Timestamp: '2020-01-01T00:00:00Z' }))).toBe(false);
  });

  it('only trusts https sns.*.amazonaws.com URLs', () => {
    expect(isSnsUrl(certUrl)).toBe(true);
    expect(isSnsUrl('http://sns.ap-southeast-1.amazonaws.com/x')).toBe(false);
    expect(isSnsUrl('https://sns.ap-southeast-1.amazonaws.com.evil.io/x')).toBe(false);
  });

  it('parses text bodies and extracts permanent bounces and complaints only', () => {
    expect(parseSnsMessage(JSON.stringify(signed()))?.Type).toBe('Notification');
    expect(parseSnsMessage({ hello: 1 })).toBeNull();
    expect(sesSuppressions(signed().Message)).toEqual([{ email: 'gone@x.vn', reason: 'BOUNCE', detail: 'General' }]);
    expect(
      sesSuppressions(JSON.stringify({ notificationType: 'Bounce', bounce: { bounceType: 'Transient', bouncedRecipients: [{ emailAddress: 'a@x.vn' }] } })),
    ).toEqual([]);
    expect(
      sesSuppressions(JSON.stringify({ eventType: 'Complaint', complaint: { complainedRecipients: [{ emailAddress: 'c@x.vn' }] } })),
    ).toMatchObject([{ email: 'c@x.vn', reason: 'COMPLAINT' }]);
  });
});

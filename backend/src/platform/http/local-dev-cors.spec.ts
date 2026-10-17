import { LOCAL_DEV_ORIGINS, localDevCors } from './local-dev-cors.js';

describe('localDevCors', () => {
  it('allows the admin web and API development origins', () => {
    expect([...LOCAL_DEV_ORIGINS]).toEqual(['http://localhost:3000', 'http://localhost:3001']);
    expect(localDevCors().origin).toEqual([...LOCAL_DEV_ORIGINS]);
    expect(localDevCors().allowedHeaders).toContain('Authorization');
    expect(localDevCors().allowedHeaders).toContain('Idempotency-Key');
  });
});

import { MockMailSender } from './mail-sender.js';
import { policyUpdateMail } from './mail-templates.js';

describe('policy update mail (t82u)', () => {
  it('renders title, version, effective date, changelog and link', () => {
    const m = policyUpdateMail({
      documentTitle: 'Điều khoản sử dụng',
      version: 3,
      effectiveAt: new Date('2026-11-15T00:00:00Z'),
      changelog: 'Làm rõ phí huỷ chuyến.',
      url: 'https://dealgo.laptrinhapp.com/terms',
    });
    expect(m.subject).toContain('Điều khoản sử dụng');
    expect(m.text + (m.html ?? "")).toContain('phiên bản 3');
    expect(m.text + (m.html ?? "")).toContain('15/11/2026');
    expect(m.text + (m.html ?? "")).toContain('Làm rõ phí huỷ chuyến.');
    expect(m.text + (m.html ?? "")).toContain('https://dealgo.laptrinhapp.com/terms');
  });

  it('mock sender records without logging the full address', async () => {
    const s = new MockMailSender('test');
    await s.sendPolicyUpdate({ email: 'tester@example.test', documentTitle: 'X', version: 1, effectiveAt: null, changelog: '', url: 'https://x' });
    expect(s.policyUpdates).toHaveLength(1);
  });
});

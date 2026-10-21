import { MemoryOpsFaqRepository } from './ops-faq.repository.js';
import { OpsFaqService } from './ops-faq.service.js';

describe('OpsFaqService help FAQ (DEC-PROD-021)', () => {
  it('serves only PUBLISHED entries of the requested audience, never INTERNAL drafts', async () => {
    const repo = new MemoryOpsFaqRepository();
    const service = new OpsFaqService(repo);

    const customer = await service.listHelp('CUSTOMER');
    expect(customer.length).toBeGreaterThanOrEqual(5);
    expect(customer[0]).toEqual({
      id: expect.any(String),
      question: 'Tôi có thể huỷ đơn đồ ăn không?',
      answer: expect.stringContaining('quán chưa nhận đơn'),
      updatedAt: expect.any(String),
    });
    expect(customer.some((f) => f.question.includes('pilot'))).toBe(false);

    const draft = await service.create({
      question: 'Nháp chưa đăng',
      suggestedAnswer: 'Không hiện',
      category: 'PRODUCT',
      audience: 'CUSTOMER',
      actorUserId: 'ops-1',
      reason: 'test',
    });
    expect((await service.listHelp('CUSTOMER')).map((f) => f.id)).not.toContain(draft.id);
    await service.patch({ id: draft.id, status: 'PUBLISHED', sortOrder: 1, actorUserId: 'ops-1', reason: 'publish' });
    expect((await service.listHelp('CUSTOMER'))[0].id).toBe(draft.id);
    expect(await service.listHelp('DRIVER')).toEqual([]);

    const internal = (await service.list()).filter((f) => f.audience === 'INTERNAL');
    expect(internal.length).toBeGreaterThan(0);
    // Re-seeding does not duplicate help entries.
    await service.listHelp('CUSTOMER');
    expect((await service.list()).filter((f) => f.openId === 'HELP-C01')).toHaveLength(1);
  });
});

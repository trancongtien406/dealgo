import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { HELP_FAQ_SEEDS } from './help-faq.seed.js';
import { OPS_FAQ_SEEDS } from './ops-faq.seed.js';
import { OPS_FAQ_REPOSITORY } from './support.constants.js';
import type {
  CreateOpsFaqInput,
  FaqAudienceName,
  OpsFaqRecord,
  OpsFaqRepository,
  OpsFaqStatusName,
  PatchOpsFaqInput,
} from './ops-faq.repository.js';

export type OpsFaqView = {
  id: string;
  openId: string | null;
  question: string;
  suggestedAnswer: string;
  status: OpsFaqStatusName;
  category: string;
  audience: FaqAudienceName;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
  createdByUserId: string | null;
  updatedByUserId: string | null;
};

export type HelpFaqView = { id: string; question: string; answer: string; updatedAt: string };

@Injectable()
export class OpsFaqService {
  private seeded = false;

  constructor(@Inject(OPS_FAQ_REPOSITORY) private readonly repo: OpsFaqRepository) {}

  async list(status?: OpsFaqStatusName): Promise<OpsFaqView[]> {
    await this.ensureSeeded();
    const rows = await this.repo.list(status);
    return rows.map(toView);
  }

  /** In-app help: PUBLISHED entries for one audience, question + answer only. */
  async listHelp(audience: Exclude<FaqAudienceName, 'INTERNAL'>): Promise<HelpFaqView[]> {
    await this.ensureSeeded();
    const rows = await this.repo.listPublished(audience);
    return rows.map((row) => ({
      id: row.id,
      question: row.question,
      answer: row.suggestedAnswer,
      updatedAt: row.updatedAt.toISOString(),
    }));
  }

  async create(
    input: Omit<CreateOpsFaqInput, 'actorUserId' | 'reason'> & {
      actorUserId: string;
      reason: string;
    },
  ): Promise<OpsFaqView> {
    await this.ensureSeeded();
    const created = await this.repo.create(input);
    return toView(created);
  }

  async patch(
    input: Omit<PatchOpsFaqInput, 'actorUserId' | 'reason'> & {
      actorUserId: string;
      reason: string;
    },
  ): Promise<OpsFaqView> {
    await this.ensureSeeded();
    const updated = await this.repo.patch(input);
    if (!updated) {
      throw new NotFoundException({ message: 'FAQ entry not found', errorCode: 'OPS_FAQ_NOT_FOUND' });
    }
    return toView(updated);
  }

  private async ensureSeeded(): Promise<void> {
    if (this.seeded) {
      return;
    }
    await this.repo.ensureSeeds([...OPS_FAQ_SEEDS, ...HELP_FAQ_SEEDS]);
    this.seeded = true;
  }
}

function toView(row: OpsFaqRecord): OpsFaqView {
  return {
    id: row.id,
    openId: row.openId,
    question: row.question,
    suggestedAnswer: row.suggestedAnswer,
    status: row.status,
    category: row.category,
    audience: row.audience,
    sortOrder: row.sortOrder,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
    createdByUserId: row.createdByUserId,
    updatedByUserId: row.updatedByUserId,
  };
}

import type { StoredDocumentRef } from '../../platform/storage/document-store.service.js';
import { randomInt, randomUUID } from 'node:crypto';
import {
  SUPPORT_ACTIVE_STATUSES,
  type SUPPORT_TICKET_CATEGORIES,
  type SUPPORT_TICKET_PRIORITIES,
  type SUPPORT_TICKET_RELATED_TYPES,
  type SUPPORT_TICKET_STATUSES,
} from './support-ticket.constants.js';

export type SupportTicketStatus = (typeof SUPPORT_TICKET_STATUSES)[number];
export type SupportTicketCategory = (typeof SUPPORT_TICKET_CATEGORIES)[number];
export type SupportTicketPriority = (typeof SUPPORT_TICKET_PRIORITIES)[number];
export type SupportTicketRelatedType = (typeof SUPPORT_TICKET_RELATED_TYPES)[number];
export type SupportTicketChannel = 'APP' | 'WEB';
export type SupportMessageAuthor = 'REQUESTER' | 'STAFF';

export type SupportTicket = {
  id: string;
  code: string;
  channel: SupportTicketChannel;
  requesterUserId: string | null;
  requesterRole: string;
  contactName: string | null;
  contact: string | null;
  category: SupportTicketCategory;
  relatedType: SupportTicketRelatedType | null;
  relatedId: string | null;
  externalRef: string | null;
  subject: string;
  status: SupportTicketStatus;
  priority: SupportTicketPriority;
  lastMessageAt: Date;
  lastAuthor: SupportMessageAuthor;
  resolvedAt: Date | null;
  closedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

export type SupportTicketMessage = {
  id: string;
  ticketId: string;
  authorType: SupportMessageAuthor;
  authorUserId: string | null;
  body: string;
  /** StoredDocumentRef[] as jsonb; parse with readSupportAttachments (DEC-PROD-020). */
  attachments: unknown;
  createdAt: Date;
};

export type SupportTicketWithMessages = SupportTicket & { messages: SupportTicketMessage[] };
export type SupportTicketListItem = SupportTicket & { lastMessagePreview: string };

export type NewSupportTicket = {
  channel: SupportTicketChannel;
  requesterUserId: string | null;
  requesterRole: string;
  contactName?: string | null;
  contact?: string | null;
  category: SupportTicketCategory;
  relatedType?: SupportTicketRelatedType | null;
  relatedId?: string | null;
  externalRef?: string | null;
  subject: string;
  description: string;
  attachments?: StoredDocumentRef[];
};

/** Limit checked under the same lock as the insert. */
export type SupportCreateLimit =
  | { kind: 'user'; userId: string; maxOpen: number }
  | { kind: 'contact'; contact: string; maxPerWindow: number; since: Date };

export type SupportListQuery = { page: number; limit: number };
export type SupportUserListQuery = SupportListQuery & { statuses?: readonly SupportTicketStatus[] };
export type SupportOpsListQuery = SupportListQuery & {
  status?: SupportTicketStatus;
  category?: SupportTicketCategory;
  channel?: SupportTicketChannel;
  q?: string;
};

export type SupportPage = { items: SupportTicketListItem[]; total: number };
export type SupportUserPage = SupportPage & { activeCount: number; doneCount: number };

export type SupportStaffPatch = {
  status?: SupportTicketStatus;
  priority?: SupportTicketPriority;
};

export type SupportAudit = {
  actorUserId: string;
  reason: string;
  metadata: Record<string, unknown>;
};

export type SupportRuleCode =
  | 'SUPPORT_TICKET_NOT_FOUND'
  | 'SUPPORT_TICKET_LIMIT_REACHED'
  | 'SUPPORT_CONTACT_LIMIT_REACHED'
  | 'SUPPORT_TICKET_CLOSED';

export class SupportRuleError extends Error {
  constructor(readonly code: SupportRuleCode) {
    super(code);
  }
}

export interface SupportTicketRepository {
  create(input: NewSupportTicket, limit: SupportCreateLimit, now: Date): Promise<SupportTicketWithMessages>;
  listForUser(userId: string, query: SupportUserListQuery): Promise<SupportUserPage>;
  listForOps(query: SupportOpsListQuery): Promise<SupportPage>;
  findById(id: string): Promise<SupportTicketWithMessages | null>;
  /** Requester follow-up. RESOLVED reopens to IN_PROGRESS; CLOSED rejects. */
  addRequesterMessage(
    ticketId: string,
    userId: string,
    body: string,
    now: Date,
    attachments?: StoredDocumentRef[],
  ): Promise<SupportTicketWithMessages>;
  /** Staff reply. OPEN moves to IN_PROGRESS; CLOSED rejects (reopen first). Writes an audit row. */
  addStaffReply(
    ticketId: string,
    staffUserId: string,
    body: string,
    now: Date,
    audit: SupportAudit,
    attachments?: StoredDocumentRef[],
  ): Promise<{ ticket: SupportTicketWithMessages; message: SupportTicketMessage }>;
  updateByStaff(
    ticketId: string,
    patch: SupportStaffPatch,
    now: Date,
    audit: SupportAudit,
  ): Promise<SupportTicketWithMessages>;
}

/** `DG-YYMMDD-NNNN` in Vietnam time (the ticket code users read out to the hotline). */
export function supportTicketCode(now: Date): string {
  const local = new Date(now.getTime() + 7 * 3_600_000);
  const yy = String(local.getUTCFullYear() % 100).padStart(2, '0');
  const mm = String(local.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(local.getUTCDate()).padStart(2, '0');
  return `DG-${yy}${mm}${dd}-${String(randomInt(0, 10_000)).padStart(4, '0')}`;
}

/** Safety reports start HIGH so they top the Ops queue. */
export function initialPriority(category: SupportTicketCategory): SupportTicketPriority {
  return category === 'SAFETY' ? 'HIGH' : 'NORMAL';
}

/** Parses the jsonb attachments column; malformed entries are dropped. */
export function readSupportAttachments(value: unknown): StoredDocumentRef[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter(
    (item): item is StoredDocumentRef =>
      !!item &&
      typeof item === 'object' &&
      typeof (item as StoredDocumentRef).key === 'string' &&
      typeof (item as StoredDocumentRef).label === 'string' &&
      typeof (item as StoredDocumentRef).contentType === 'string' &&
      typeof (item as StoredDocumentRef).sizeBytes === 'number',
  );
}

export function messagePreview(body: string): string {
  const flat = body.replace(/\s+/g, ' ').trim();
  return flat.length > 120 ? `${flat.slice(0, 119)}…` : flat;
}

/** Timestamps that follow a status change (resolvedAt/closedAt are kept only while in that state). */
export function statusStamps(
  status: SupportTicketStatus,
  current: Pick<SupportTicket, 'resolvedAt' | 'closedAt'>,
  now: Date,
): Pick<SupportTicket, 'resolvedAt' | 'closedAt'> {
  return {
    resolvedAt: status === 'RESOLVED' ? (current.resolvedAt ?? now) : null,
    closedAt: status === 'CLOSED' ? (current.closedAt ?? now) : null,
  };
}

export function isActiveStatus(status: SupportTicketStatus): boolean {
  return (SUPPORT_ACTIVE_STATUSES as readonly string[]).includes(status);
}

export class MemorySupportTicketRepository implements SupportTicketRepository {
  private readonly tickets = new Map<string, SupportTicket>();
  private readonly messages: SupportTicketMessage[] = [];
  readonly audits: Array<SupportAudit & { ticketId: string }> = [];

  async create(
    input: NewSupportTicket,
    limit: SupportCreateLimit,
    now: Date,
  ): Promise<SupportTicketWithMessages> {
    const all = [...this.tickets.values()];
    if (limit.kind === 'user') {
      const open = all.filter(
        (t) => t.requesterUserId === limit.userId && isActiveStatus(t.status),
      ).length;
      if (open >= limit.maxOpen) {
        throw new SupportRuleError('SUPPORT_TICKET_LIMIT_REACHED');
      }
    } else {
      const recent = all.filter(
        (t) => t.contact === limit.contact && t.createdAt >= limit.since,
      ).length;
      if (recent >= limit.maxPerWindow) {
        throw new SupportRuleError('SUPPORT_CONTACT_LIMIT_REACHED');
      }
    }
    let code = supportTicketCode(now);
    while (all.some((t) => t.code === code)) {
      code = supportTicketCode(now);
    }
    const ticket: SupportTicket = {
      id: randomUUID(),
      code,
      channel: input.channel,
      requesterUserId: input.requesterUserId,
      requesterRole: input.requesterRole,
      contactName: input.contactName ?? null,
      contact: input.contact ?? null,
      category: input.category,
      relatedType: input.relatedType ?? null,
      relatedId: input.relatedId ?? null,
      externalRef: input.externalRef ?? null,
      subject: input.subject,
      status: 'OPEN',
      priority: initialPriority(input.category),
      lastMessageAt: now,
      lastAuthor: 'REQUESTER',
      resolvedAt: null,
      closedAt: null,
      createdAt: now,
      updatedAt: now,
    };
    this.tickets.set(ticket.id, ticket);
    this.messages.push({
      id: randomUUID(),
      ticketId: ticket.id,
      authorType: 'REQUESTER',
      authorUserId: input.requesterUserId,
      body: input.description,
      attachments: [...(input.attachments ?? [])],
      createdAt: now,
    });
    return this.withMessages(ticket);
  }

  async listForUser(userId: string, query: SupportUserListQuery): Promise<SupportUserPage> {
    const mine = [...this.tickets.values()].filter((t) => t.requesterUserId === userId);
    const activeCount = mine.filter((t) => isActiveStatus(t.status)).length;
    const filtered = query.statuses ? mine.filter((t) => query.statuses?.includes(t.status)) : mine;
    return { ...this.page(filtered, query), activeCount, doneCount: mine.length - activeCount };
  }

  async listForOps(query: SupportOpsListQuery): Promise<SupportPage> {
    const q = query.q?.trim().toLowerCase();
    const rows = [...this.tickets.values()].filter(
      (t) =>
        (!query.status || t.status === query.status) &&
        (!query.category || t.category === query.category) &&
        (!query.channel || t.channel === query.channel) &&
        (!q ||
          t.code.toLowerCase().includes(q) ||
          t.subject.toLowerCase().includes(q) ||
          (t.contact ?? '').toLowerCase().includes(q)),
    );
    return this.page(rows, query);
  }

  async findById(id: string): Promise<SupportTicketWithMessages | null> {
    const ticket = this.tickets.get(id);
    return ticket ? this.withMessages(ticket) : null;
  }

  async addRequesterMessage(
    ticketId: string,
    userId: string,
    body: string,
    now: Date,
    attachments: StoredDocumentRef[] = [],
  ): Promise<SupportTicketWithMessages> {
    const ticket = this.tickets.get(ticketId);
    if (!ticket || ticket.requesterUserId !== userId) {
      throw new SupportRuleError('SUPPORT_TICKET_NOT_FOUND');
    }
    if (ticket.status === 'CLOSED') {
      throw new SupportRuleError('SUPPORT_TICKET_CLOSED');
    }
    const status: SupportTicketStatus = ticket.status === 'RESOLVED' ? 'IN_PROGRESS' : ticket.status;
    this.push(ticketId, 'REQUESTER', userId, body, now, attachments);
    const next = {
      ...ticket,
      status,
      ...statusStamps(status, ticket, now),
      lastMessageAt: now,
      lastAuthor: 'REQUESTER' as const,
      updatedAt: now,
    };
    this.tickets.set(ticketId, next);
    return this.withMessages(next);
  }

  async addStaffReply(
    ticketId: string,
    staffUserId: string,
    body: string,
    now: Date,
    audit: SupportAudit,
    attachments: StoredDocumentRef[] = [],
  ): Promise<{ ticket: SupportTicketWithMessages; message: SupportTicketMessage }> {
    const ticket = this.tickets.get(ticketId);
    if (!ticket) {
      throw new SupportRuleError('SUPPORT_TICKET_NOT_FOUND');
    }
    if (ticket.status === 'CLOSED') {
      throw new SupportRuleError('SUPPORT_TICKET_CLOSED');
    }
    const status: SupportTicketStatus = ticket.status === 'OPEN' ? 'IN_PROGRESS' : ticket.status;
    const message = this.push(ticketId, 'STAFF', staffUserId, body, now, attachments);
    const next = {
      ...ticket,
      status,
      lastMessageAt: now,
      lastAuthor: 'STAFF' as const,
      updatedAt: now,
    };
    this.tickets.set(ticketId, next);
    this.audits.push({ ...audit, ticketId });
    return { ticket: this.withMessages(next), message };
  }

  async updateByStaff(
    ticketId: string,
    patch: SupportStaffPatch,
    now: Date,
    audit: SupportAudit,
  ): Promise<SupportTicketWithMessages> {
    const ticket = this.tickets.get(ticketId);
    if (!ticket) {
      throw new SupportRuleError('SUPPORT_TICKET_NOT_FOUND');
    }
    const status = patch.status ?? ticket.status;
    const next = {
      ...ticket,
      status,
      priority: patch.priority ?? ticket.priority,
      ...statusStamps(status, ticket, now),
      updatedAt: now,
    };
    this.tickets.set(ticketId, next);
    this.audits.push({ ...audit, ticketId });
    return this.withMessages(next);
  }

  private push(
    ticketId: string,
    authorType: SupportMessageAuthor,
    authorUserId: string | null,
    body: string,
    now: Date,
    attachments: StoredDocumentRef[] = [],
  ): SupportTicketMessage {
    const message = {
      id: randomUUID(),
      ticketId,
      authorType,
      authorUserId,
      body,
      attachments: [...attachments],
      createdAt: now,
    };
    this.messages.push(message);
    return message;
  }

  private withMessages(ticket: SupportTicket): SupportTicketWithMessages {
    return {
      ...ticket,
      messages: this.messages.filter((m) => m.ticketId === ticket.id),
    };
  }

  private page(rows: SupportTicket[], query: SupportListQuery): SupportPage {
    const sorted = [...rows].sort(
      (a, b) => b.lastMessageAt.getTime() - a.lastMessageAt.getTime() || b.code.localeCompare(a.code),
    );
    const start = (query.page - 1) * query.limit;
    return {
      total: rows.length,
      items: sorted.slice(start, start + query.limit).map((t) => {
        const last = this.messages.filter((m) => m.ticketId === t.id).at(-1);
        return { ...t, lastMessagePreview: last ? messagePreview(last.body) : '' };
      }),
    };
  }
}

import type { StoredDocumentRef } from '../../platform/storage/document-store.service.js';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { SUPPORT_ACTIVE_STATUSES } from './support-ticket.constants.js';
import {
  SupportRuleError,
  initialPriority,
  messagePreview,
  statusStamps,
  supportTicketCode,
  type NewSupportTicket,
  type SupportAudit,
  type SupportCreateLimit,
  type SupportListQuery,
  type SupportOpsListQuery,
  type SupportPage,
  type SupportStaffPatch,
  type SupportTicket,
  type SupportTicketMessage,
  type SupportTicketRepository,
  type SupportTicketStatus,
  type SupportTicketWithMessages,
  type SupportUserListQuery,
  type SupportUserPage,
} from './support-ticket.repository.js';

const CODE_ATTEMPTS = 5;
const withMessages = { messages: { orderBy: { createdAt: 'asc' } } } as const;
const withPreview = { messages: { orderBy: { createdAt: 'desc' }, take: 1 } } as const;

type Tx = Prisma.TransactionClient;

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    (error as { code?: string }).code === 'P2002'
  );
}

export class PrismaSupportTicketRepository implements SupportTicketRepository {
  constructor(private readonly db: PrismaClient) {}

  async create(
    input: NewSupportTicket,
    limit: SupportCreateLimit,
    now: Date,
  ): Promise<SupportTicketWithMessages> {
    for (let attempt = 1; ; attempt += 1) {
      try {
        return await this.db.$transaction(async (tx) => {
          await this.enforceLimit(tx, limit);
          return tx.supportTicket.create({
            data: {
              code: supportTicketCode(now),
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
              priority: initialPriority(input.category),
              lastMessageAt: now,
              createdAt: now,
              messages: {
                create: {
                  authorType: 'REQUESTER',
                  authorUserId: input.requesterUserId,
                  body: input.description,
                  attachments: (input.attachments ?? []) as Prisma.InputJsonValue,
                  createdAt: now,
                },
              },
            },
            include: withMessages,
          });
        });
      } catch (error) {
        // Ticket code collision (DG-YYMMDD-NNNN): retry with a fresh code.
        if (isUniqueViolation(error) && attempt < CODE_ATTEMPTS) {
          continue;
        }
        throw error;
      }
    }
  }

  async listForUser(userId: string, query: SupportUserListQuery): Promise<SupportUserPage> {
    const where: Prisma.SupportTicketWhereInput = {
      requesterUserId: userId,
      ...(query.statuses ? { status: { in: [...query.statuses] } } : {}),
    };
    const [page, activeCount, allCount] = await Promise.all([
      this.page(where, query),
      this.db.supportTicket.count({
        where: { requesterUserId: userId, status: { in: [...SUPPORT_ACTIVE_STATUSES] } },
      }),
      this.db.supportTicket.count({ where: { requesterUserId: userId } }),
    ]);
    return { ...page, activeCount, doneCount: allCount - activeCount };
  }

  async listForOps(query: SupportOpsListQuery): Promise<SupportPage> {
    const q = query.q?.trim();
    return this.page(
      {
        ...(query.status ? { status: query.status } : {}),
        ...(query.category ? { category: query.category } : {}),
        ...(query.channel ? { channel: query.channel } : {}),
        ...(q
          ? {
              OR: [
                { code: { contains: q, mode: 'insensitive' } },
                { subject: { contains: q, mode: 'insensitive' } },
                { contact: { contains: q, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      query,
    );
  }

  async findById(id: string): Promise<SupportTicketWithMessages | null> {
    return this.db.supportTicket.findUnique({ where: { id }, include: withMessages });
  }

  async addRequesterMessage(
    ticketId: string,
    userId: string,
    body: string,
    now: Date,
    attachments: StoredDocumentRef[] = [],
  ): Promise<SupportTicketWithMessages> {
    return this.db.$transaction(async (tx) => {
      const ticket = await this.lockTicket(tx, ticketId);
      if (!ticket || ticket.requesterUserId !== userId) {
        throw new SupportRuleError('SUPPORT_TICKET_NOT_FOUND');
      }
      if (ticket.status === 'CLOSED') {
        throw new SupportRuleError('SUPPORT_TICKET_CLOSED');
      }
      const status: SupportTicketStatus =
        ticket.status === 'RESOLVED' ? 'IN_PROGRESS' : ticket.status;
      await tx.supportTicketMessage.create({
        data: {
          ticketId,
          authorType: 'REQUESTER',
          authorUserId: userId,
          body,
          attachments: attachments as Prisma.InputJsonValue,
          createdAt: now,
        },
      });
      return tx.supportTicket.update({
        where: { id: ticketId },
        data: {
          status,
          ...statusStamps(status, ticket, now),
          lastMessageAt: now,
          lastAuthor: 'REQUESTER',
        },
        include: withMessages,
      });
    });
  }

  async addStaffReply(
    ticketId: string,
    staffUserId: string,
    body: string,
    now: Date,
    audit: SupportAudit,
    attachments: StoredDocumentRef[] = [],
  ): Promise<{ ticket: SupportTicketWithMessages; message: SupportTicketMessage }> {
    return this.db.$transaction(async (tx) => {
      const ticket = await this.lockTicket(tx, ticketId);
      if (!ticket) {
        throw new SupportRuleError('SUPPORT_TICKET_NOT_FOUND');
      }
      if (ticket.status === 'CLOSED') {
        throw new SupportRuleError('SUPPORT_TICKET_CLOSED');
      }
      const message = await tx.supportTicketMessage.create({
        data: {
          ticketId,
          authorType: 'STAFF',
          authorUserId: staffUserId,
          body,
          attachments: attachments as Prisma.InputJsonValue,
          createdAt: now,
        },
      });
      const updated = await tx.supportTicket.update({
        where: { id: ticketId },
        data: {
          status: ticket.status === 'OPEN' ? 'IN_PROGRESS' : ticket.status,
          lastMessageAt: now,
          lastAuthor: 'STAFF',
        },
        include: withMessages,
      });
      await this.audit(tx, ticketId, audit);
      return { ticket: updated, message };
    });
  }

  async updateByStaff(
    ticketId: string,
    patch: SupportStaffPatch,
    now: Date,
    audit: SupportAudit,
  ): Promise<SupportTicketWithMessages> {
    return this.db.$transaction(async (tx) => {
      const ticket = await this.lockTicket(tx, ticketId);
      if (!ticket) {
        throw new SupportRuleError('SUPPORT_TICKET_NOT_FOUND');
      }
      const status = patch.status ?? ticket.status;
      const updated = await tx.supportTicket.update({
        where: { id: ticketId },
        data: {
          status,
          priority: patch.priority ?? ticket.priority,
          ...statusStamps(status, ticket, now),
        },
        include: withMessages,
      });
      await this.audit(tx, ticketId, audit);
      return updated;
    });
  }

  /**
   * Serializes ticket creation per requester (user row lock) or per typed contact
   * (transaction advisory lock) so the open/day limits hold under concurrent submits.
   */
  private async enforceLimit(tx: Tx, limit: SupportCreateLimit): Promise<void> {
    if (limit.kind === 'user') {
      await tx.$queryRaw`SELECT "id" FROM "users" WHERE "id" = ${limit.userId}::uuid FOR UPDATE`;
      const open = await tx.supportTicket.count({
        where: { requesterUserId: limit.userId, status: { in: [...SUPPORT_ACTIVE_STATUSES] } },
      });
      if (open >= limit.maxOpen) {
        throw new SupportRuleError('SUPPORT_TICKET_LIMIT_REACHED');
      }
      return;
    }
    const lockKey = `support-contact:${limit.contact}`;
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${lockKey}))`;
    const recent = await tx.supportTicket.count({
      where: { contact: limit.contact, createdAt: { gte: limit.since } },
    });
    if (recent >= limit.maxPerWindow) {
      throw new SupportRuleError('SUPPORT_CONTACT_LIMIT_REACHED');
    }
  }

  private async lockTicket(tx: Tx, ticketId: string): Promise<SupportTicket | null> {
    await tx.$queryRaw`SELECT "id" FROM "support_tickets" WHERE "id" = ${ticketId}::uuid FOR UPDATE`;
    return tx.supportTicket.findUnique({ where: { id: ticketId } });
  }

  private async audit(tx: Tx, ticketId: string, audit: SupportAudit): Promise<void> {
    await tx.opsAuditLog.create({
      data: {
        actorUserId: audit.actorUserId,
        action: 'SUPPORT_TICKET_UPDATE',
        entityType: 'SUPPORT_TICKET',
        entityId: ticketId,
        reason: audit.reason.slice(0, 500),
        metadata: audit.metadata as Prisma.InputJsonValue,
      },
    });
  }

  private async page(where: Prisma.SupportTicketWhereInput, query: SupportListQuery): Promise<SupportPage> {
    const [rows, total] = await Promise.all([
      this.db.supportTicket.findMany({
        where,
        orderBy: [{ lastMessageAt: 'desc' }, { code: 'desc' }],
        skip: (query.page - 1) * query.limit,
        take: query.limit,
        include: withPreview,
      }),
      this.db.supportTicket.count({ where }),
    ]);
    return {
      total,
      items: rows.map(({ messages, ...ticket }) => ({
        ...ticket,
        lastMessagePreview: messages[0] ? messagePreview(messages[0].body) : '',
      })),
    };
  }
}

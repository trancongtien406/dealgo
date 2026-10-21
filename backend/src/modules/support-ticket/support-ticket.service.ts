import { HttpException, Inject, Injectable, Logger } from '@nestjs/common';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { INBOX_REPOSITORY } from '../communication/inbox/inbox.constants.js';
import type { InboxRepository } from '../communication/inbox/inbox.repository.js';
import { FoodService } from '../food-order/food.service.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import type { IdentityRepository } from '../identity/identity.repository.js';
import { RideService } from '../ride/ride.service.js';
import { SUPPORT_TICKET_REPOSITORY } from './support-ticket.constants.js';
import type {
  CreatePublicSupportTicketDto,
  CreateSupportTicketDto,
  ListMySupportTicketsQueryDto,
  ListOpsSupportTicketsQueryDto,
  PatchOpsSupportTicketDto,
} from './support-ticket.dto.js';
import {
  DocumentStoreService,
  type StoredDocumentRef,
} from '../../platform/storage/document-store.service.js';
import type { SupportAttachmentDto } from './support-ticket.dto.js';
import {
  SupportRuleError,
  readSupportAttachments,
  type SupportRuleCode,
  type SupportTicket,
  type SupportTicketListItem,
  type SupportTicketMessage,
  type SupportTicketRepository,
  type SupportTicketWithMessages,
} from './support-ticket.repository.js';

const DAY_MS = 86_400_000;
const DEFAULT_LIMIT = 20;

const RULE_STATUS: Record<SupportRuleCode, { status: number; message: string }> = {
  SUPPORT_TICKET_NOT_FOUND: { status: 404, message: 'Support ticket not found' },
  SUPPORT_TICKET_LIMIT_REACHED: {
    status: 409,
    message: 'Too many open support tickets; wait for a reply or add to an existing one',
  },
  SUPPORT_CONTACT_LIMIT_REACHED: {
    status: 429,
    message: 'Too many support requests from this contact today',
  },
  SUPPORT_TICKET_CLOSED: { status: 409, message: 'This support ticket is closed' },
};

/** What the requester sees: no staff identities, no internal contact data. */
export type PublicSupportTicket = {
  id: string;
  code: string;
  category: SupportTicket['category'];
  subject: string;
  status: SupportTicket['status'];
  priority: SupportTicket['priority'];
  relatedType: SupportTicket['relatedType'];
  relatedId: string | null;
  /** True when the latest message is from DealGo support (the "replied" chip). */
  awaitingRequester: boolean;
  lastMessagePreview?: string;
  lastMessageAt: string;
  resolvedAt: string | null;
  closedAt: string | null;
  createdAt: string;
  updatedAt: string;
  messages?: Array<{
    id: string;
    author: 'REQUESTER' | 'STAFF';
    body: string;
    attachments: SupportAttachmentView[];
    createdAt: string;
  }>;
};

/** Attachment metadata; bytes via GET .../messages/:messageId/attachments/:index. */
export type SupportAttachmentView = {
  index: number;
  label: string;
  contentType: string;
  sizeBytes: number;
};

export type OpsSupportTicket = Omit<PublicSupportTicket, 'messages'> & {
  channel: SupportTicket['channel'];
  requesterRole: string;
  requester: { userId: string; displayName: string; phone: string | null; email: string | null } | null;
  contactName: string | null;
  contact: string | null;
  externalRef: string | null;
  messages?: Array<{
    id: string;
    author: 'REQUESTER' | 'STAFF';
    authorUserId: string | null;
    body: string;
    attachments: SupportAttachmentView[];
    createdAt: string;
  }>;
};

function fail(status: number, errorCode: string, message: string): never {
  throw new HttpException({ message, errorCode }, status);
}

/** Normalizes a typed contact: lowercase email, or a VN mobile as 0XXXXXXXXX. */
export function normalizeSupportContact(raw: string): string | null {
  const value = raw.trim();
  if (value.includes('@')) {
    const email = value.toLowerCase();
    return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email) ? email : null;
  }
  let digits = value.replace(/[\s.\-()]/g, '');
  if (digits.startsWith('+84')) digits = `0${digits.slice(3)}`;
  else if (/^84\d{9}$/.test(digits)) digits = `0${digits.slice(2)}`;
  return /^0\d{9}$/.test(digits) ? digits : null;
}

@Injectable()
export class SupportTicketService {
  private readonly logger = new Logger(SupportTicketService.name);

  constructor(
    @Inject(SUPPORT_TICKET_REPOSITORY) private readonly tickets: SupportTicketRepository,
    @Inject(INBOX_REPOSITORY) private readonly inbox: InboxRepository,
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    private readonly rides: RideService,
    private readonly food: FoodService,
    private readonly settings: PlatformSettingsService,
    private readonly uploads: DocumentStoreService,
  ) {}

  async create(userId: string, dto: CreateSupportTicketDto): Promise<PublicSupportTicket> {
    await this.assertTextLimit(dto.description);
    if (dto.relatedType && dto.relatedId) {
      const participants =
        dto.relatedType === 'RIDE'
          ? await this.rides.participantUserIds(dto.relatedId)
          : await this.food.participantUserIds(dto.relatedId);
      if (!participants.includes(userId)) {
        fail(404, 'SUPPORT_RELATED_NOT_FOUND', 'The related ride or order was not found');
      }
    }
    const maxOpen = await this.settings.getNumber('SUPPORT_TICKET_MAX_OPEN_PER_USER');
    const attachments = await this.storeAttachments(dto.attachments);
    const created = await this.discardOnFailure(attachments, () =>
      this.tickets.create(
        {
          channel: 'APP',
          requesterUserId: userId,
          requesterRole: dto.role ?? 'CUSTOMER',
          category: dto.category,
          relatedType: dto.relatedType ?? null,
          relatedId: dto.relatedId ?? null,
          subject: dto.subject,
          description: dto.description,
          attachments,
        },
        { kind: 'user', userId, maxOpen },
        new Date(),
      ),
    );
    return toPublic(created);
  }

  async createPublic(dto: CreatePublicSupportTicketDto): Promise<{ code: string; createdAt: string }> {
    await this.assertTextLimit(dto.description);
    const contact = normalizeSupportContact(dto.contact);
    if (!contact) {
      fail(400, 'SUPPORT_CONTACT_INVALID', 'Enter a valid Vietnamese mobile number or email');
    }
    const now = new Date();
    const maxPerWindow = await this.settings.getNumber('SUPPORT_PUBLIC_TICKETS_PER_CONTACT_PER_DAY');
    const created = await this.run(() =>
      this.tickets.create(
        {
          channel: 'WEB',
          requesterUserId: null,
          requesterRole: dto.role,
          contactName: dto.contactName ?? null,
          contact,
          category: dto.category,
          externalRef: dto.externalRef ?? null,
          subject: dto.subject ?? subjectFrom(dto.description),
          description: dto.description,
        },
        { kind: 'contact', contact, maxPerWindow, since: new Date(now.getTime() - DAY_MS) },
        now,
      ),
    );
    return { code: created.code, createdAt: created.createdAt.toISOString() };
  }

  async listMine(
    userId: string,
    query: ListMySupportTicketsQueryDto,
  ): Promise<{
    items: PublicSupportTicket[];
    total: number;
    page: number;
    limit: number;
    activeCount: number;
    doneCount: number;
  }> {
    const page = query.page ?? 1;
    const limit = query.limit ?? DEFAULT_LIMIT;
    const statuses =
      query.state === 'ACTIVE'
        ? (['OPEN', 'IN_PROGRESS'] as const)
        : query.state === 'DONE'
          ? (['RESOLVED', 'CLOSED'] as const)
          : undefined;
    const result = await this.tickets.listForUser(userId, { page, limit, statuses });
    return {
      items: result.items.map(toPublic),
      total: result.total,
      page,
      limit,
      activeCount: result.activeCount,
      doneCount: result.doneCount,
    };
  }

  async getMine(userId: string, id: string): Promise<PublicSupportTicket> {
    const ticket = await this.tickets.findById(id);
    if (!ticket || ticket.requesterUserId !== userId) {
      fail(404, 'SUPPORT_TICKET_NOT_FOUND', 'Support ticket not found');
    }
    return toPublic(ticket);
  }

  async addMine(
    userId: string,
    id: string,
    body: string,
    files: readonly SupportAttachmentDto[] = [],
  ): Promise<PublicSupportTicket> {
    await this.assertTextLimit(body);
    let attachments: StoredDocumentRef[] = [];
    if (files.length > 0) {
      // Check ownership and status before writing bytes, so a refused reply stores nothing.
      const ticket = await this.tickets.findById(id);
      if (!ticket || ticket.requesterUserId !== userId) {
        fail(404, 'SUPPORT_TICKET_NOT_FOUND', 'Support ticket not found');
      }
      if (ticket.status === 'CLOSED') {
        fail(409, 'SUPPORT_TICKET_CLOSED', 'This support ticket is closed');
      }
      attachments = await this.storeAttachments(files);
    }
    const updated = await this.discardOnFailure(attachments, () =>
      this.tickets.addRequesterMessage(id, userId, body, new Date(), attachments),
    );
    return toPublic(updated);
  }

  /** Requester download: only the ticket's own requester. */
  async readMineAttachment(
    userId: string,
    ticketId: string,
    messageId: string,
    index: number,
  ): Promise<{ body: Buffer; contentType: string; filename: string }> {
    const ticket = await this.tickets.findById(ticketId);
    if (!ticket || ticket.requesterUserId !== userId) {
      fail(404, 'SUPPORT_ATTACHMENT_NOT_FOUND', 'Attachment not found');
    }
    return this.readAttachment(ticket, messageId, index);
  }

  async readOpsAttachment(
    ticketId: string,
    messageId: string,
    index: number,
  ): Promise<{ body: Buffer; contentType: string; filename: string }> {
    const ticket = await this.tickets.findById(ticketId);
    if (!ticket) {
      fail(404, 'SUPPORT_ATTACHMENT_NOT_FOUND', 'Attachment not found');
    }
    return this.readAttachment(ticket, messageId, index);
  }

  private async readAttachment(
    ticket: SupportTicketWithMessages,
    messageId: string,
    index: number,
  ): Promise<{ body: Buffer; contentType: string; filename: string }> {
    const message = ticket.messages.find((m) => m.id === messageId);
    const ref = message ? readSupportAttachments(message.attachments)[index] : undefined;
    const file = ref ? await this.uploads.read(ref) : null;
    if (!ref || !file) {
      fail(404, 'SUPPORT_ATTACHMENT_NOT_FOUND', 'Attachment not found');
    }
    const ext = ref.key.slice(ref.key.lastIndexOf('.') + 1);
    return { ...file, filename: `${ticket.code}-${index + 1}.${ext}` };
  }

  /** Runs the DB write; if it fails, removes the files stored for it (no orphan uploads). */
  private async discardOnFailure<T>(stored: readonly StoredDocumentRef[], work: () => Promise<T>): Promise<T> {
    try {
      return await this.run(work);
    } catch (error) {
      await this.uploads.discard(stored);
      throw error;
    }
  }

  private async storeAttachments(
    files: readonly SupportAttachmentDto[] | undefined,
  ): Promise<StoredDocumentRef[]> {
    if (!files || files.length === 0) {
      return [];
    }
    const month = new Date(Date.now() + 7 * 3_600_000).toISOString().slice(0, 7);
    return this.uploads.storeAll(
      `support-attachments/${month}`,
      files.map((file, index) => ({
        label: file.label?.trim() || `attachment-${index + 1}`,
        contentType: file.contentType,
        contentBase64: file.contentBase64,
      })),
    );
  }

  async listForOps(query: ListOpsSupportTicketsQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? DEFAULT_LIMIT;
    const result = await this.tickets.listForOps({
      page,
      limit,
      status: query.status,
      category: query.category,
      channel: query.channel,
      q: query.q,
    });
    return {
      items: await Promise.all(result.items.map((t) => this.toOps(t))),
      total: result.total,
      page,
      limit,
    };
  }

  async getForOps(id: string): Promise<OpsSupportTicket> {
    const ticket = await this.tickets.findById(id);
    if (!ticket) {
      fail(404, 'SUPPORT_TICKET_NOT_FOUND', 'Support ticket not found');
    }
    return this.toOps(ticket);
  }

  async patchForOps(
    staffUserId: string,
    id: string,
    dto: PatchOpsSupportTicketDto,
  ): Promise<OpsSupportTicket> {
    if (dto.status === undefined && dto.priority === undefined) {
      fail(400, 'SUPPORT_PATCH_EMPTY', 'Send a status or a priority');
    }
    const before = await this.tickets.findById(id);
    if (!before) {
      fail(404, 'SUPPORT_TICKET_NOT_FOUND', 'Support ticket not found');
    }
    const updated = await this.run(() =>
      this.tickets.updateByStaff(
        id,
        { status: dto.status, priority: dto.priority },
        new Date(),
        {
          actorUserId: staffUserId,
          reason: dto.reason,
          metadata: {
            op: 'patch',
            code: before.code,
            previousStatus: before.status,
            status: dto.status ?? before.status,
            previousPriority: before.priority,
            priority: dto.priority ?? before.priority,
          },
        },
      ),
    );
    if (dto.status && dto.status !== before.status && dto.status === 'RESOLVED') {
      await this.notify(updated, `support-resolved:${updated.id}:${updated.updatedAt.getTime()}`, {
        title: 'Yêu cầu hỗ trợ đã được giải quyết',
        body: `${updated.code}: ${updated.subject}`,
      });
    }
    return this.toOps(updated);
  }

  async replyForOps(
    staffUserId: string,
    id: string,
    body: string,
    files: readonly SupportAttachmentDto[] = [],
  ): Promise<OpsSupportTicket> {
    await this.assertTextLimit(body);
    const attachments = await this.storeAttachments(files);
    const { ticket, message } = await this.discardOnFailure(attachments, () =>
      this.tickets.addStaffReply(
        id,
        staffUserId,
        body,
        new Date(),
        {
          actorUserId: staffUserId,
          reason: 'Staff reply',
          metadata: { op: 'reply', messageLength: body.length, attachments: attachments.length },
        },
        attachments,
      ),
    );
    await this.notify(ticket, `support-reply:${message.id}`, {
      title: 'DealGo đã phản hồi yêu cầu hỗ trợ',
      body: `${ticket.code}: ${ticket.subject}`,
    });
    return this.toOps(ticket);
  }

  private async notify(
    ticket: SupportTicket,
    sourceEventKey: string,
    text: { title: string; body: string },
  ): Promise<void> {
    if (!ticket.requesterUserId) {
      return;
    }
    try {
      await this.inbox.createMany([
        {
          userId: ticket.requesterUserId,
          category: 'SYSTEM',
          title: text.title,
          body: text.body,
          data: { aggregateType: 'SupportTicket', aggregateId: ticket.id, status: ticket.status },
          sourceEventKey,
        },
      ]);
    } catch (error) {
      // The reply is already stored; a missed inbox row must not fail the staff action.
      this.logger.warn(`support inbox write failed for ${ticket.code}: ${String(error)}`);
    }
  }

  private async assertTextLimit(text: string): Promise<void> {
    const max = await this.settings.getNumber('SUPPORT_TICKET_TEXT_MAX_CHARS');
    if (text.length > max) {
      fail(400, 'SUPPORT_TEXT_TOO_LONG', `Text exceeds ${max} characters`);
    }
  }

  private async run<T>(work: () => Promise<T>): Promise<T> {
    try {
      return await work();
    } catch (error) {
      if (error instanceof SupportRuleError) {
        const mapped = RULE_STATUS[error.code];
        fail(mapped.status, error.code, mapped.message);
      }
      throw error;
    }
  }

  private async toOps(
    ticket: SupportTicketWithMessages | SupportTicketListItem,
  ): Promise<OpsSupportTicket> {
    const user = ticket.requesterUserId
      ? await this.identity.findUserById(ticket.requesterUserId)
      : null;
    const base = toPublic(ticket);
    return {
      ...base,
      channel: ticket.channel,
      requesterRole: ticket.requesterRole,
      requester: user
        ? {
            userId: user.id,
            displayName: user.displayName,
            phone: user.phone ?? null,
            email: user.email ?? null,
          }
        : null,
      contactName: ticket.contactName,
      contact: ticket.contact,
      externalRef: ticket.externalRef,
      messages:
        'messages' in ticket
          ? ticket.messages.map((m: SupportTicketMessage) => ({
              id: m.id,
              author: m.authorType,
              authorUserId: m.authorUserId,
              body: m.body,
              attachments: attachmentViews(m.attachments),
              createdAt: m.createdAt.toISOString(),
            }))
          : undefined,
    };
  }
}

function attachmentViews(value: unknown): SupportAttachmentView[] {
  return readSupportAttachments(value).map((ref, index) => ({
    index,
    label: ref.label,
    contentType: ref.contentType,
    sizeBytes: ref.sizeBytes,
  }));
}

function subjectFrom(description: string): string {
  const firstLine = description.split('\n')[0]?.trim() ?? '';
  const base = firstLine.length >= 3 ? firstLine : description.trim();
  return base.length > 80 ? `${base.slice(0, 79)}…` : base;
}

function toPublic(ticket: SupportTicketWithMessages | SupportTicketListItem): PublicSupportTicket {
  return {
    id: ticket.id,
    code: ticket.code,
    category: ticket.category,
    subject: ticket.subject,
    status: ticket.status,
    priority: ticket.priority,
    relatedType: ticket.relatedType,
    relatedId: ticket.relatedId,
    awaitingRequester: ticket.lastAuthor === 'STAFF',
    ...('lastMessagePreview' in ticket ? { lastMessagePreview: ticket.lastMessagePreview } : {}),
    lastMessageAt: ticket.lastMessageAt.toISOString(),
    resolvedAt: ticket.resolvedAt?.toISOString() ?? null,
    closedAt: ticket.closedAt?.toISOString() ?? null,
    createdAt: ticket.createdAt.toISOString(),
    updatedAt: ticket.updatedAt.toISOString(),
    ...('messages' in ticket
      ? {
          messages: ticket.messages.map((m) => ({
            id: m.id,
            author: m.authorType,
            body: m.body,
            attachments: attachmentViews(m.attachments),
            createdAt: m.createdAt.toISOString(),
          })),
        }
      : {}),
  };
}

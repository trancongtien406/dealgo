import type { PrismaClient } from '../../../generated/prisma/client.js';
import type {
  ChatContext,
  ChatMessagePage,
  ChatMessageView,
  ChatRepository,
} from './chat.repository.js';

export class PrismaChatRepository implements ChatRepository {
  constructor(private readonly db: PrismaClient) {}

  async listMessages(
    context: ChatContext,
    page: number,
    limit: number,
  ): Promise<ChatMessagePage> {
    const thread = await this.findThread(context);
    if (!thread) {
      return { items: [], total: 0 };
    }
    const where = { threadId: thread.id };
    const [total, rows] = await Promise.all([
      this.db.chatMessage.count({ where }),
      this.db.chatMessage.findMany({
        where,
        orderBy: { createdAt: 'asc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return {
      total,
      items: rows.map(toView),
    };
  }

  async postMessage(
    context: ChatContext,
    senderUserId: string,
    body: string,
  ): Promise<ChatMessageView> {
    const thread = await this.ensureThread(context);
    const row = await this.db.chatMessage.create({
      data: {
        threadId: thread.id,
        senderUserId,
        body,
      },
    });
    return toView(row);
  }

  private async findThread(context: ChatContext) {
    if (context.kind === 'ride') {
      return this.db.chatThread.findUnique({ where: { rideId: context.rideId } });
    }
    return this.db.chatThread.findUnique({ where: { foodOrderId: context.foodOrderId } });
  }

  private async ensureThread(context: ChatContext) {
    const existing = await this.findThread(context);
    if (existing) {
      return existing;
    }
    return this.db.chatThread.create({
      data:
        context.kind === 'ride'
          ? { rideId: context.rideId }
          : { foodOrderId: context.foodOrderId },
    });
  }
}

function toView(row: {
  id: string;
  threadId: string;
  senderUserId: string;
  body: string;
  createdAt: Date;
}): ChatMessageView {
  return {
    id: row.id,
    threadId: row.threadId,
    senderUserId: row.senderUserId,
    body: row.body,
    createdAt: row.createdAt,
  };
}

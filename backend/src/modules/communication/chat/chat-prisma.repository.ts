import { randomUUID } from 'node:crypto';
import type { PrismaClient } from '../../../generated/prisma/client.js';
import { chatAad, type ChatCipher } from './chat-cipher.js';
import type {
  ChatContext,
  ChatMessagePage,
  ChatMessageView,
  ChatRepository,
} from './chat.repository.js';

export class PrismaChatRepository implements ChatRepository {
  constructor(
    private readonly db: PrismaClient,
    private readonly cipher: ChatCipher | null = null,
  ) {}

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
      // Page 1 = the newest `limit` messages (a chat opens at the bottom); each page is
      // returned oldest → newest so the client can render it as-is.
      this.db.chatMessage.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return {
      total,
      items: rows.reverse().map((row) => toView(row, this.cipher)),
    };
  }

  async postMessage(
    context: ChatContext,
    senderUserId: string,
    body: string,
  ): Promise<ChatMessageView> {
    const thread = await this.ensureThread(context);
    const id = randomUUID();
    const sealed = this.cipher?.encrypt(body, chatAad(id, thread.id));
    const row = await this.db.chatMessage.create({
      data: sealed
        ? {
            id,
            threadId: thread.id,
            senderUserId,
            body: null,
            bodyCiphertext: sealed.ciphertext,
            keyVersion: sealed.keyVersion,
          }
        : { id, threadId: thread.id, senderUserId, body },
    });
    return toView(row, this.cipher);
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

export function toView(
  row: {
    id: string;
    threadId: string;
    senderUserId: string;
    body: string | null;
    bodyCiphertext?: string | null;
    keyVersion?: number | null;
    createdAt: Date;
  },
  cipher: ChatCipher | null,
): ChatMessageView {
  let body = row.body ?? '';
  if (row.bodyCiphertext) {
    if (!cipher || row.keyVersion == null) {
      // Fail closed: never return ciphertext or guess; no message content in the error.
      throw new Error(`chat message ${row.id} is encrypted but no chat key is configured`);
    }
    body = cipher.decrypt(
      { ciphertext: row.bodyCiphertext, keyVersion: row.keyVersion },
      chatAad(row.id, row.threadId),
    );
  }
  return {
    id: row.id,
    threadId: row.threadId,
    senderUserId: row.senderUserId,
    body,
    createdAt: row.createdAt,
  };
}

import { randomUUID } from 'node:crypto';

/** Food orders keep two separate threads: customer↔driver and customer↔shop. */
export type FoodChatChannel = 'DRIVER' | 'MERCHANT';

export type ChatContext =
  | { kind: 'ride'; rideId: string }
  | { kind: 'food'; foodOrderId: string; channel: FoodChatChannel };

export type ChatMessageView = {
  id: string;
  threadId: string;
  senderUserId: string;
  body: string;
  createdAt: Date;
};

export type ChatMessagePage = {
  items: ChatMessageView[];
  total: number;
};

export interface ChatRepository {
  listMessages(context: ChatContext, page: number, limit: number): Promise<ChatMessagePage>;
  postMessage(
    context: ChatContext,
    senderUserId: string,
    body: string,
  ): Promise<ChatMessageView>;
}

type MemoryThread = {
  id: string;
  rideId: string | null;
  foodOrderId: string | null;
  channel: FoodChatChannel;
  messages: ChatMessageView[];
};

export class MemoryChatRepository implements ChatRepository {
  private readonly threads = new Map<string, MemoryThread>();

  async listMessages(
    context: ChatContext,
    page: number,
    limit: number,
  ): Promise<ChatMessagePage> {
    const thread = this.findThread(context);
    if (!thread) {
      return { items: [], total: 0 };
    }
    // Same contract as Prisma: page 1 = newest `limit`, each page oldest → newest.
    const newest = thread.messages
      .map((message, index) => ({ message, index }))
      .sort((a, b) => b.message.createdAt.getTime() - a.message.createdAt.getTime() || b.index - a.index)
      .map(({ message }) => message);
    const start = (page - 1) * limit;
    return {
      items: newest.slice(start, start + limit).reverse(),
      total: newest.length,
    };
  }

  async postMessage(
    context: ChatContext,
    senderUserId: string,
    body: string,
  ): Promise<ChatMessageView> {
    let thread = this.findThread(context);
    if (!thread) {
      thread = {
        id: randomUUID(),
        rideId: context.kind === 'ride' ? context.rideId : null,
        foodOrderId: context.kind === 'food' ? context.foodOrderId : null,
        channel: context.kind === 'food' ? context.channel : 'DRIVER',
        messages: [],
      };
      this.threads.set(thread.id, thread);
    }
    const message: ChatMessageView = {
      id: randomUUID(),
      threadId: thread.id,
      senderUserId,
      body,
      createdAt: new Date(),
    };
    thread.messages.push(message);
    return message;
  }

  private findThread(context: ChatContext): MemoryThread | undefined {
    for (const thread of this.threads.values()) {
      if (context.kind === 'ride' && thread.rideId === context.rideId) {
        return thread;
      }
      if (
        context.kind === 'food' &&
        thread.foodOrderId === context.foodOrderId &&
        thread.channel === context.channel
      ) {
        return thread;
      }
    }
    return undefined;
  }
}

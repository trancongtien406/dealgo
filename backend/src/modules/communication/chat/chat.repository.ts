import { randomUUID } from 'node:crypto';

export type ChatContext =
  | { kind: 'ride'; rideId: string }
  | { kind: 'food'; foodOrderId: string };

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
    const sorted = [...thread.messages].sort(
      (a, b) => a.createdAt.getTime() - b.createdAt.getTime(),
    );
    const start = (page - 1) * limit;
    return {
      items: sorted.slice(start, start + limit),
      total: sorted.length,
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
      if (context.kind === 'food' && thread.foodOrderId === context.foodOrderId) {
        return thread;
      }
    }
    return undefined;
  }
}

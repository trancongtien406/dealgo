import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';

export type DeliveryStatus = 'PENDING' | 'ASSIGNED' | 'PICKED_UP' | 'COMPLETED' | 'CANCELLED';

export interface DeliveryTask {
  id: string;
  orderId: string;
  driverId?: string;
  status: DeliveryStatus;
  pickupAddress: string;
  dropoffAddress: string;
  createdAt: Date;
  updatedAt: Date;
}

export type CreateDeliveryTaskInput = {
  orderId: string;
  pickupAddress: string;
  dropoffAddress: string;
};

@Injectable()
export class DeliveryService {
  private readonly tasks = new Map<string, DeliveryTask>();

  createTask(input: CreateDeliveryTaskInput): DeliveryTask {
    const task: DeliveryTask = {
      id: randomUUID(),
      orderId: input.orderId,
      status: 'PENDING',
      pickupAddress: input.pickupAddress,
      dropoffAddress: input.dropoffAddress,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    this.tasks.set(task.id, task);
    return task;
  }

  assignDriver(taskId: string, driverId: string): DeliveryTask | null {
    const task = this.tasks.get(taskId);
    if (!task) return null;
    task.driverId = driverId;
    task.status = 'ASSIGNED';
    task.updatedAt = new Date();
    return task;
  }

  markPickedUp(taskId: string): DeliveryTask | null {
    const task = this.tasks.get(taskId);
    if (!task) return null;
    task.status = 'PICKED_UP';
    task.updatedAt = new Date();
    return task;
  }

  markCompleted(taskId: string): DeliveryTask | null {
    const task = this.tasks.get(taskId);
    if (!task) return null;
    task.status = 'COMPLETED';
    task.updatedAt = new Date();
    return task;
  }

  getTask(taskId: string): DeliveryTask | null {
    return this.tasks.get(taskId) ?? null;
  }
}

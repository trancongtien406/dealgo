import { HttpException, Inject, Injectable } from '@nestjs/common';
import { ADDRESS_BOOK_REPOSITORY } from './address-book.constants.js';
import type { CreateSavedAddressDto, UpdateSavedAddressDto } from './address-book.dto.js';
import {
  AddressRuleError,
  type AddressBookRepository,
  type SavedAddress,
} from './address-book.repository.js';

export type PublicSavedAddress = Omit<SavedAddress, 'createdAt' | 'updatedAt'> & {
  createdAt: string;
  updatedAt: string;
};

const STATUS: Record<AddressRuleError['code'], { status: number; message: string }> = {
  ADDRESS_NOT_FOUND: { status: 404, message: 'Address not found' },
  ADDRESS_LIMIT_REACHED: { status: 409, message: 'Address book is full' },
  ADDRESS_KIND_TAKEN: { status: 409, message: 'Home or work address already saved' },
};

@Injectable()
export class AddressBookService {
  constructor(
    @Inject(ADDRESS_BOOK_REPOSITORY) private readonly addresses: AddressBookRepository,
  ) {}

  async list(userId: string): Promise<{ items: PublicSavedAddress[] }> {
    return { items: (await this.addresses.list(userId)).map(publish) };
  }

  create(userId: string, dto: CreateSavedAddressDto): Promise<PublicSavedAddress> {
    return this.run(() => this.addresses.create(userId, dto));
  }

  update(userId: string, id: string, dto: UpdateSavedAddressDto): Promise<PublicSavedAddress> {
    return this.run(() => this.addresses.update(userId, id, dto));
  }

  async remove(userId: string, id: string): Promise<{ deleted: true }> {
    await this.run(async () => {
      await this.addresses.remove(userId, id);
      return null;
    });
    return { deleted: true };
  }

  private async run<T extends SavedAddress | null>(
    work: () => Promise<T>,
  ): Promise<T extends SavedAddress ? PublicSavedAddress : null> {
    try {
      const result = await work();
      return (result ? publish(result) : null) as T extends SavedAddress
        ? PublicSavedAddress
        : null;
    } catch (error) {
      if (error instanceof AddressRuleError) {
        const mapped = STATUS[error.code];
        throw new HttpException(
          { message: mapped.message, errorCode: error.code },
          mapped.status,
        );
      }
      throw error;
    }
  }
}

function publish(row: SavedAddress): PublicSavedAddress {
  return {
    ...row,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

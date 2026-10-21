import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  PrismaModule,
  PrismaService,
  resolvePersistenceRepository,
} from '../../platform/database/index.js';
import type { AppEnv } from '../../platform/config/index.js';
import { IdentityModule } from '../identity/index.js';
import { ADDRESS_BOOK_REPOSITORY } from './address-book.constants.js';
import { AddressBookController } from './address-book.controller.js';
import { PrismaAddressBookRepository } from './address-book-prisma.repository.js';
import { MemoryAddressBookRepository, type AddressBookRepository } from './address-book.repository.js';
import { AddressBookService } from './address-book.service.js';

@Module({
  imports: [PrismaModule, IdentityModule],
  controllers: [AddressBookController],
  providers: [
    AddressBookService,
    {
      provide: ADDRESS_BOOK_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): AddressBookRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, AddressBookRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryAddressBookRepository(),
          createPrisma: (client) => new PrismaAddressBookRepository(client),
        }),
    },
  ],
  exports: [AddressBookService, ADDRESS_BOOK_REPOSITORY],
})
export class AddressBookModule {}

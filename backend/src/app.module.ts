import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_FILTER, APP_INTERCEPTOR, APP_PIPE } from '@nestjs/core';
import { ThrottlerModule, type ThrottlerModuleOptions } from '@nestjs/throttler';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { createValidationPipe, HttpExceptionFilter, ResponseInterceptor } from './platform/http/index.js';
import { RedisThrottlerStorage } from './platform/cache/index.js';
import { loadEnv, type AppEnv } from './platform/config/index.js';
import { FoodModule } from './modules/food-order/index.js';
import { HealthModule } from './platform/health/index.js';
import { IdentityModule } from './modules/identity/index.js';
import { LedgerModule } from './modules/ledger/index.js';
import { MapsModule } from './integrations/maps/index.js';
import { PartnerModule } from './modules/partner/index.js';
import { PaymentModule } from './modules/payment/index.js';
import { PrismaModule } from './platform/database/index.js';
import { ChatModule } from './modules/communication/chat/index.js';
import { OpsModule } from './modules/operations/index.js';
import { OutboxModule } from './modules/communication/outbox/index.js';
import { PushModule } from './integrations/push/index.js';
import { RealtimeModule } from './modules/communication/realtime/index.js';
import { RideModule } from './modules/ride/index.js';
import { VoiceModule } from './integrations/voice/index.js';
import { PlatformSettingsModule } from './platform/settings/index.js';
import { AuditModule } from './platform/audit/index.js';
import { ServiceAreaModule } from './modules/service-area/index.js';
import { SupportModule } from './modules/support/index.js';
import { PublicPagesModule } from './modules/public-pages/index.js';
import { AppLinksModule } from './modules/app-links/index.js';
import { SiteConfigModule } from './modules/site-config/index.js';
import { AppVersionModule } from './modules/app-version/index.js';
import { AppCheckModule } from './modules/app-check/app-check.module.js';
import { LegalConsentModule } from './modules/legal-consent/index.js';
import { SettlementModule } from './modules/settlement/index.js';
import { NotificationModule } from './modules/communication/notifications/index.js';
import { MerchantModule } from './modules/merchant/index.js';
import { CatalogModule } from './modules/catalog/index.js';
import { PricingModule } from './modules/pricing/index.js';
import { DeliveryModule } from './modules/delivery/index.js';
import { PromotionModule } from './modules/promotion/index.js';
import { InboxModule } from './modules/communication/inbox/index.js';
import { AddressBookModule } from './modules/address-book/index.js';
import { PlacesModule } from './modules/places/index.js';
import { IntegrationsAdminModule } from './modules/integrations-admin/index.js';
import { SystemErrorsModule } from './modules/system-errors/index.js';
import { OpsEventsModule } from './platform/ops-events/index.js';
import { RatingModule } from './modules/rating/index.js';
import { DriverCardModule } from './modules/driver-card/index.js';
import { RideShareModule } from './modules/ride-share/index.js';
import { AvatarModule } from './modules/avatar/index.js';
import { SupportTicketModule } from './modules/support-ticket/index.js';
import { CustomerActivityModule } from './modules/customer-activity/index.js';
import { DriverHistoryModule } from './modules/driver-history/index.js';
import { DriverCreditModule } from './modules/driver-credit/index.js';
import { AccountDeletionModule } from './modules/account-deletion/index.js';
import { AccountSettingsModule } from './modules/account-settings/index.js';
import { RoutingModule } from './modules/routing/index.js';
import { HomeBannerModule } from './modules/home-banner/index.js';
import { FoodCategoryModule } from './modules/food-category/index.js';

function buildThrottlerOptions(config: ConfigService<AppEnv, true>): ThrottlerModuleOptions {
  const throttlers = [
    {
      ttl: config.get('OTP_THROTTLE_TTL_MS', { infer: true }),
      limit: config.get('OTP_THROTTLE_LIMIT', { infer: true }),
    },
  ];
  const redisUrl = config.get('REDIS_URL', { infer: true });
  if (redisUrl) {
    return {
      throttlers,
      storage: new RedisThrottlerStorage(redisUrl),
    };
  }
  return { throttlers };
}

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: (config: Record<string, unknown>) => loadEnv(config),
    }),
    // REDIS_URL → RedisThrottlerStorage; otherwise in-memory (single process).
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService<AppEnv, true>) => buildThrottlerOptions(config),
    }),
    PrismaModule,
    HealthModule,
    IdentityModule,
    PartnerModule,
    MapsModule,
    PaymentModule,
    LedgerModule,
    RideModule,
    FoodModule,
    ChatModule,
    VoiceModule,
    PushModule,
    RealtimeModule,
    OutboxModule,
    PlatformSettingsModule,
    AuditModule,
    ServiceAreaModule,
    SupportModule,
    PublicPagesModule,
    AppLinksModule,
    SiteConfigModule,
    AppVersionModule,
    AppCheckModule,
    LegalConsentModule,
    SettlementModule,
    NotificationModule,
    MerchantModule,
    CatalogModule,
    PricingModule,
    DeliveryModule,
    PromotionModule,
    InboxModule,
    AddressBookModule,
    PlacesModule,
    RatingModule,
    DriverCardModule,
    RideShareModule,
    AvatarModule,
    SupportTicketModule,
    CustomerActivityModule,
    DriverHistoryModule,
    AccountDeletionModule,
    AccountSettingsModule,
    RoutingModule,
    HomeBannerModule,
    FoodCategoryModule,
    OpsModule,
    IntegrationsAdminModule,
    SystemErrorsModule,
    OpsEventsModule,
    DriverCreditModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    { provide: APP_PIPE, useFactory: createValidationPipe },
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
    { provide: APP_INTERCEPTOR, useClass: ResponseInterceptor },
  ],
})
export class AppModule {}

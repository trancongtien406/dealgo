import { HttpException, Inject, Injectable } from '@nestjs/common';
import { PlatformSettingsService } from '../../../platform/settings/platform-settings.service.js';
import {
  PAYMENT_METHOD_CODES,
  PAYMENT_SERVICES,
  normalizePaymentMethodRegistry,
  type PaymentMethodCode,
  type PaymentMethodRegistryValue,
  type PaymentServiceCode,
} from '../../../platform/settings/payment-method-registry.js';
import { PAYMENT_ADAPTERS, type PaymentAdapterMap } from './payment-adapters.js';
import { PAYMENT_GATEWAY_OPTIONS, type PaymentGatewayOptions } from './payment-gateway.options.js';
import { PAYMENT_METHOD_CATALOG, type PaymentMethodGroup } from './payment-method.catalog.js';

export type AdapterKindView = 'NONE' | 'REAL' | 'STUB';

export type OpsPaymentMethodView = {
  code: PaymentMethodCode;
  label: string;
  group: PaymentMethodGroup;
  provider: string | null;
  adapterKind: AdapterKindView;
  /** Env key names only, never values. */
  requiredEnv: string[];
  configured: boolean;
  services: Record<PaymentServiceCode, boolean>;
  sortOrder: number;
  unsupportedReason: string | null;
  /** Effective availability per service (flag + adapter REAL + configured). */
  availableFor: Record<PaymentServiceCode, boolean>;
  locked: boolean;
};

export type PublicPaymentMethodView = {
  code: PaymentMethodCode;
  label: string;
  subtitle: string | null;
  group: PaymentMethodGroup;
  available: boolean;
  reason: string | null;
  requiresRedirect: boolean;
  sortOrder: number;
};

export type PaymentMethodPatch = {
  code: PaymentMethodCode;
  services?: Partial<Record<PaymentServiceCode, boolean>>;
  sortOrder?: number;
  unsupportedReason?: string | null;
};

export function paymentMethodUnavailable(code: string, reason: string | null): HttpException {
  return new HttpException(
    {
      message: `Payment method ${code} is not available${reason ? `: ${reason}` : ''}`,
      errorCode: 'PAYMENT_METHOD_UNAVAILABLE',
    },
    422,
  );
}

@Injectable()
export class PaymentMethodRegistryService {
  constructor(
    private readonly settings: PlatformSettingsService,
    @Inject(PAYMENT_ADAPTERS) private readonly adapters: PaymentAdapterMap,
    @Inject(PAYMENT_GATEWAY_OPTIONS) private readonly options: PaymentGatewayOptions,
  ) {}

  private async readRegistry(): Promise<{ registry: PaymentMethodRegistryValue; walletEnabled: boolean }> {
    let registry: PaymentMethodRegistryValue = { methods: {} };
    let walletEnabled = false;
    try {
      registry = normalizePaymentMethodRegistry(await this.settings.getJson('PAYMENT_METHOD_REGISTRY'));
    } catch {
      registry = { methods: {} };
    }
    try {
      walletEnabled = await this.settings.getBoolean('PAYMENT_WALLET_ENABLED');
    } catch {
      walletEnabled = false;
    }
    return { registry, walletEnabled };
  }

  async listForOps(): Promise<{ walletEnabled: boolean; publicBaseUrlConfigured: boolean; methods: OpsPaymentMethodView[] }> {
    const { registry, walletEnabled } = await this.readRegistry();
    const methods = PAYMENT_METHOD_CATALOG.map((entry): OpsPaymentMethodView => {
      const saved = registry.methods[entry.code];
      const adapter = entry.provider ? this.adapters[entry.provider] : undefined;
      const adapterKind: AdapterKindView = entry.provider === null ? 'NONE' : adapter?.kind ?? 'STUB';
      const configured =
        entry.provider === null
          ? true
          : Boolean(adapter?.isConfigured()) && Boolean(this.options.publicBaseUrl);
      const services: Record<PaymentServiceCode, boolean> =
        entry.code === 'CASH'
          ? { BIKE: true, CAR: true, FOOD: true }
          : saved?.services ?? { BIKE: false, CAR: false, FOOD: false };
      const gate = (svc: PaymentServiceCode) => {
        if (entry.code === 'CASH') {
          return true;
        }
        if (entry.code === 'DEALGO_WALLET' && !walletEnabled) {
          return false;
        }
        return services[svc] && adapterKind === 'REAL' && configured;
      };
      return {
        code: entry.code,
        label: entry.label,
        group: entry.group,
        provider: entry.provider,
        adapterKind,
        requiredEnv: [...(adapter?.requiredEnv() ?? [])],
        configured,
        services,
        sortOrder: saved?.sortOrder ?? entry.defaultSortOrder,
        unsupportedReason: saved?.unsupportedReason ?? null,
        availableFor: { BIKE: gate('BIKE'), CAR: gate('CAR'), FOOD: gate('FOOD') },
        locked: entry.code === 'CASH',
      };
    }).sort((a, b) => a.sortOrder - b.sortOrder || a.code.localeCompare(b.code));
    return { walletEnabled, publicBaseUrlConfigured: Boolean(this.options.publicBaseUrl), methods };
  }

  async list(service: PaymentServiceCode): Promise<PublicPaymentMethodView[]> {
    const ops = await this.listForOps();
    return ops.methods.map((m) => {
      const entry = PAYMENT_METHOD_CATALOG.find((c) => c.code === m.code)!;
      const available = m.availableFor[service];
      return {
        code: m.code,
        label: m.label,
        subtitle: entry.subtitle,
        group: m.group,
        available,
        reason: available ? null : m.unsupportedReason ?? (entry.defaultReason || 'Không khả dụng'),
        requiresRedirect: entry.provider !== null,
        sortOrder: m.sortOrder,
      };
    });
  }

  async isSelectable(service: PaymentServiceCode, code: string): Promise<{ ok: boolean; reason: string | null }> {
    if (code === 'CASH') {
      return { ok: true, reason: null };
    }
    const methods = await this.list(service);
    const hit = methods.find((m) => m.code === code);
    if (!hit) {
      return { ok: false, reason: 'Phương thức không tồn tại' };
    }
    return { ok: hit.available, reason: hit.reason };
  }

  /** Throws 422 PAYMENT_METHOD_UNAVAILABLE unless the method is usable for the service now. */
  async assertSelectable(service: PaymentServiceCode, code: string): Promise<PaymentMethodCode> {
    const result = await this.isSelectable(service, code);
    if (!result.ok) {
      throw paymentMethodUnavailable(code, result.reason);
    }
    return code as PaymentMethodCode;
  }

  async update(
    input: { methods?: PaymentMethodPatch[]; walletEnabled?: boolean },
    reason: string,
    actorUserId: string,
  ) {
    if (input.methods && input.methods.length > 0) {
      const { registry } = await this.readRegistry();
      const next: PaymentMethodRegistryValue = { methods: { ...registry.methods } };
      for (const patch of input.methods) {
        if (!(PAYMENT_METHOD_CODES as readonly string[]).includes(patch.code)) {
          throw new HttpException({ message: `Unknown method ${patch.code}`, errorCode: 'PAYMENT_METHOD_UNKNOWN' }, 400);
        }
        const entry = PAYMENT_METHOD_CATALOG.find((c) => c.code === patch.code)!;
        const current = next.methods[patch.code] ?? {
          services: { BIKE: false, CAR: false, FOOD: false },
          sortOrder: entry.defaultSortOrder,
          unsupportedReason: null,
        };
        const services = { ...current.services };
        for (const svc of PAYMENT_SERVICES) {
          if (patch.services && typeof patch.services[svc] === 'boolean') {
            services[svc] = patch.services[svc]!;
          }
        }
        next.methods[patch.code] = {
          services,
          sortOrder: patch.sortOrder ?? current.sortOrder,
          unsupportedReason:
            patch.unsupportedReason === undefined ? current.unsupportedReason : patch.unsupportedReason,
        };
      }
      await this.settings.patch('PAYMENT_METHOD_REGISTRY', JSON.stringify(next), reason, actorUserId);
    }
    if (typeof input.walletEnabled === 'boolean') {
      await this.settings.patch('PAYMENT_WALLET_ENABLED', String(input.walletEnabled), reason, actorUserId);
    }
    return this.listForOps();
  }
}

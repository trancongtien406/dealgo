import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsDefined,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  Matches,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class GeoPointDto {
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  lat!: number;

  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  lng!: number;

  @IsString()
  @MinLength(1)
  @MaxLength(160)
  label!: string;
}

export class CreateRideDto {
  @IsDefined()
  @ValidateNested()
  @Type(() => GeoPointDto)
  pickup!: GeoPointDto;

  @IsDefined()
  @ValidateNested()
  @Type(() => GeoPointDto)
  dropoff!: GeoPointDto;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  offeredFareVnd!: number;

  /** Required Ride class (MOTORBIKE | CAR_4 | CAR_7, …). No silent default (DG-DEC-VEH-001). */
  @IsString()
  @MinLength(1)
  @MaxLength(32)
  @Matches(/^[A-Za-z0-9_]+$/)
  vehicleClassCode!: string;

  /**
   * Multi-stop: intermediate stops in visiting order (admin flag + max per service, hard cap 5).
   * Omitted / empty = single destination.
   */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @ValidateNested({ each: true })
  @Type(() => GeoPointDto)
  stops?: GeoPointDto[];

  /** One-tap re-post of the customer's own EXPIRED request. */
  @IsOptional()
  @IsUUID()
  repostOfRideId?: string;
}

export class QuoteRideDto {
  @IsDefined()
  @ValidateNested()
  @Type(() => GeoPointDto)
  pickup!: GeoPointDto;

  @IsDefined()
  @ValidateNested()
  @Type(() => GeoPointDto)
  dropoff!: GeoPointDto;

  /**
   * Multi-stop: intermediate stops in visiting order (admin flag + max per service, hard cap 5).
   * Omitted / empty = single destination.
   */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @ValidateNested({ each: true })
  @Type(() => GeoPointDto)
  stops?: GeoPointDto[];
}

export class CreateOfferDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  amountVnd!: number;

  /** Route version the driver saw; a stale one is rejected with RIDE_ROUTE_CHANGED. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  routeVersion?: number;
}

/** Customer replaces the stop list while NEGOTIATING (empty = back to single destination). */
export class UpdateStopsDto {
  @IsDefined()
  @IsArray()
  @ArrayMaxSize(5)
  @ValidateNested({ each: true })
  @Type(() => GeoPointDto)
  stops!: GeoPointDto[];

  /** Optional new final destination. */
  @IsOptional()
  @ValidateNested()
  @Type(() => GeoPointDto)
  dropoff?: GeoPointDto;

  /** Optional new bid (must respect the re-quoted floor). Defaults to the current bid. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  offeredFareVnd?: number;

  /** Optimistic check: the version the app edited (409 RIDE_ROUTE_CHANGED if stale). */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  routeVersion?: number;
}

export class StartTripDto {
  /** DEC-PROD-017: the 4-digit code the customer reads out at pickup. */
  @IsString()
  @Matches(/^\d{4}$/, { message: 'pickupCode must be 4 digits' })
  pickupCode!: string;
}

export class SelectOfferDto {
  @IsUUID()
  offerId!: string;

  /** DEC-PROD-024: optional voucher, redeemed atomically with the selection on the agreed fare. */
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  @Matches(/^[A-Za-z0-9_-]+$/)
  voucherCode?: string;
}

export class RidePageQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;

  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsString()
  zone?: string;

  @IsOptional()
  @IsString()
  /** Accepted for Admin UI compat; Ride has no serviceType column — ignored server-side. */
  serviceType?: string;
}

export class OpsInterveneDto {
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

/** Authenticated road geometry for the app (same provider as Admin DEC-PROD-045). */
export class RideRouteQueryDto {
  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  fromLat!: number;

  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  fromLng!: number;

  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  toLat!: number;

  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  toLng!: number;

  /** Multi-stop preview: up to 5 waypoints as `lat,lng|lat,lng` between from and to. */
  @IsOptional()
  @IsString()
  @MaxLength(220)
  @Matches(/^-?\d{1,2}(\.\d+)?,-?\d{1,3}(\.\d+)?(\|-?\d{1,2}(\.\d+)?,-?\d{1,3}(\.\d+)?){0,4}$/, {
    message: 'via must be up to 5 "lat,lng" pairs separated by |',
  })
  via?: string;
}

/** Parses RideRouteQueryDto.via (already shape-checked) into in-range points. */
export function parseRouteVia(via: string | undefined): Array<{ lat: number; lng: number }> {
  if (!via) return [];
  return via.split('|').map((pair) => {
    const [lat, lng] = pair.split(',').map(Number) as [number, number];
    return { lat, lng };
  }).filter((p) => Math.abs(p.lat) <= 90 && Math.abs(p.lng) <= 180);
}

/** Customer raises the bid (must be above the current one; class max still applies). */
export class RaiseFareDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  amountVnd!: number;
}

/** Customer rejects one driver's offer. */
export class DeclineOfferDto {
  @IsUUID()
  offerId!: string;
}

/** Reasons a driver may give when cancelling an assigned ride. */
export const DRIVER_CANCEL_REASONS = [
  'CUSTOMER_UNREACHABLE',
  'PICKUP_TOO_FAR',
  'VEHICLE_PROBLEM',
  'SAFETY_CONCERN',
  'CUSTOMER_ASKED',
  'OTHER',
] as const;

export class DriverCancelRideDto {
  @IsString()
  @IsIn(DRIVER_CANCEL_REASONS as unknown as string[])
  reasonCode!: (typeof DRIVER_CANCEL_REASONS)[number];
}

/** Driver → customer rating. */
export class RateCustomerDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  stars!: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(6)
  @IsIn(['ON_TIME', 'POLITE', 'CLEAR_PICKUP', 'LATE', 'RUDE', 'WRONG_PICKUP'], { each: true })
  tags?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(300)
  comment?: string;
}

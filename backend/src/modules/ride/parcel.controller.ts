import {
  Body,
  Controller,
  Get,
  Header,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { CurrentActor, CustomerSessionGuard, type RequestActor } from '../identity/access-auth.guard.js';
import {
  CreateParcelDto,
  ParcelDeliverDto,
  ParcelFailDto,
  ParcelPickupDto,
  ParcelReturnedDto,
  QuoteParcelDto,
} from './parcel.dto.js';
import { ParcelService } from './parcel.service.js';
import { readIdempotencyKey } from './ride.controller.js';
import { rideError } from './ride.error.js';
import type { ParcelPhotoKind } from './ride-parcel.store.js';

const PHOTO_KINDS: readonly ParcelPhotoKind[] = ['item', 'pickup', 'delivery', 'return'];

export function parsePhotoKind(kind: string): ParcelPhotoKind {
  if (!(PHOTO_KINDS as readonly string[]).includes(kind)) {
    throw rideError(400, 'VALIDATION_ERROR', 'Unknown photo kind');
  }
  return kind as ParcelPhotoKind;
}

/** DEC-PROD-071 (DRAFT) Giao hang. Offers/select/cancel/track reuse /v1/rides/:id/*. */
@ApiTags('parcels')
@ApiBearerAuth()
@Controller('v1/parcels')
@UseGuards(CustomerSessionGuard)
export class ParcelController {
  constructor(private readonly parcels: ParcelService) {}

  @Get('size-classes')
  @ApiOperation({ summary: 'Enabled package size classes (admin PARCEL_SIZE_CLASSES)' })
  sizeClasses() {
    return this.parcels.sizeClasses();
  }

  @Post('quote')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Server quote for a parcel: parcel-enabled classes + size surcharge' })
  quote(@CurrentActor() actor: RequestActor, @Body() dto: QuoteParcelDto) {
    return this.parcels.quote(actor, dto);
  }

  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Book a parcel (negotiating ride + package). Idempotency-Key required' })
  create(
    @CurrentActor() actor: RequestActor,
    @Headers('idempotency-key') idempotencyKey: string | string[] | undefined,
    @Body() dto: CreateParcelDto,
  ) {
    return this.parcels.create(actor, readIdempotencyKey(idempotencyKey), dto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Parcel detail (ride view + package); participants only' })
  get(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.parcels.get(actor, id);
  }

  @Post(':id/pickup')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Driver picked up the package (photo, pickup code if required) -> IN_TRIP' })
  pickup(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ParcelPickupDto) {
    return this.parcels.pickup(actor, id, dto);
  }

  @Post(':id/deliver')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Driver delivered (photo, recipient code if required) -> COMPLETED/DELIVERED' })
  deliver(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ParcelDeliverDto) {
    return this.parcels.deliver(actor, id, dto);
  }

  @Post(':id/fail')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delivery failed -> RETURNING to sender' })
  fail(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ParcelFailDto) {
    return this.parcels.fail(actor, id, dto);
  }

  @Post(':id/returned')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Package returned to sender (photo) -> COMPLETED/RETURNED' })
  returned(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ParcelReturnedDto) {
    return this.parcels.returned(actor, id, dto);
  }

  @Get(':id/photos/:kind')
  @SkipResponseEnvelope()
  @Header('Cache-Control', 'private, no-store')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({ summary: 'Parcel photo (item|pickup|delivery|return); participants only' })
  async photo(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('kind') kind: string,
  ): Promise<StreamableFile> {
    const found = await this.parcels.photo(actor, id, parsePhotoKind(kind));
    return new StreamableFile(found.body, { type: found.contentType, length: found.body.byteLength });
  }
}

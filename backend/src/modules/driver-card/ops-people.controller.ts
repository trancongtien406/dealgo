import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsUUID } from 'class-validator';
import { OpsSessionGuard } from '../identity/access-auth.guard.js';
import { DriverCardService, OPS_PEOPLE_MAX_IDS } from './driver-card.service.js';

export class OpsPeopleQueryDto {
  /** Comma-separated user ids. */
  @Transform(({ value }) =>
    typeof value === 'string'
      ? value
          .split(',')
          .map((part) => part.trim())
          .filter(Boolean)
      : value,
  )
  @ArrayMinSize(1)
  @ArrayMaxSize(OPS_PEOPLE_MAX_IDS)
  @IsUUID('all', { each: true })
  ids!: string[];
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/people')
@UseGuards(OpsSessionGuard)
export class OpsPeopleController {
  constructor(private readonly cards: DriverCardService) {}

  @Get()
  @ApiOperation({
    summary:
      'Ops batch lookup: display name, masked phone and KYC-approved vehicle for user ids (Admin ride/driver rows)',
  })
  list(@Query() query: OpsPeopleQueryDto) {
    return this.cards.opsPeople(query.ids);
  }
}

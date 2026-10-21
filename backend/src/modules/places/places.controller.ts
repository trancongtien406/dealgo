import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import { CustomerSessionGuard } from '../identity/access-auth.guard.js';
import { ReversePlaceQueryDto, SearchPlacesQueryDto } from './places.dto.js';
import { PlacesService } from './places.service.js';

@ApiTags('places')
@ApiBearerAuth()
@Controller('v1/places')
@UseGuards(CustomerSessionGuard, ThrottlerGuard)
export class PlacesController {
  constructor(private readonly places: PlacesService) {}

  @Get('search')
  @ApiOperation({
    summary:
      'Search places by text on the maps provider; { items[{lat,lng,name,address,provider}], available }',
  })
  search(@Query() query: SearchPlacesQueryDto) {
    return this.places.search(query.q, query.limit);
  }

  @Get('reverse')
  @ApiOperation({
    summary:
      'Nearest address for a GPS fix; { place {lat,lng,name,address,provider} | null, available }',
  })
  reverse(@Query() query: ReversePlaceQueryDto) {
    return this.places.reverse(query.lat, query.lng);
  }
}

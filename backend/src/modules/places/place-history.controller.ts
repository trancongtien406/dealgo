import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentActor, CustomerSessionGuard, type RequestActor } from '../identity/access-auth.guard.js';
import { RecordPlaceHistoryDto } from './places.dto.js';
import { PlaceHistoryService } from './place-history.service.js';

@ApiTags('me')
@ApiBearerAuth()
@Controller('v1/me/place-history')
@UseGuards(CustomerSessionGuard)
export class PlaceHistoryController {
  constructor(private readonly history: PlaceHistoryService) {}

  @Get()
  @ApiOperation({ summary: 'Places this user picked from search, newest first (max 20)' })
  list(@CurrentActor() actor: RequestActor) {
    return this.history.list(actor.userId);
  }

  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Record a picked place (same place moves to the top; keeps 20)' })
  record(@CurrentActor() actor: RequestActor, @Body() body: RecordPlaceHistoryDto) {
    return this.history.record(actor.userId, body);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete one history entry' })
  remove(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.history.remove(actor.userId, id);
  }

  @Delete()
  @ApiOperation({ summary: 'Clear the whole place history' })
  clear(@CurrentActor() actor: RequestActor) {
    return this.history.clear(actor.userId);
  }
}

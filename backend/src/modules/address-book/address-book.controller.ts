import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import { CreateSavedAddressDto, UpdateSavedAddressDto } from './address-book.dto.js';
import { AddressBookService } from './address-book.service.js';

@ApiTags('me')
@ApiBearerAuth()
@Controller('v1/me/addresses')
@UseGuards(CustomerSessionGuard)
export class AddressBookController {
  constructor(private readonly addresses: AddressBookService) {}

  @Get()
  @ApiOperation({ summary: 'Saved addresses of the signed-in app user (default first)' })
  list(@CurrentActor() actor: RequestActor) {
    return this.addresses.list(actor.userId);
  }

  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Save an address (max 20; one HOME, one WORK)' })
  create(@CurrentActor() actor: RequestActor, @Body() body: CreateSavedAddressDto) {
    return this.addresses.create(actor.userId, body);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Edit a saved address or make it the default' })
  update(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: UpdateSavedAddressDto,
  ) {
    return this.addresses.update(actor.userId, id, body);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a saved address (the newest remaining becomes default)' })
  remove(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.addresses.remove(actor.userId, id);
  }
}

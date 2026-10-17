import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../../identity/access-auth.guard.js';
import { ChatPageQueryDto, PostChatMessageDto } from './chat.dto.js';
import { ChatService } from './chat.service.js';

@ApiTags('chat')
@ApiBearerAuth()
@Controller('v1/rides')
@UseGuards(CustomerSessionGuard)
export class RideChatController {
  constructor(private readonly chat: ChatService) {}

  @Get(':rideId/messages')
  @ApiOperation({
    summary: 'List transaction chat messages for a ride (participants only; text only)',
  })
  list(
    @CurrentActor() actor: RequestActor,
    @Param('rideId', ParseUUIDPipe) rideId: string,
    @Query() query: ChatPageQueryDto,
  ) {
    return this.chat.listForRide(actor, rideId, query.page, query.limit);
  }

  @Post(':rideId/messages')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Post a text chat message on a ride (participants only)' })
  post(
    @CurrentActor() actor: RequestActor,
    @Param('rideId', ParseUUIDPipe) rideId: string,
    @Body() dto: PostChatMessageDto,
  ) {
    return this.chat.postForRide(actor, rideId, dto.body);
  }
}

@ApiTags('chat')
@ApiBearerAuth()
@Controller('v1/food/orders')
@UseGuards(CustomerSessionGuard)
export class FoodChatController {
  constructor(private readonly chat: ChatService) {}

  @Get(':orderId/messages')
  @ApiOperation({
    summary: 'List transaction chat messages for a food order (participants only; text only)',
  })
  list(
    @CurrentActor() actor: RequestActor,
    @Param('orderId', ParseUUIDPipe) orderId: string,
    @Query() query: ChatPageQueryDto,
  ) {
    return this.chat.listForFood(actor, orderId, query.page, query.limit);
  }

  @Post(':orderId/messages')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Post a text chat message on a food order (participants only)' })
  post(
    @CurrentActor() actor: RequestActor,
    @Param('orderId', ParseUUIDPipe) orderId: string,
    @Body() dto: PostChatMessageDto,
  ) {
    return this.chat.postForFood(actor, orderId, dto.body);
  }
}

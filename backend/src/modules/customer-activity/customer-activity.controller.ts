import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import { CustomerActivityService } from './customer-activity.service.js';

@ApiTags('customer')
@ApiBearerAuth()
@Controller('v1/customer')
@UseGuards(CustomerSessionGuard)
export class CustomerActivityController {
  constructor(private readonly activity: CustomerActivityService) {}

  @Get('active-trip')
  @ApiOperation({
    summary: 'Live ride or open food order to reopen after an app relaunch ({trip:null} when none)',
  })
  activeTrip(@CurrentActor() actor: RequestActor) {
    return this.activity.activeTrip(actor.userId);
  }
}

import { type INestApplication } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule, type OpenAPIObject } from '@nestjs/swagger';

export function buildOpenApiDocument(app: INestApplication): OpenAPIObject {
  const config = new DocumentBuilder()
    .setTitle('DealGo API')
    .setDescription(
      [
        'DealGo REST API for the Ride (inDrive-style bargaining) and Food delivery apps and the ops Admin.',
        '',
        'Success responses are wrapped by the Nest response interceptor as:',
        '`{ success: true, statusCode, message, data, requestId }`.',
        'Errors use:',
        '`{ success: false, statusCode, message, errorCode, timestamp, path, requestId }`.',
        '',
        'Money fields are integer VND. The server is the source of truth for roles, assignment,',
        'status transitions, committed fares, fees and commissions; client-sent role or price is never trusted.',
        '',
        'Business parameters (fare bounds, offer TTL, search radius, commissions, cancellation fees,',
        'contact window, chat retention, ...) are Admin settings: GET/PATCH /v1/ops/platform-settings',
        '(DB value wins; an env value of the same name only seeds a missing key). Secrets stay env-only.',
        '',
        'Realtime runs on Socket.IO: clients `subscribe` to `ride:{id}` / `food:{id}` rooms with a Bearer',
        'handshake and receive `snapshot` hints, then re-read state over REST. The outbox relay also sends',
        'FCM push. See docs/06-data-api/realtime-api-contract.md.',
        '',
        'Ops date buckets (overview, settlements) use the Asia/Ho_Chi_Minh calendar day (UTC+7).',
      ].join('\n'),
    )
    .setVersion('0.1.0')
    .addBearerAuth()
    .addTag('identity', 'Auth, sessions, me, role grants')
    .addTag('rides', 'Ride negotiation and trip lifecycle')
    .addTag('food', 'Food catalog and order lifecycle')
    .addTag('chat', 'Transaction-scoped text chat')
    .addTag('voice', 'In-app audio-only calls between the customer and the assigned driver (LiveKit)')
    .addTag('payments', 'PSP webhook stubs (VNPAY/MoMo)')
    .addTag('ops', 'Operator explorer (ops session)')
    .addTag('health', 'Liveness / readiness')
    .build();

  return SwaggerModule.createDocument(app, config, {
    operationIdFactory: (_controllerKey: string, methodKey: string) => methodKey,
  });
}

export function shouldServeSwagger(nodeEnv: string, swaggerEnabled: boolean | undefined): boolean {
  if (swaggerEnabled === true) {
    return true;
  }
  if (swaggerEnabled === false) {
    return false;
  }
  return nodeEnv !== 'production';
}

import { Body, Controller, ForbiddenException, HttpCode, HttpStatus, Inject, Logger, Post } from '@nestjs/common';
import { ApiExcludeEndpoint } from '@nestjs/swagger';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { DynamicMailSender } from './dynamic-mail-sender.js';
import { EMAIL_SUPPRESSION_REPOSITORY, type EmailSuppressionRepository } from './email-suppression.repository.js';
import { redactEmail } from './mail-templates.js';
import { isSnsUrl, parseSnsMessage, sesSuppressions, SnsSignatureVerifier } from './sns-message.js';


/**
 * SNS subscription endpoint for SES bounce/complaint events. Accepts only signed messages from the
 * topic ARN set in Admin › Email; permanent bounces and complaints go to `email_suppressions`.
 */
@Controller('v1/webhooks/ses')
export class SesWebhookController {
  private readonly logger = new Logger(SesWebhookController.name);

  constructor(
    private readonly mail: DynamicMailSender,
    @Inject(EMAIL_SUPPRESSION_REPOSITORY) private readonly suppressions: EmailSuppressionRepository,
    private readonly verifier: SnsSignatureVerifier,
  ) {}

  @Post()
  @HttpCode(HttpStatus.OK)
  @SkipResponseEnvelope()
  @ApiExcludeEndpoint()
  async receive(@Body() body: unknown): Promise<{ ok: true; suppressed?: number }> {
    const msg = parseSnsMessage(body);
    if (!msg) throw new ForbiddenException('Not an SNS message');
    const topicArn = (await this.mail.effective()).ses.snsTopicArn;
    if (!topicArn || msg.TopicArn !== topicArn) {
      this.logger.warn({ msg: 'email.ses_webhook.unknown_topic', topic: msg.TopicArn });
      throw new ForbiddenException('Unknown topic');
    }
    if (!(await this.verifier.verify(msg).catch(() => false))) {
      throw new ForbiddenException('Invalid SNS signature');
    }
    if (msg.Type === 'SubscriptionConfirmation') {
      if (!isSnsUrl(msg.SubscribeURL)) throw new ForbiddenException('Invalid SubscribeURL');
      const response = await fetch(msg.SubscribeURL!, { signal: AbortSignal.timeout(5_000) });
      this.logger.log({ msg: 'email.ses_webhook.subscribed', status: response.status });
      return { ok: true };
    }
    if (msg.Type !== 'Notification') return { ok: true };
    const rows = sesSuppressions(msg.Message).filter((row) => row.email.includes('@'));
    for (const row of rows) {
      await this.suppressions.suppress(row);
      this.logger.warn({ msg: 'email.suppressed.added', to: redactEmail(row.email), reason: row.reason });
    }
    return { ok: true, suppressed: rows.length };
  }
}

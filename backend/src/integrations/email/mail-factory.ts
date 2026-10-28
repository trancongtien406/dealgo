import { UnavailableMailSender, type MailSender } from './mail-sender.js';

export function isMailSenderAvailable(sender: MailSender): boolean {
  return !(sender instanceof UnavailableMailSender);
}

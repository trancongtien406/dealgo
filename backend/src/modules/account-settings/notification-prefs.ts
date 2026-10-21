/** Inbox / push category → S024 preference key. SYSTEM is always allowed. */
export type PrefKey = 'ride' | 'food' | 'chat' | 'promotion' | 'news';

export type NotificationPrefs = {
  ride: boolean;
  food: boolean;
  chat: boolean;
  promotion: boolean;
  news: boolean;
};

export const DEFAULT_NOTIFICATION_PREFS: NotificationPrefs = {
  ride: true,
  food: true,
  chat: true,
  promotion: false,
  news: false,
};

export function prefKeyForCategory(category: string): PrefKey | 'always' {
  switch (category) {
    case 'RIDE':
      return 'ride';
    case 'FOOD':
      return 'food';
    case 'CHAT':
      return 'chat';
    case 'PROMOTION':
      return 'promotion';
    case 'NEWS':
      return 'news';
    case 'SYSTEM':
      return 'always';
    default:
      return 'always';
  }
}

export function prefsAllow(prefs: NotificationPrefs, category: string): boolean {
  const key = prefKeyForCategory(category);
  return key === 'always' ? true : prefs[key];
}

export const RATING_REPOSITORY = Symbol('RATING_REPOSITORY');

export const RATING_SUBJECT_TYPES = ['RIDE', 'FOOD_ORDER'] as const;
export type RatingSubjectType = (typeof RATING_SUBJECT_TYPES)[number];

/** Quick-pick tags shown in the app; free text goes in `comment`. */
export const RATING_TAGS = [
  'ON_TIME',
  'FRIENDLY',
  'SAFE_DRIVING',
  'CLEAN_VEHICLE',
  'TASTY_FOOD',
  'WELL_PACKED',
  'LATE',
  'RUDE',
  'UNSAFE_DRIVING',
  'WRONG_ITEMS',
  'COLD_FOOD',
] as const;
export type RatingTag = (typeof RATING_TAGS)[number];

import { parseSnapshotRoom, roomForAggregate } from './realtime.constants.js';

describe('realtime.constants', () => {
  it('parses ride and food rooms with UUID ids', () => {
    const rideId = '11111111-1111-4111-8111-111111111111';
    const foodId = '22222222-2222-4222-8222-222222222222';
    expect(parseSnapshotRoom(`ride:${rideId}`)).toEqual({
      kind: 'ride',
      id: rideId,
      room: `ride:${rideId}`,
    });
    expect(parseSnapshotRoom(`food:${foodId}`)).toEqual({
      kind: 'food',
      id: foodId,
      room: `food:${foodId}`,
    });
  });

  it('rejects malformed rooms', () => {
    expect(parseSnapshotRoom('ride:not-a-uuid')).toBeNull();
    expect(parseSnapshotRoom('order:11111111-1111-4111-8111-111111111111')).toBeNull();
    expect(parseSnapshotRoom('')).toBeNull();
  });

  it('maps outbox aggregate types to rooms', () => {
    expect(roomForAggregate('Ride', 'r1')).toBe('ride:r1');
    expect(roomForAggregate('FoodOrder', 'o1')).toBe('food:o1');
    expect(roomForAggregate('Other', 'x')).toBeNull();
  });
});

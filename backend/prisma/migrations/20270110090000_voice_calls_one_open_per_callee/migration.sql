-- One phone shows one call screen: a user who is still being rung (or is already talking)
-- on a ride must not also be rung for a food order. The service checks this before creating
-- the call; the index closes the race between two concurrent starts.
CREATE UNIQUE INDEX "voice_calls_one_open_per_callee" ON "voice_calls"("calleeUserId") WHERE "status" IN ('RINGING', 'ACCEPTED');

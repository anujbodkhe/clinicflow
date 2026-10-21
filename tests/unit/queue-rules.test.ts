import assert from 'node:assert/strict'
import test from 'node:test'
import {
  calculateEstimatedWaitMinutes,
  getMissedTurnTransition,
  getQueuePosition,
  orderQueueEntries,
  type QueueEntryForRules,
} from '../../lib/queue-rules.ts'

const entries: QueueEntryForRules[] = [
  { id: 'regular', token: 3, status: 'waiting', urgency: 'standard', queueOrder: 30 },
  { id: 'active', token: 1, status: 'in_progress', urgency: 'standard', startedAt: '2026-10-20T10:00:00.000Z' },
  { id: 'approved', token: 4, status: 'waiting', urgency: 'standard', sosApprovedAt: '2026-10-20T10:02:00.000Z', queueOrder: 40 },
  { id: 'urgent', token: 2, status: 'waiting', urgency: 'urgent', queueOrder: 50 },
]

test('orders the active consultation first, approved SOS next, and otherwise preserves queue order', () => {
  assert.deepEqual(orderQueueEntries(entries).map(({ id }) => id), ['active', 'approved', 'regular', 'urgent'])
})

test('does not restore approved SOS priority after the first missed call pushes the entry back', () => {
  const missedSosEntry: QueueEntryForRules = {
    id: 'missed-sos',
    token: 5,
    status: 'waiting',
    urgency: 'standard',
    sosApprovedAt: '2026-10-20T10:02:00.000Z',
    sosPriorityActive: false,
    queueOrder: 35,
  }
  assert.deepEqual(orderQueueEntries([...entries, missedSosEntry]).map(({ id }) => id), [
    'active', 'approved', 'regular', 'missed-sos', 'urgent',
  ])
})

test('returns the one-based position in the effective queue order', () => {
  assert.equal(getQueuePosition(entries, 'urgent'), 4)
  assert.equal(getQueuePosition(entries, 'missing'), null)
})

test('estimates remaining active consultation time and preceding standard/urgent entries', () => {
  const now = new Date('2026-10-20T10:06:00.000Z')
  assert.equal(calculateEstimatedWaitMinutes(entries, 'regular', now), 14)
  assert.equal(calculateEstimatedWaitMinutes(entries, 'active', now), 0)
})

test('pushes the first missed call back two positions and moves the second miss to standby', () => {
  assert.deepEqual(getMissedTurnTransition(0), { status: 'waiting', missedTurnCount: 1, pushBackPositions: 2 })
  assert.deepEqual(getMissedTurnTransition(1), { status: 'standby', missedTurnCount: 2, pushBackPositions: 0 })
})

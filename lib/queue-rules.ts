export type QueueEntryForRules = {
  id: string
  token: number
  status: 'waiting' | 'called' | 'in_progress' | 'completed' | 'cancelled' | 'no_show' | 'standby'
  urgency: 'standard' | 'urgent'
  sosApprovedAt?: string | null
  sosPriorityActive?: boolean
  sosRequestedAt?: string | null
  queueOrder?: number | null
  createdAt?: string | null
  startedAt?: string | null
  estimatedMinutes?: number | null
}

const activeStatuses = new Set(['called', 'in_progress'])
const queueableStatuses = new Set(['waiting', 'called', 'in_progress'])

export function orderQueueEntries<T extends QueueEntryForRules>(entries: readonly T[]): T[] {
  return [...entries].sort((left, right) => {
    const activeDifference = Number(activeStatuses.has(right.status)) - Number(activeStatuses.has(left.status))
    if (activeDifference) return activeDifference

    const leftApproved = left.sosPriorityActive ?? Boolean(left.sosApprovedAt)
    const rightApproved = right.sosPriorityActive ?? Boolean(right.sosApprovedAt)
    const approvedDifference = Number(rightApproved) - Number(leftApproved)
    if (approvedDifference) return approvedDifference

    if (leftApproved && rightApproved) {
      const approvedAtDifference = (left.sosApprovedAt ?? '').localeCompare(right.sosApprovedAt ?? '')
      if (approvedAtDifference) return approvedAtDifference
    }

    const orderDifference = (left.queueOrder ?? left.token) - (right.queueOrder ?? right.token)
    return orderDifference || left.token - right.token || left.id.localeCompare(right.id)
  })
}

export function getQueuePosition(entries: readonly QueueEntryForRules[], entryId: string): number | null {
  const ordered = orderQueueEntries(entries.filter((entry) => queueableStatuses.has(entry.status)))
  const index = ordered.findIndex((entry) => entry.id === entryId)
  return index < 0 ? null : index + 1
}

export function calculateEstimatedWaitMinutes(
  entries: readonly QueueEntryForRules[],
  entryId: string,
  now = new Date(),
  standardMinutes = 10,
  urgentMinutes = 15,
): number | null {
  const ordered = orderQueueEntries(entries.filter((entry) => queueableStatuses.has(entry.status)))
  const targetIndex = ordered.findIndex((entry) => entry.id === entryId)
  if (targetIndex < 0) return null

  return ordered.slice(0, targetIndex).reduce((total, entry) => {
    const duration = entry.urgency === 'urgent' ? urgentMinutes : standardMinutes
    if (entry.status !== 'in_progress' || !entry.startedAt) return total + duration
    const elapsed = Math.max(0, Math.floor((now.getTime() - new Date(entry.startedAt).getTime()) / 60_000))
    return total + Math.max(0, duration - elapsed)
  }, 0)
}

export function getMissedTurnTransition(missedTurnCount: number) {
  if (missedTurnCount < 1) {
    return { status: 'waiting' as const, missedTurnCount: 1, pushBackPositions: 2 }
  }
  return { status: 'standby' as const, missedTurnCount: missedTurnCount + 1, pushBackPositions: 0 }
}

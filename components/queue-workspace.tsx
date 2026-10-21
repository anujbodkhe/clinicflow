'use client'

import { useEffect, useMemo, useState } from 'react'
import { Activity, CalendarClock, CheckCircle2, Clock3, LoaderCircle, Plus, RefreshCw, Siren, UserPlus, Users } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { orderQueueEntries } from '@/lib/queue-rules'

type Role = 'super_admin' | 'clinic_admin' | 'doctor' | 'receptionist' | 'patient'
type QueueStatus = 'waiting' | 'called' | 'in_progress' | 'completed' | 'cancelled' | 'no_show' | 'standby'
type Clinic = { id: string; name: string; address: string | null; membershipRole: Role }
type Availability = { session_id: string; clinic_id: string; clinic_name: string; doctor_id: string; doctor_name: string; session_date: string; starts_at: string; ends_at: string; online_capacity: number; walk_in_reserve: number; total_capacity: number; registered_count: number }
type Entry = { id: string; session_id: string; token: number; status: QueueStatus; source: 'online' | 'walk_in'; urgency: 'standard' | 'urgent'; estimated_minutes: number; sos_requested_at: string | null; sos_approved_at: string | null; sos_decision?: 'pending' | 'approved' | 'rejected' | null; sos_priority_active?: boolean; queue_order?: number; missed_turn_count?: number; call_grace_expires_at?: string | null; queue_position?: number | null; estimated_wait_minutes?: number | null }
type StaffSession = Availability & { status: string }
type StaffEntry = Entry & { patient_id: string | null; walk_in_patient_id: string | null; walk_in_patients?: { full_name: string; phone?: string | null; symptoms?: string } | null }
type Doctor = { id: string; full_name: string }
type Schedule = { id: string; clinic_id: string; doctor_id: string; weekday: number; starts_at: string; ends_at: string; consultation_minutes: number; online_capacity: number; walk_in_reserve: number; active: boolean }

const statusLabels: Record<QueueStatus, string> = { waiting: 'Waiting', called: 'Called', in_progress: 'In progress', completed: 'Completed', cancelled: 'Cancelled', no_show: 'No-show', standby: 'Standby' }
const activeStatuses = ['waiting', 'called', 'in_progress']

function orderStaffEntries(entries: readonly StaffEntry[]) {
  return orderQueueEntries(entries.map((entry) => ({
    ...entry,
    sosApprovedAt: entry.sos_approved_at,
    sosPriorityActive: entry.sos_priority_active,
    sosRequestedAt: entry.sos_requested_at,
    queueOrder: entry.queue_order,
    createdAt: null,
  })))
}

export function QueueWorkspace({ role, userId, clinics, availability, entries, staffSessions, staffEntries }: { role: Role; userId: string; clinics: Clinic[]; availability: Availability[]; entries: Entry[]; staffSessions: StaffSession[]; staffEntries: StaffEntry[] }) {
  const supabase = useMemo(() => createClient(), [])
  const [sessions, setSessions] = useState(availability)
  const [myEntries, setMyEntries] = useState(entries)
  const [staffRows, setStaffRows] = useState(staffSessions)
  const [staffQueue, setStaffQueue] = useState(staffEntries)
  const [doctors, setDoctors] = useState<Doctor[]>([])
  const [schedules, setSchedules] = useState<Schedule[]>([])
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState(false)
  const [loading, setLoading] = useState(true)
  const [selectedClinic, setSelectedClinic] = useState(clinics[0]?.id ?? '')
  const [symptomsDrafts, setSymptomsDrafts] = useState<Record<string, string>>({})
  const [clockNow, setClockNow] = useState(Date.now())
  const canManage = role === 'clinic_admin' || role === 'super_admin'

  async function refreshPatient() {
    setLoading(true)
    const [{ data: nextSessions, error: sessionsError }, { data: nextEntries, error: entriesError }] = await Promise.all([
      supabase.rpc('patient_queue_availability', { p_clinic_id: selectedClinic || null }),
      supabase.from('queue_entries').select('id, session_id, token, status, source, urgency, estimated_minutes, sos_requested_at, sos_approved_at, sos_decision, sos_priority_active, queue_order, missed_turn_count, call_grace_expires_at').eq('patient_id', userId).order('created_at', { ascending: false }).limit(10),
    ])
    if (sessionsError || entriesError) setMessage(sessionsError?.message ?? entriesError?.message ?? 'Queue data could not be loaded.')
    else {
      setSessions((nextSessions ?? []) as Availability[])
      const rows = (nextEntries ?? []) as Entry[]
      const positions = await Promise.all(rows.map(async (entry) => {
        if (!['waiting', 'called', 'in_progress'].includes(entry.status)) return [entry.id, null] as const
        const { data, error } = await supabase.rpc('patient_queue_position', { p_entry_id: entry.id })
        if (error) {
          setMessage('Queue position and estimated wait could not be refreshed.')
          return [entry.id, null] as const
        }
        const result = Array.isArray(data) ? data[0] : data
        return [entry.id, result as { queue_position: number; estimated_wait_minutes: number } | null] as const
      }))
      const positionMap = new Map(positions)
      setMyEntries(rows.map((entry) => ({
        ...entry,
        queue_position: positionMap.get(entry.id)?.queue_position ?? null,
        estimated_wait_minutes: positionMap.get(entry.id)?.estimated_wait_minutes ?? null,
      })))
    }
    setLoading(false)
  }

  async function refreshStaff() {
    const clinicIds = clinics.map((clinic) => clinic.id)
    if (!clinicIds.length) { setLoading(false); return }
    setLoading(true)
    const { data: nextSessions, error: sessionsError } = await supabase.from('queue_sessions').select('id, clinic_id, doctor_id, session_date, starts_at, ends_at, online_capacity, walk_in_reserve, total_capacity, status, clinics(name), profiles!queue_sessions_doctor_id_fkey(full_name)').in('clinic_id', clinicIds).order('session_date')
    if (sessionsError) {
      setMessage(sessionsError.message)
      setLoading(false)
      return
    }

    const sessionIds = (nextSessions ?? []).map((session: any) => session.id)
    const walkInResults = await Promise.all(clinicIds.map((clinicId) => supabase.rpc('list_clinic_walk_ins', { p_clinic_id: clinicId })))
    const walkInError = walkInResults.find((result: any) => result.error)?.error
    if (walkInError) {
      setMessage(walkInError.message ?? 'Clinic queue data could not be loaded.')
      setLoading(false)
      return
    }

    const onlineResult = sessionIds.length
      ? await supabase.from('queue_entries').select('id, session_id, patient_id, walk_in_patient_id, token, status, source, urgency, estimated_minutes, sos_requested_at, sos_approved_at, sos_decision, sos_priority_active, queue_order, missed_turn_count, call_grace_expires_at').in('session_id', sessionIds).not('patient_id', 'is', null)
      : { data: [] as Array<any>, error: null }

    if (onlineResult.error) {
      setMessage(onlineResult.error.message ?? 'Clinic queue data could not be loaded.')
      setLoading(false)
      return
    }

    const patientIds = [...new Set((onlineResult.data ?? []).map((entry: any) => entry.patient_id).filter(Boolean))]
    const { data: profiles } = patientIds.length ? await supabase.from('profiles').select('id, full_name').in('id', patientIds) : { data: [] as Array<{ id: string; full_name: string }> }
    const patientMap = new Map((profiles ?? []).map((profile) => [profile.id, profile.full_name]))

    const walkIns = (walkInResults ?? []).flatMap((result: any) => (result.data ?? []).map((entry: any) => ({ ...entry, walk_in_patients: { full_name: entry.full_name, phone: entry.phone, symptoms: entry.symptoms } })))
    const onlineEntries = (onlineResult.data ?? []).map((entry: any) => ({
      ...entry,
      patient_id: entry.patient_id,
      walk_in_patient_id: null,
      walk_in_patients: null,
      patient_name: patientMap.get(entry.patient_id) ?? 'Patient',
    })) as StaffEntry[]

    setStaffRows((nextSessions ?? []).map((session: any) => ({
      session_id: session.id,
      clinic_id: session.clinic_id,
      clinic_name: Array.isArray(session.clinics) ? session.clinics[0]?.name ?? 'Clinic' : session.clinics?.name ?? 'Clinic',
      doctor_id: session.doctor_id,
      doctor_name: Array.isArray(session.profiles) ? session.profiles[0]?.full_name ?? 'Doctor' : session.profiles?.full_name ?? 'Doctor',
      session_date: session.session_date,
      starts_at: session.starts_at,
      ends_at: session.ends_at,
      online_capacity: session.online_capacity,
      walk_in_reserve: session.walk_in_reserve,
      total_capacity: session.total_capacity,
      registered_count: 0,
      status: session.status,
    })))

    const combinedQueue = [...onlineEntries, ...(walkIns as StaffEntry[])]
    combinedQueue.sort((left, right) => {
      const sessionOrder = left.session_id.localeCompare(right.session_id)
      if (sessionOrder) return sessionOrder
      return orderStaffEntries([left, right])[0]?.id === left.id ? -1 : 1
    })
    setStaffQueue(combinedQueue)
    setLoading(false)
  }

  useEffect(() => {
    const channel = supabase.channel(`clinicflow-queue-${userId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'queue_entries' }, () => { void (role === 'patient' ? refreshPatient() : refreshStaff()) })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'queue_sessions' }, () => { void (role === 'patient' ? refreshPatient() : refreshStaff()) })
      .subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [role, selectedClinic, userId])

  useEffect(() => { void (role === 'patient' ? refreshPatient() : refreshStaff()) }, [role, selectedClinic, userId])

  useEffect(() => { if (!canManage) return; let cancelled = false; void Promise.all(clinics.map(async (clinic) => { const [{ data: doctorRows, error: doctorError }, { data: rows, error: scheduleError }] = await Promise.all([supabase.rpc('list_manageable_doctors', { p_clinic_id: clinic.id }), supabase.from('doctor_schedules').select('id, clinic_id, doctor_id, weekday, starts_at, ends_at, consultation_minutes, online_capacity, walk_in_reserve, active').eq('clinic_id', clinic.id)]); if (doctorError || scheduleError) setMessage(doctorError?.message ?? scheduleError?.message ?? 'Schedule data could not be loaded.'); return { doctors: (doctorRows ?? []) as Doctor[], schedules: (rows ?? []) as Schedule[] } })).then((results) => { if (cancelled) return; const nextDoctors = new Map<string, Doctor>(); const nextSchedules: Schedule[] = []; for (const result of results) { for (const doctor of result.doctors) nextDoctors.set(doctor.id, doctor); nextSchedules.push(...result.schedules) } setDoctors([...nextDoctors.values()]); setSchedules(nextSchedules) }); return () => { cancelled = true } }, [canManage, clinics, supabase])

  useEffect(() => {
    if (!staffQueue.some((entry) => entry.status === 'called')) return
    const timer = window.setInterval(() => setClockNow(Date.now()), 5000)
    return () => window.clearInterval(timer)
  }, [staffQueue])

  async function run(action: () => Promise<void>) { setBusy(true); setMessage(''); try { await action() } finally { setBusy(false) } }
  async function register(sessionId: string, urgency: 'standard' | 'urgent' = 'standard', symptoms = '') { const existing = myEntries.find((entry) => entry.session_id === sessionId); if (existing) { setMessage(`You already have Token #${existing.token} for this session (${statusLabels[existing.status].toLowerCase()}).`); return } const trimmedSymptoms = symptoms.trim(); if (!trimmedSymptoms) { setMessage('Please add a short symptom description before joining the queue.'); return } await run(async () => { const { data, error } = await supabase.rpc('register_for_queue_with_symptoms', { p_session_id: sessionId, p_urgency: urgency, p_symptoms: trimmedSymptoms }); if (error) { setMessage(error.code === '23505' || error.message.includes('queue_entries_session_id_patient_id_key') ? 'You already have a registration for this queue session.' : 'Queue registration could not be completed. Please try again.') } else if (data) { setMyEntries((current) => [data as Entry, ...current.filter((entry) => entry.session_id !== sessionId)]); await refreshPatient() } }) }
  async function requestSos(entryId: string) { await run(async () => { const { error } = await supabase.rpc('request_queue_sos', { p_entry_id: entryId }); if (error) setMessage(error.message); else { setMessage('SOS request sent for authorized staff review. If this is an emergency, contact local emergency services; this request does not contact them.'); await refreshPatient() } }) }
  async function reviewSos(entryId: string, decision: 'approve' | 'reject') { await run(async () => { const { error } = await supabase.rpc(`${decision}_queue_sos`, { p_entry_id: entryId }); if (error) setMessage(error.message); else { setMessage(`SOS request ${decision === 'approve' ? 'approved' : 'rejected'}.`); await refreshStaff() } }) }
  async function processMissedTurn(entryId: string) { await run(async () => { const { error } = await supabase.rpc('process_missed_turn', { p_entry_id: entryId }); if (error) setMessage(error.message); else { setMessage('Missed turn recorded.'); await refreshStaff() } }) }
  async function reactivateStandby(entryId: string) { await run(async () => { const { error } = await supabase.rpc('reactivate_standby_queue_entry', { p_entry_id: entryId }); if (error) setMessage(error.message); else { setMessage('Patient returned to the end of the queue.'); await refreshStaff() } }) }
  async function updateStatus(entryId: string, status: QueueStatus) { await run(async () => { const { error } = await supabase.rpc('update_queue_status', { p_entry_id: entryId, p_status: status }); if (error) setMessage(error.message); else { await refreshStaff() } }) }
  async function callNext(sessionId: string) { await run(async () => { const { error } = await supabase.rpc('call_next_queue_entry', { p_session_id: sessionId }); if (error) setMessage(error.message); else { setMessage('Next queue entry called.'); await refreshStaff() } }) }
  async function createWalkIn(form: HTMLFormElement) { const data = new FormData(form); await run(async () => { const { data: result, error } = await supabase.rpc('create_walk_in', { p_session_id: String(data.get('session_id')), p_full_name: String(data.get('full_name')), p_phone: String(data.get('phone')), p_symptoms: String(data.get('symptoms') || '') }); if (error) setMessage(error.message); else if (result) { setMessage(`Walk-in token #${(result as Entry).token} created.`); await refreshStaff() } }) }
  async function createSchedule(form: HTMLFormElement) { const data = new FormData(form); await run(async () => { const payload = { p_clinic_id: String(data.get('clinic_id')), p_doctor_id: String(data.get('doctor_id')), p_weekday: Number(data.get('weekday')), p_starts_at: String(data.get('starts_at')), p_ends_at: String(data.get('ends_at')), p_consultation_minutes: Number(data.get('consultation_minutes')), p_online_capacity: Number(data.get('online_capacity')), p_walk_in_reserve: Number(data.get('walk_in_reserve')) }; const { data: result, error } = await supabase.rpc('create_doctor_schedule', payload); if (error) setMessage(error.message); else { setMessage('Doctor schedule created.'); if (result) setSchedules((current) => [...current, result as Schedule]) } }) }
  async function createSession(form: HTMLFormElement) { const data = new FormData(form); const clinicId = String(data.get('clinic_id') || ''); const doctorId = String(data.get('doctor_id') || ''); const sessionDate = String(data.get('session_date') || ''); const scheduleId = data.get('schedule_id'); const start = String(data.get('starts_at')); const end = String(data.get('ends_at')); const startDate = new Date(`${sessionDate}T${start}`); const endDate = new Date(`${sessionDate}T${end}`); if (!clinicId || !doctorId || !sessionDate) { setMessage('Choose a clinic, doctor, and session date.'); return } if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime()) || endDate <= startDate) { setMessage('Session end must be after its start.'); return } await run(async () => { const { error } = await supabase.rpc('create_queue_session', { p_clinic_id: clinicId, p_doctor_id: doctorId, p_schedule_id: scheduleId ? String(scheduleId) : null, p_session_date: sessionDate, p_starts_at: startDate.toISOString(), p_ends_at: endDate.toISOString(), p_online_capacity: Number(data.get('online_capacity')), p_walk_in_reserve: Number(data.get('walk_in_reserve')) }); if (error) setMessage(error.message); else { setMessage('Queue session created.'); await refreshStaff() } }) }
  async function manageSession(form: HTMLFormElement) { const data = new FormData(form); await run(async () => { const { error } = await supabase.rpc('manage_queue_session', { p_session_id: String(data.get('session_id')), p_status: String(data.get('status')), p_online_capacity: Number(data.get('online_capacity')), p_walk_in_reserve: Number(data.get('walk_in_reserve')), p_starts_at: new Date(String(data.get('starts_at'))).toISOString(), p_ends_at: new Date(String(data.get('ends_at'))).toISOString() }); if (error) setMessage(error.message); else { setMessage('Queue session updated.'); await refreshStaff() } }) }

  const latestEntry = myEntries.find((entry) => activeStatuses.includes(entry.status)) ?? myEntries[0]
  const sessionEntryCount = (sessionId: string) => staffQueue.filter((entry) => entry.session_id === sessionId && !['cancelled', 'no_show'].includes(entry.status)).length
  const activeStaffCount = staffQueue.filter((entry) => activeStatuses.includes(entry.status)).length
  const capacityTotal = staffRows.reduce((total, row) => total + row.total_capacity, 0)
  const capacityUsed = staffQueue.filter((entry) => !['cancelled', 'no_show'].includes(entry.status)).length
  const capacityRate = capacityTotal ? `${Math.round((capacityUsed / capacityTotal) * 100)}%` : '—'
  const currentPositionText = latestEntry?.status === 'standby'
    ? 'Standby · contact reception to request reactivation'
    : latestEntry && !['waiting', 'called', 'in_progress'].includes(latestEntry.status)
      ? 'No active queue position'
    : latestEntry?.queue_position
      ? `Position ${latestEntry.queue_position} · ${latestEntry.queue_position - 1} ahead · EWT approximately ${latestEntry.estimated_wait_minutes ?? 0} min`
      : 'Queue position and EWT are refreshing'
  return <div className="mt-10 space-y-8">
    {message && <div role="status" className="rounded-xl border border-[#f0c9bd] bg-[#fff7f4] px-4 py-3 text-sm text-[#9a4d3b]">{message}</div>}
    {loading && <div role="status" className="flex items-center gap-2 rounded-xl border border-[#dceae6] bg-white px-4 py-3 text-sm text-[#58706b]"><LoaderCircle className="size-4 animate-spin" />Refreshing live queue data…</div>}
    {role === 'patient' ? <>
      {latestEntry && <section className="rounded-2xl bg-[#116b5b] p-6 text-white"><div className="flex items-start justify-between"><div><p className="text-sm text-[#c7e5dd]">Your current queue</p><p className="mt-2 text-4xl font-semibold">Token #{latestEntry.token}</p><p className="mt-2 text-[#c7e5dd]">{statusLabels[latestEntry.status]} · {latestEntry.sos_decision === 'approved' ? latestEntry.sos_priority_active === false && (latestEntry.missed_turn_count ?? 0) > 0 ? 'SOS approved · priority paused after missed call' : 'SOS approved · Urgent priority' : latestEntry.sos_decision === 'rejected' ? 'SOS reviewed · Standard priority' : latestEntry.sos_decision === 'pending' ? 'SOS requested · Pending staff review' : 'Standard priority'} · {currentPositionText}</p></div><Activity /></div><div className="mt-3 text-sm text-[#c7e5dd]">SOS requests are reviewed by clinic staff and do not contact emergency services.</div><div className="mt-6 flex flex-wrap gap-3"><button disabled={busy || Boolean(latestEntry.sos_requested_at) || latestEntry.status !== 'waiting'} onClick={() => void requestSos(latestEntry.id)} className="rounded-xl bg-[#ef896f] px-4 py-2 text-sm font-semibold text-[#18322f] disabled:opacity-50"><Siren className="mr-2 inline size-4" />{latestEntry.sos_requested_at ? 'SOS requested' : 'Request SOS review'}</button><button onClick={() => void refreshPatient()} className="rounded-xl border border-white/30 px-4 py-2 text-sm"><RefreshCw className="mr-2 inline size-4" />Refresh queue</button></div></section>}
      <section><div className="flex flex-wrap items-end justify-between gap-4"><div><h2 className="text-2xl font-semibold">Open queue sessions</h2><p className="mt-1 text-sm text-[#58706b]">Choose a clinic and join online without seeing other patients&apos; private entries.</p></div><select value={selectedClinic} onChange={(event) => setSelectedClinic(event.target.value)} className="rounded-xl border border-[#cfe5df] bg-white px-3 py-2 text-sm"><option value="">All clinics</option>{clinics.map((clinic) => <option key={clinic.id} value={clinic.id}>{clinic.name}</option>)}</select></div><div className="mt-4 grid gap-4 lg:grid-cols-2">{sessions.map((session) => <div key={session.session_id} className="rounded-2xl border border-[#dceae6] bg-white p-5"><div className="flex items-start justify-between"><div><p className="font-semibold">{session.clinic_name}</p><p className="mt-1 text-sm text-[#58706b]">Dr. {session.doctor_name}</p></div><span className="rounded-full bg-[#e9f6f2] px-3 py-1 text-xs font-medium text-[#116b5b]">{session.registered_count}/{session.total_capacity}</span></div><p className="mt-5 text-sm"><CalendarClock className="mr-2 inline size-4 text-[#116b5b]" />{session.session_date} · {new Date(session.starts_at).toLocaleTimeString('en-IN', { timeZone: 'Asia/Kolkata', hour: '2-digit', minute: '2-digit' })}</p><textarea value={symptomsDrafts[session.session_id] ?? ''} onChange={(event) => setSymptomsDrafts((current) => ({ ...current, [session.session_id]: event.target.value }))} placeholder="Briefly describe the symptoms for this visit" className="mt-4 min-h-20 w-full rounded-xl border border-[#cfe5df] px-3 py-2 text-sm" /><div>{(() => { const existingEntry = myEntries.find((entry) => entry.session_id === session.session_id); return <button disabled={busy || Boolean(existingEntry)} onClick={() => void register(session.session_id, 'standard', symptomsDrafts[session.session_id] ?? '')} className="mt-5 w-full rounded-xl bg-[#116b5b] px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-50">{existingEntry ? `Registered · ${statusLabels[existingEntry.status]}` : 'Join queue'}</button> })()}</div></div>)}{sessions.length === 0 && <p className="text-sm text-[#58706b]">No open sessions are available. A clinic administrator must create a dated session first.</p>}</div></section>
    </> : <>
      <section className="grid gap-4 sm:grid-cols-3"><Metric icon={Users} label="Active queue entries" value={String(activeStaffCount)} /><Metric icon={Clock3} label="Open sessions" value={String(staffRows.filter((row) => row.status === 'open').length)} /><Metric icon={CheckCircle2} label="Capacity used" value={capacityRate} /></section>
      <section className="rounded-2xl border border-[#dceae6] bg-white p-6"><h2 className="text-xl font-semibold">Queue operations</h2><p className="mt-1 text-sm text-[#58706b]">Queue calls, transitions, SOS review, missed turns, and reactivation are enforced by Supabase RPCs.</p><div className="mt-5 grid gap-3">{staffRows.map((row) => <div key={row.session_id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-[#e7efec] p-4"><div><p className="font-medium">{row.clinic_name} · Dr. {row.doctor_name}</p><p className="text-sm text-[#58706b]">{row.session_date} · {row.status} · {sessionEntryCount(row.session_id)} registered</p></div><div className="flex flex-wrap gap-2">{staffQueue.filter((entry) => entry.session_id === row.session_id).map((entry) => <div key={entry.id} className="flex items-center gap-2 rounded-lg bg-[#f7faf9] px-3 py-2 text-sm"><span className="font-semibold">#{entry.token}</span><span>{entry.walk_in_patients?.full_name ?? 'Registered patient'}{entry.walk_in_patients?.phone ? ` · ${entry.walk_in_patients.phone}` : ''}</span><span>{statusLabels[entry.status]}</span>{entry.sos_decision === 'approved' ? <span className="rounded-full bg-[#ffe5dc] px-2 py-0.5 text-xs font-semibold text-[#9a4d3b]">{entry.sos_priority_active ? 'SOS Approved · Urgent' : 'SOS Approved · Priority paused after missed call'}</span> : entry.sos_decision === 'pending' ? <span className="rounded-full bg-[#fff4d6] px-2 py-0.5 text-xs font-semibold text-[#8a6414]">SOS Pending</span> : entry.sos_decision === 'rejected' ? <span className="rounded-full bg-[#e9f6f2] px-2 py-0.5 text-xs font-semibold text-[#58706b]">SOS Rejected</span> : null}{role === 'doctor' && activeStatuses.includes(entry.status) && <button type="button" onClick={() => window.dispatchEvent(new CustomEvent('clinicflow:start-consultation', { detail: { patientId: entry.patient_id, queueEntryId: entry.id, clinicId: row.clinic_id } }))} className="font-medium text-[#116b5b]">Start consultation</button>}{(role === 'receptionist' || canManage) && entry.sos_decision === 'pending' && <><button disabled={busy} onClick={() => void reviewSos(entry.id, 'approve')} className="text-[#9a4d3b]">Approve SOS</button><button disabled={busy} onClick={() => void reviewSos(entry.id, 'reject')} className="text-[#58706b]">Reject SOS</button></>}{entry.status === 'waiting' && !staffQueue.some((candidate) => candidate.session_id === row.session_id && ['called', 'in_progress'].includes(candidate.status)) && orderStaffEntries(staffQueue.filter((candidate) => candidate.session_id === row.session_id && candidate.status === 'waiting'))[0]?.id === entry.id && <button disabled={busy} onClick={() => void callNext(row.session_id)} className="text-[#116b5b]">Call next</button>}{entry.status === 'called' && <button disabled={busy} onClick={() => void updateStatus(entry.id, 'in_progress')} className="text-[#116b5b]">Start</button>}{entry.status === 'in_progress' && <button disabled={busy} onClick={() => void updateStatus(entry.id, 'completed')} className="text-[#116b5b]">Complete</button>}{(role === 'receptionist' || canManage) && entry.status === 'called' && entry.call_grace_expires_at && new Date(entry.call_grace_expires_at).getTime() <= clockNow && <button disabled={busy} onClick={() => void processMissedTurn(entry.id)} className="text-[#9a4d3b]">Record missed call</button>}{(role === 'receptionist' || canManage) && entry.status === 'standby' && <button disabled={busy} onClick={() => void reactivateStandby(entry.id)} className="text-[#116b5b]">Reactivate</button>}</div>)}</div></div>)}{staffRows.length === 0 && <p className="text-sm text-[#58706b]">No clinic sessions are visible. Add a clinic membership and dated session first.</p>}</div></section>
      {(role === 'receptionist' || canManage) && <section className="grid gap-5 lg:grid-cols-2"><form onSubmit={(event) => { event.preventDefault(); void createWalkIn(event.currentTarget) }} className="rounded-2xl border border-[#dceae6] bg-white p-6"><h2 className="text-xl font-semibold"><UserPlus className="mr-2 inline size-5 text-[#116b5b]" />Register walk-in</h2><div className="mt-4 grid gap-3"><select required name="session_id" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm"><option value="">Choose session</option>{staffRows.filter((row) => row.status === 'open').map((row) => <option key={row.session_id} value={row.session_id}>{row.clinic_name} · {row.session_date}</option>)}</select><input required name="full_name" placeholder="Patient full name" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm" /><input required name="phone" placeholder="Phone number" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm" /><textarea name="symptoms" placeholder="Symptoms (optional)" className="min-h-20 rounded-xl border border-[#cfe5df] px-3 py-2 text-sm" /><select name="urgency" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm"><option value="standard">Standard · 10 min estimate</option><option value="urgent">Urgent · 15 min estimate</option></select><button disabled={busy} className="rounded-xl bg-[#116b5b] px-4 py-2.5 text-sm font-semibold text-white">Create walk-in</button></div></form>{canManage && <><form onSubmit={(event) => { event.preventDefault(); void createSchedule(event.currentTarget) }} className="rounded-2xl border border-[#dceae6] bg-white p-6"><h2 className="text-xl font-semibold"><Plus className="mr-2 inline size-5 text-[#116b5b]" />Create doctor schedule</h2><div className="mt-4 grid gap-3"><select required name="clinic_id" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm"><option value="">Choose clinic</option>{clinics.map((clinic) => <option key={clinic.id} value={clinic.id}>{clinic.name}</option>)}</select><select required name="doctor_id" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm"><option value="">Choose doctor</option>{doctors.map((doctor) => <option key={doctor.id} value={doctor.id}>{doctor.full_name}</option>)}</select><div className="grid grid-cols-2 gap-3"><input required type="number" min="0" max="6" name="weekday" placeholder="Weekday 0-6" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm" /><input required type="number" min="5" max="120" name="consultation_minutes" defaultValue="10" placeholder="Minutes" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm" /></div><div className="grid grid-cols-2 gap-3"><input required type="time" name="starts_at" /><input required type="time" name="ends_at" /></div><div className="grid grid-cols-2 gap-3"><input required type="number" min="0" name="online_capacity" defaultValue="20" placeholder="Online capacity" /><input required type="number" min="0" name="walk_in_reserve" defaultValue="5" placeholder="Walk-in reserve" /></div><button disabled={busy} className="rounded-xl bg-[#116b5b] px-4 py-2.5 text-sm font-semibold text-white">Save schedule</button></div></form><form onSubmit={(event) => { event.preventDefault(); void createSession(event.currentTarget) }} className="rounded-2xl border border-[#dceae6] bg-white p-6"><h2 className="text-xl font-semibold"><CalendarClock className="mr-2 inline size-5 text-[#116b5b]" />Create dated queue session</h2><div className="mt-4 grid gap-3"><select required name="clinic_id" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm"><option value="">Choose clinic</option>{clinics.map((clinic) => <option key={clinic.id} value={clinic.id}>{clinic.name}</option>)}</select><select required name="doctor_id" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm"><option value="">Choose doctor</option>{doctors.map((doctor) => <option key={doctor.id} value={doctor.id}>{doctor.full_name}</option>)}</select><select name="schedule_id" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm"><option value="">Optional schedule</option>{schedules.map((schedule) => <option key={schedule.id} value={schedule.id}>{schedule.starts_at}–{schedule.ends_at}</option>)}</select><input required type="date" name="session_date" /><div className="grid grid-cols-2 gap-3"><input required type="time" name="starts_at" /><input required type="time" name="ends_at" /></div><div className="grid grid-cols-2 gap-3"><input required type="number" min="0" name="online_capacity" defaultValue="20" placeholder="Online capacity" /><input required type="number" min="0" name="walk_in_reserve" defaultValue="5" placeholder="Walk-in reserve" /></div><button disabled={busy} className="rounded-xl bg-[#116b5b] px-4 py-2.5 text-sm font-semibold text-white">Create session</button></div></form><form onSubmit={(event) => { event.preventDefault(); void manageSession(event.currentTarget) }} className="rounded-2xl border border-[#dceae6] bg-white p-6"><h2 className="text-xl font-semibold">Manage dated session</h2><div className="mt-4 grid gap-3"><select required name="session_id" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm"><option value="">Choose session</option>{staffRows.map((row) => <option key={row.session_id} value={row.session_id}>{row.clinic_name} · {row.session_date}</option>)}</select><select name="status" className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm"><option value="open">Open</option><option value="closed">Closed</option><option value="completed">Completed</option></select><input required type="datetime-local" name="starts_at" /><input required type="datetime-local" name="ends_at" /><div className="grid grid-cols-2 gap-3"><input required type="number" min="0" name="online_capacity" defaultValue="20" /><input required type="number" min="0" name="walk_in_reserve" defaultValue="5" /></div><button disabled={busy} className="rounded-xl bg-[#116b5b] px-4 py-2.5 text-sm font-semibold text-white">Update session</button></div></form></>}</section>}
    </>}
  </div>
}

function Metric({ icon: Icon, label, value }: { icon: typeof Users; label: string; value: string }) { return <div className="rounded-2xl border border-[#dceae6] bg-white p-5"><Icon className="text-[#116b5b]" /><p className="mt-5 text-2xl font-semibold">{value}</p><p className="text-sm text-[#58706b]">{label}</p></div> }

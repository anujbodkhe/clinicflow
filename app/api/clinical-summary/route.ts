import { generateText } from 'ai'
import { NextResponse } from 'next/server'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const requestSchema = z.object({
  patientId: z.string().uuid(),
  clinicId: z.string().uuid(),
}).strict()

const maxRequestBytes = 2048
const maxSourceCharacters = 12000
const maxFieldCharacters = 2000

type SummarySource = {
  id: string
  source: string
  recordedAt: string
  content: Record<string, string>
}

async function readBoundedBody(request: Request) {
  const reader = request.body?.getReader()
  if (!reader) return { kind: 'invalid' as const }

  const chunks: Uint8Array[] = []
  let byteLength = 0
  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      byteLength += value.byteLength
      if (byteLength > maxRequestBytes) {
        await reader.cancel()
        return { kind: 'too-large' as const }
      }
      chunks.push(value)
    }
  } catch {
    return { kind: 'unreadable' as const }
  } finally {
    reader.releaseLock()
  }

  const bytes = new Uint8Array(byteLength)
  let offset = 0
  for (const chunk of chunks) {
    bytes.set(chunk, offset)
    offset += chunk.byteLength
  }
  return { kind: 'ok' as const, text: new TextDecoder().decode(bytes) }
}

function boundedText(value: string | null) {
  return (value ?? '').trim().slice(0, maxFieldCharacters)
}

export async function POST(request: Request) {
  const supabase = await createClient()
  const { data: { user }, error: authError } = await supabase.auth.getUser()
  if (authError) return NextResponse.json({ error: 'Authentication could not be verified.' }, { status: 401 })
  if (!user) return NextResponse.json({ error: 'Authentication required.' }, { status: 401 })

  const contentLength = Number(request.headers.get('content-length') ?? 0)
  if (contentLength > maxRequestBytes) {
    return NextResponse.json({ error: 'Request is too large.' }, { status: 413 })
  }

  const bodyResult = await readBoundedBody(request)
  if (bodyResult.kind === 'too-large') {
    return NextResponse.json({ error: 'Request is too large.' }, { status: 413 })
  }
  if (bodyResult.kind !== 'ok') {
    return NextResponse.json({ error: 'Request body could not be read.' }, { status: 400 })
  }

  let body: unknown
  try {
    body = JSON.parse(bodyResult.text)
  } catch {
    return NextResponse.json({ error: 'Request body must be valid JSON.' }, { status: 400 })
  }

  const parsed = requestSchema.safeParse(body)
  if (!parsed.success) {
    return NextResponse.json({ error: 'A valid patient and clinic are required.' }, { status: 400 })
  }

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .maybeSingle()
  if (profileError) return NextResponse.json({ error: 'Account permissions could not be verified.' }, { status: 500 })
  if (profile?.role !== 'doctor') {
    return NextResponse.json({ error: 'Only an authorized doctor can request a clinical summary.' }, { status: 403 })
  }

  const { data: membership, error: membershipError } = await supabase
    .from('clinic_memberships')
    .select('clinic_id')
    .eq('clinic_id', parsed.data.clinicId)
    .eq('user_id', user.id)
    .eq('role', 'doctor')
    .maybeSingle()
  if (membershipError) return NextResponse.json({ error: 'Clinic permissions could not be verified.' }, { status: 500 })
  if (!membership) return NextResponse.json({ error: 'You are not authorized for this clinic.' }, { status: 403 })

  const { data: authorizedConsultation, error: authorizationError } = await supabase
    .from('consultations')
    .select('id')
    .eq('patient_id', parsed.data.patientId)
    .eq('clinic_id', parsed.data.clinicId)
    .eq('doctor_id', user.id)
    .limit(1)
  if (authorizationError) {
    return NextResponse.json({ error: 'Patient access could not be verified.' }, { status: 500 })
  }
  if (!authorizedConsultation?.length) {
    return NextResponse.json({ error: 'You are not authorized to summarize this patient record.' }, { status: 403 })
  }

  const [{ data: histories, error: historyError }, { data: consultations, error: consultationError }] = await Promise.all([
    supabase
      .from('patient_medical_histories')
      .select('id, allergies, conditions, medications, symptoms, notes, source, created_at')
      .eq('patient_id', parsed.data.patientId)
      .order('created_at', { ascending: false })
      .limit(10),
    supabase
      .from('consultations')
      .select('id, symptoms, clinical_notes, diagnosis_notes, created_at')
      .eq('patient_id', parsed.data.patientId)
      .eq('clinic_id', parsed.data.clinicId)
      .eq('doctor_id', user.id)
      .order('created_at', { ascending: false })
      .limit(10),
  ])

  if (historyError || consultationError) {
    return NextResponse.json({ error: 'Authorized source records could not be loaded.' }, { status: 500 })
  }

  const sources: SummarySource[] = [
    ...(histories ?? []).map((record) => ({
      id: record.id,
      source: record.source === 'patient' ? 'Patient-reported history' : 'Clinician-recorded history',
      recordedAt: record.created_at,
      content: {
        allergies: boundedText(record.allergies),
        conditions: boundedText(record.conditions),
        medications: boundedText(record.medications),
        symptoms: boundedText(record.symptoms),
        notes: boundedText(record.notes),
      },
    })),
    ...(consultations ?? []).map((record) => ({
      id: record.id,
      source: 'Clinician-authored consultation',
      recordedAt: record.created_at,
      content: {
        symptoms: boundedText(record.symptoms),
        clinicalNotes: boundedText(record.clinical_notes),
        diagnosisNotes: boundedText(record.diagnosis_notes),
      },
    })),
  ].sort((left, right) => right.recordedAt.localeCompare(left.recordedAt))

  const boundedSources: SummarySource[] = []
  let sourceCharacters = 2
  for (const source of sources) {
    if (!Object.values(source.content).some(Boolean)) continue
    const sourceLength = JSON.stringify(source).length
    if (sourceCharacters + sourceLength + 1 > maxSourceCharacters) continue
    boundedSources.push(source)
    sourceCharacters += sourceLength + 1
  }
  if (!boundedSources.length) {
    return NextResponse.json({ error: 'No source records are available to summarize.' }, { status: 422 })
  }

  try {
    const { text } = await generateText({
      model: 'openai/gpt-5-mini',
      system: 'Create a concise advisory clinical intake summary using only the supplied source records. Identify source types and dates. Distinguish patient-reported information from clinician-authored records and historical medication mentions from confirmed current medication. State when information is unavailable or unclear. Do not diagnose, recommend treatment, generate prescriptions, or decide SOS priority.',
      prompt: JSON.stringify(boundedSources),
    })
    return NextResponse.json({ summary: text })
  } catch {
    return NextResponse.json({ error: 'Clinical summary is temporarily unavailable. Continue with the original source records.' }, { status: 502 })
  }
}

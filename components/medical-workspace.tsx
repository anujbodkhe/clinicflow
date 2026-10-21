'use client'

import { useEffect, useState } from 'react'
import { FileText, HeartPulse, Download, LoaderCircle, Save, Upload } from 'lucide-react'
import { jsPDF } from 'jspdf'
import { createClient } from '@/lib/supabase/client'

type Role = 'super_admin' | 'clinic_admin' | 'doctor' | 'receptionist' | 'patient'
type Clinic = { id: string; name: string }
type RecordRow = { history_id: string; patient_id: string; allergies: string | null; conditions: string | null; medications: string | null; symptoms: string | null; notes: string | null; history_source: string; history_created_at: string; consultation_id: string | null; consultation_status: string | null; clinical_notes: string | null; prescription_id: string | null; prescription_status: string | null }
type Prescription = { id: string; consultation_id: string; patient_id: string; doctor_id: string; status: 'draft' | 'finalized'; created_at: string; pdf_storage_path?: string | null }
type Item = { medicine_name: string; strength: string; dose: string; frequency: string; duration: string; instructions: string }

export function MedicalWorkspace({ role, userId, clinics }: { role: Role; userId: string; clinics: Clinic[] }) {
  const supabase = createClient()
  const [records, setRecords] = useState<RecordRow[]>([])
  const [documents, setDocuments] = useState<{ id: string; file_name: string; storage_path: string; created_at: string }[]>([])
  const [prescriptions, setPrescriptions] = useState<Prescription[]>([])
  const [items, setItems] = useState<Record<string, Item[]>>({})
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState(false)
  const [loading, setLoading] = useState(role === 'patient')
  const [history, setHistory] = useState({ allergies: '', conditions: '', medications: '', symptoms: '', notes: '' })
  const [consult, setConsult] = useState({ patientId: '', clinicId: clinics[0]?.id ?? '', queueEntryId: '', symptoms: '', clinicalNotes: '', diagnosisNotes: '' })
  const [selectedPatient, setSelectedPatient] = useState<{ patientId: string; queueEntryId: string; clinicId: string; walkInPatient?: { full_name: string; phone: string; symptoms: string } | null } | null>(null)
  const [prescriptionForm, setPrescriptionForm] = useState({ consultationId: '', patientId: '', items: [{ medicine_name: '', strength: '', dose: '', frequency: '', duration: '', instructions: '' }] as Item[] })

  async function loadPatientData(patientId = userId) {
    const [{ data: recordData, error: recordError }, { data: documentData }, { data: prescriptionData }] = await Promise.all([
      supabase.rpc('list_patient_medical_records', { p_patient_id: patientId }),
      supabase.from('medical_documents').select('id, file_name, storage_path, created_at').eq('patient_id', patientId).order('created_at', { ascending: false }),
      supabase.from('prescriptions').select('id, consultation_id, patient_id, doctor_id, status, created_at, pdf_storage_path').eq('patient_id', patientId).eq('status', 'finalized').order('created_at', { ascending: false }),
    ])
    if (recordError) setMessage(recordError.message)
    setRecords((recordData ?? []) as RecordRow[])
    setDocuments(documentData ?? [])
    const next = (prescriptionData ?? []) as Prescription[]
    setPrescriptions(next)
    if (next.length) {
      const { data } = await supabase.from('prescription_items').select('prescription_id, medicine_name, strength, dose, frequency, duration, instructions').in('prescription_id', next.map((p) => p.id))
      const grouped: Record<string, Item[]> = {}
      for (const row of data ?? []) {
        const item = { medicine_name: row.medicine_name, strength: row.strength, dose: row.dose, frequency: row.frequency, duration: row.duration, instructions: row.instructions }
        grouped[row.prescription_id] = [...(grouped[row.prescription_id] ?? []), item]
      }
      setItems(grouped)
    } else setItems({})
    setLoading(false)
  }

  useEffect(() => { if (role === 'patient') void loadPatientData(); else setLoading(false) }, [role, userId])
  useEffect(() => { const handleSelection = (event: Event) => { const detail = (event as CustomEvent<{ patientId: string; queueEntryId: string; clinicId: string; walkInPatient?: { full_name: string; phone: string; symptoms: string } | null }>).detail; setSelectedPatient(detail); setConsult((current) => ({ ...current, patientId: detail.patientId, queueEntryId: detail.queueEntryId, clinicId: detail.clinicId, symptoms: detail.walkInPatient?.symptoms ?? current.symptoms })); void loadPatientData(detail.patientId) }; window.addEventListener('clinicflow:start-consultation', handleSelection); return () => window.removeEventListener('clinicflow:start-consultation', handleSelection) }, [userId])

  async function saveHistory(event: React.FormEvent) { event.preventDefault(); setBusy(true); const { error } = await supabase.rpc('save_patient_history', { p_allergies: history.allergies, p_conditions: history.conditions, p_medications: history.medications, p_symptoms: history.symptoms, p_notes: history.notes }); setMessage(error?.message ?? 'Medical history saved.'); if (!error) await loadPatientData(); setBusy(false) }
  async function uploadDocument(event: React.ChangeEvent<HTMLInputElement>) { const file = event.target.files?.[0]; if (!file) return; const allowed = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp']; if (!allowed.includes(file.type) || file.size > 10 * 1024 * 1024) { setMessage('Use a PDF or JPG, PNG, or WEBP image up to 10 MB.'); return } setBusy(true); const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, '-'); const path = `${userId}/${safeName}`; try { const { error: uploadError } = await supabase.storage.from('medical-documents').upload(path, file, { contentType: file.type, upsert: true }); if (uploadError) { setMessage(`Document upload failed: ${uploadError.message}`); return } const { error: metadataError } = await supabase.from('medical_documents').upsert({ patient_id: userId, uploaded_by: userId, storage_path: path, file_name: file.name, mime_type: file.type, file_size: file.size }, { onConflict: 'storage_path', ignoreDuplicates: true }); if (metadataError) { setMessage(`Document metadata could not be saved: ${metadataError.message}. The uploaded file may remain in private storage; retrying is safe.`); return } setMessage('Private document uploaded.'); await loadPatientData() } finally { setBusy(false) } }
  async function openDocument(path: string) { const { data, error } = await supabase.storage.from('medical-documents').createSignedUrl(path, 300); if (error) setMessage(error.message); else window.open(data.signedUrl, '_blank', 'noopener,noreferrer') }
  async function persistPrescriptionPdf(prescriptionId: string, patientId: string, issuedAt: string, rows: Item[], allowExisting = false) {
    const pdf = new jsPDF();
    pdf.setFillColor(17, 107, 91); pdf.rect(0, 0, 210, 28, 'F');
    pdf.setTextColor(255, 255, 255); pdf.setFontSize(20); pdf.text('ClinicFlow', 16, 18);
    pdf.setFontSize(10); pdf.text('Finalized prescription', 150, 18);
    pdf.setTextColor(24, 50, 47); pdf.setFontSize(11); pdf.text(`Prescription ID: ${prescriptionId}`, 16, 42); pdf.text(`Issued (UTC): ${new Date(issuedAt).toISOString().slice(0, 10)}`, 16, 50);
    let y = 68;
    rows.forEach((item, index) => {
      pdf.setFontSize(13); pdf.text(`${index + 1}. ${item.medicine_name} — ${item.strength}`, 16, y);
      pdf.setFontSize(10); pdf.text(`${item.dose} | ${item.frequency} | ${item.duration}`, 22, y + 8);
      if (item.instructions) pdf.text(`Instructions: ${item.instructions}`, 22, y + 16);
      y += item.instructions ? 28 : 20;
    });
    pdf.setFontSize(9); pdf.setTextColor(88, 112, 107); pdf.text('Generated from doctor-reviewed ClinicFlow records. Verify instructions with your clinician.', 16, 282);
    const pdfBlob = pdf.output('blob') as Blob;
    const storagePath = `${patientId}/prescriptions/${prescriptionId}.pdf`;
    // Use upsert: false (plain INSERT) so that Storage only needs INSERT permission on
    // first upload, avoiding the SELECT dependency that caused "new row violates row-level
    // security policy" when no storage.objects row existed yet.  If the object already
    // exists (retry after a partial failure), Storage returns a 409-style error which is
    // surfaced as a non-null uploadError with a message containing "already exists"; in
    // that case the caller (retryPrescriptionPdf) passes allowExisting: true to skip the
    // upload step and continue with metadata and attach_prescription_pdf.
    const { error: uploadError } = await supabase.storage.from('medical-documents').upload(storagePath, pdfBlob, { contentType: 'application/pdf', upsert: false });
    if (uploadError) {
      const alreadyExists = uploadError.message.toLowerCase().includes('already exists') || uploadError.message.toLowerCase().includes('duplicate') || (uploadError as { statusCode?: string }).statusCode === '409' || (uploadError as { statusCode?: number }).statusCode === 409;
      if (!allowExisting || !alreadyExists) {
        setMessage(`Prescription was finalized but the private PDF could not be stored: ${uploadError.message}`);
        return null
      }
      // Object already exists from a previous partial attempt; proceed to ensure
      // metadata and prescription reference are also recorded.
    }
    const { error: metadataError } = await supabase.from('medical_documents').upsert({ patient_id: patientId, uploaded_by: userId, storage_path: storagePath, file_name: `clinicflow-prescription-${prescriptionId}.pdf`, mime_type: 'application/pdf', file_size: pdfBlob.size }, { onConflict: 'storage_path', ignoreDuplicates: true });
    if (metadataError) {
      setMessage(`Prescription was finalized but private PDF metadata could not be saved: ${metadataError.message}`);
      return null
    }
    const { error: attachError } = await supabase.rpc('attach_prescription_pdf', { p_prescription_id: prescriptionId, p_storage_path: storagePath });
    if (attachError) {
      setMessage(`Prescription was finalized but the private PDF reference could not be recorded: ${attachError.message}`);
      return null
    }
    return storagePath
  }
  async function retryPrescriptionPdf(prescription: Prescription) {
    if (!prescription.patient_id) {
      setMessage('Private PDF persistence is not supported for this patient identity yet.')
      return
    }
    const rows = items[prescription.id] ?? []
    if (!rows.length) {
      setMessage('Prescription items could not be loaded; the private PDF was not regenerated.')
      return
    }
    setBusy(true)
    setMessage('')
    try {
      const storagePath = await persistPrescriptionPdf(prescription.id, prescription.patient_id, prescription.created_at, rows, true)
      if (!storagePath) return
      setMessage('Prescription PDF saved to private storage.')
      await loadPatientData(prescription.patient_id)
    } finally {
      setBusy(false)
    }
  }
  async function saveConsultation(event: React.FormEvent) { event.preventDefault(); if (!selectedPatient || consult.patientId !== selectedPatient.patientId || consult.queueEntryId !== selectedPatient.queueEntryId || consult.clinicId !== selectedPatient.clinicId) { setMessage('Select an eligible patient from Today\'s Queue before saving.'); return } setBusy(true); const { data, error } = await supabase.rpc('create_consultation', { p_patient_id: consult.patientId || null, p_clinic_id: consult.clinicId, p_queue_entry_id: consult.queueEntryId || null, p_symptoms: consult.symptoms, p_clinical_notes: consult.clinicalNotes, p_diagnosis_notes: consult.diagnosisNotes }); setMessage(error?.message ?? 'Consultation saved as draft.'); if (!error && data) setPrescriptionForm((current) => ({ ...current, consultationId: data.id, patientId: consult.patientId })); setBusy(false) }
  async function finalizeConsultation() { if (!prescriptionForm.consultationId) return setMessage('Save a consultation first.'); setBusy(true); const { error } = await supabase.rpc('finalize_consultation', { p_consultation_id: prescriptionForm.consultationId }); setMessage(error?.message ?? 'Consultation finalized.'); setBusy(false) }
  async function createPrescription() {
    const valid = prescriptionForm.items.filter((item) => Object.values(item).some(Boolean))
    if (!prescriptionForm.consultationId || valid.some((item) => !item.medicine_name || !item.strength || !item.dose || !item.frequency || !item.duration)) {
      setMessage('Finalize a consultation and complete every prescription item.')
      return
    }
    setBusy(true)
    setMessage('')
    try {
      const { data, error } = await supabase.rpc('create_prescription', { p_consultation_id: prescriptionForm.consultationId, p_items: valid })
      if (error || !data) {
        setMessage(error?.message ?? 'Prescription could not be saved.')
        return
      }
      const { error: finalizeError } = await supabase.rpc('finalize_prescription', { p_prescription_id: data.id })
      if (finalizeError) {
        setMessage(finalizeError.message ?? 'Prescription could not be finalized.')
        return
      }
      const patientId = data.patient_id
      if (!patientId) {
        setMessage('Prescription was finalized, but private PDF storage is not supported for this patient identity.')
        return
      }
      const storagePath = await persistPrescriptionPdf(data.id, patientId, data.created_at, valid)
      if (!storagePath) {
        await loadPatientData(patientId)
        return
      }
      setMessage('Prescription reviewed, finalized, and saved to private storage.')
      await loadPatientData(patientId)
    } finally {
      setBusy(false)
    }
  }
  async function downloadPrescription(prescription: Prescription) {
    if (!prescription.pdf_storage_path) {
      setMessage('Prescription PDF is not available in private storage. Contact your clinic for help.')
      return
    }
    await openDocument(prescription.pdf_storage_path)
  }
  const updateItem = (index: number, key: keyof Item, value: string) => setPrescriptionForm((current) => ({ ...current, items: current.items.map((item, itemIndex) => itemIndex === index ? { ...item, [key]: value } : item) }))
  const field = (key: keyof typeof history, label: string) => <label className="grid gap-1 text-sm"><span className="font-medium">{label}</span><textarea value={history[key]} onChange={(event) => setHistory({ ...history, [key]: event.target.value })} className="min-h-20 rounded-xl border border-[#cfe5df] px-3 py-2" /></label>

  return <section className="mt-8 rounded-2xl border border-[#dceae6] bg-white p-6"><div className="flex items-center gap-3"><div className="flex size-10 items-center justify-center rounded-xl bg-[#e9f6f2] text-[#116b5b]"><HeartPulse /></div><div><h2 className="text-2xl font-semibold">Medical records</h2><p className="text-sm text-[#58706b]">Private, source-labelled records connected to Supabase.</p></div></div>    {message && <p role="status" className="mt-4 rounded-xl bg-[#fff7f4] px-4 py-3 text-sm text-[#9a4d3b]">{message}</p>}
    {loading && <div role="status" className="mt-4 flex items-center gap-2 rounded-xl bg-[#f7faf9] px-4 py-3 text-sm text-[#58706b]"><LoaderCircle className="size-4 animate-spin" />Loading your private records…</div>}
    {role === 'patient' && <div className="mt-6 grid gap-6 lg:grid-cols-2"><form onSubmit={saveHistory} className="grid gap-3"><h3 className="font-semibold">Your reported history</h3>{field('allergies','Allergies')}{field('conditions','Conditions')}{field('medications','Current medications')}{field('symptoms','Current symptoms')}{field('notes','Additional notes')}<button disabled={busy} className="rounded-xl bg-[#116b5b] px-4 py-2.5 text-sm font-semibold text-white"><Save className="mr-2 inline size-4" />Save history</button><label className="flex cursor-pointer items-center gap-2 rounded-xl border border-dashed border-[#9bcabd] px-4 py-3 text-sm"><Upload className="size-4" />Upload private document<input type="file" accept="application/pdf,image/jpeg,image/png,image/webp" onChange={uploadDocument} className="sr-only" /></label></form><div><h3 className="font-semibold">My records</h3><div className="mt-3 grid gap-3">{records.map((record, index) => <div key={`${record.history_id}:${index}`} className="rounded-xl bg-[#f7faf9] p-4 text-sm"><p className="font-medium">{record.history_source === 'patient' ? 'Patient-reported' : 'Clinician-recorded'} · {new Date(record.history_created_at).toLocaleDateString()}</p><p className="mt-2 whitespace-pre-wrap">{record.symptoms || record.notes || 'No additional notes.'}</p></div>)}</div><h3 className="mt-6 font-semibold">Private documents</h3><div className="mt-3 grid gap-2">{documents.map((document) => <button type="button" key={document.id} onClick={() => void openDocument(document.storage_path)} className="flex items-center gap-2 text-left text-sm text-[#116b5b]"><FileText className="size-4" />{document.file_name}</button>)}</div><h3 className="mt-6 font-semibold">Finalized prescriptions</h3>{prescriptions.map((prescription) => <button type="button" key={prescription.id} onClick={() => downloadPrescription(prescription)} className="mt-2 flex items-center gap-2 text-sm text-[#116b5b]"><Download className="size-4" />Download prescription PDF</button>)}</div></div>}
    {role === 'doctor' && <div className="mt-6 grid gap-6 lg:grid-cols-2"><form onSubmit={saveConsultation} className="grid gap-3"><h3 className="font-semibold">Record consultation</h3>{selectedPatient ? <div className="rounded-xl border border-[#cfe5df] bg-[#f7faf9] p-4 text-sm"><p className="font-semibold">Selected patient</p><p className="mt-1 text-[#58706b]">Patient summary loaded from today&apos;s queue. Consultation is linked automatically to this patient and queue entry.</p><p className="mt-2 text-xs text-[#58706b]">{records.length} authorized medical record{records.length === 1 ? '' : 's'} available</p></div> : <p className="rounded-xl bg-[#fff7f4] px-4 py-3 text-sm text-[#9a4d3b]">Select an eligible patient from Today&apos;s Queue to start a consultation.</p>}<select required value={consult.clinicId} onChange={(event) => setConsult({ ...consult, clinicId: event.target.value })} className="rounded-xl border border-[#cfe5df] px-3 py-2 text-sm">{clinics.map((clinic) => <option key={clinic.id} value={clinic.id}>{clinic.name}</option>)}</select><textarea required placeholder="Patient symptoms" value={consult.symptoms} onChange={(event) => setConsult({ ...consult, symptoms: event.target.value })} className="min-h-20 rounded-xl border border-[#cfe5df] px-3 py-2 text-sm" /><textarea required placeholder="Clinical notes" value={consult.clinicalNotes} onChange={(event) => setConsult({ ...consult, clinicalNotes: event.target.value })} className="min-h-24 rounded-xl border border-[#cfe5df] px-3 py-2 text-sm" /><textarea placeholder="Diagnosis notes" value={consult.diagnosisNotes} onChange={(event) => setConsult({ ...consult, diagnosisNotes: event.target.value })} className="min-h-20 rounded-xl border border-[#cfe5df] px-3 py-2 text-sm" /><div className="flex flex-wrap gap-2"><button disabled={busy} className="rounded-xl bg-[#116b5b] px-4 py-2.5 text-sm font-semibold text-white">Save draft</button><button type="button" disabled={busy} onClick={() => void finalizeConsultation()} className="rounded-xl border border-[#cfe5df] px-4 py-2.5 text-sm">Finalize consultation</button></div></form><div className="grid content-start gap-3 rounded-xl bg-[#f7faf9] p-5"><h3 className="font-semibold">Doctor-reviewed prescription</h3><p className="text-sm text-[#58706b]">Consultation: {prescriptionForm.consultationId || 'save a draft first'}</p>{prescriptionForm.items.map((item, index) => <div key={index} className="grid gap-2 rounded-xl border border-[#dceae6] bg-white p-3">{(['medicine_name','strength','dose','frequency','duration','instructions'] as (keyof Item)[]).map((key) => <input key={key} placeholder={key.replace('_',' ')} value={item[key]} onChange={(event) => updateItem(index, key, event.target.value)} className="rounded-lg border border-[#cfe5df] px-3 py-2 text-sm" />)}</div>)}<button type="button" onClick={() => setPrescriptionForm((current) => ({ ...current, items: [...current.items, { medicine_name: '', strength: '', dose: '', frequency: '', duration: '', instructions: '' }] }))} className="rounded-xl border border-[#cfe5df] px-4 py-2 text-sm">Add medicine</button><button type="button" disabled={busy} onClick={() => void createPrescription()} className="rounded-xl bg-[#116b5b] px-4 py-2.5 text-sm font-semibold text-white">Save and finalize prescription</button></div></div>}
    {role === 'doctor' && selectedPatient && prescriptions.filter((prescription) => prescription.patient_id === selectedPatient.patientId && !prescription.pdf_storage_path).map((prescription) => <button key={prescription.id} type="button" disabled={busy} onClick={() => void retryPrescriptionPdf(prescription)} className="mt-4 rounded-xl border border-[#cfe5df] px-4 py-2 text-sm disabled:opacity-50">Retry private PDF storage for finalized prescription</button>)}
    {role === 'receptionist' && <p className="mt-6 rounded-xl bg-[#f7faf9] p-4 text-sm text-[#58706b]">Receptionists can operate queues but cannot access routine medical records.</p>}
  </section>
}

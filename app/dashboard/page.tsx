import { redirect } from 'next/navigation'
import { Activity, Building2, LogOut, ShieldCheck, Users } from 'lucide-react'
import { MedicalWorkspace } from '@/components/medical-workspace'
import { QueueWorkspace } from '@/components/queue-workspace'
import { SuperAdminUsers } from '@/components/super-admin-users'
import { createClient } from '@/lib/supabase/server'

type Role = 'super_admin' | 'clinic_admin' | 'doctor' | 'receptionist' | 'patient'
type AdminUser = { user_id: string; email: string | null; full_name: string; role: Role; created_at: string }

const roleLabels: Record<string, string> = { super_admin: 'Super Admin', clinic_admin: 'Clinic Admin', doctor: 'Doctor', receptionist: 'Receptionist', patient: 'Patient' }

export default async function DashboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/login')

  const [{ data: profile }, { data: memberships }] = await Promise.all([
    supabase.from('profiles').select('full_name, role').eq('id', user.id).maybeSingle(),
    supabase.from('clinic_memberships').select('clinic_id, role, clinics(id, name, slug, address)').eq('user_id', user.id),
  ])

  const role = (profile?.role ?? 'patient') as Role
  const name = profile?.full_name?.trim() || user.email?.split('@')[0] || 'there'
  const clinics = (memberships ?? []).flatMap((membership) => {
    const clinic = Array.isArray(membership.clinics) ? membership.clinics[0] : membership.clinics
    return clinic ? [{ ...clinic, membershipRole: membership.role as Role }] : []
  })
  const clinicIds = clinics.map((clinic) => clinic.id)
  const [adminUsersResult, adminClinicsResult] = role === 'super_admin'
    ? await Promise.all([
        supabase.rpc('admin_list_users'),
        supabase.from('clinics').select('id, name').eq('active', true).order('name'),
      ])
    : [{ data: [], error: null }, { data: [], error: null }]
  const adminLoadError = adminUsersResult.error?.message ?? adminClinicsResult.error?.message ?? null
  const adminUsers = (adminUsersResult.data ?? []) as AdminUser[]
  const adminClinics = adminClinicsResult.data ?? []

  const [{ data: availability }, { data: ownEntries }, { data: staffSessions }, { data: staffEntries }] = await Promise.all([
    role === 'patient' ? supabase.rpc('patient_queue_availability', { p_clinic_id: null }) : Promise.resolve({ data: [] }),
    role === 'patient' ? supabase.from('queue_entries').select('id, session_id, token, status, source, urgency, estimated_minutes, sos_requested_at, sos_approved_at').eq('patient_id', user.id).order('created_at', { ascending: false }).limit(10) : Promise.resolve({ data: [] }),
    role !== 'patient' && clinicIds.length ? supabase.from('queue_sessions').select('id, clinic_id, doctor_id, session_date, starts_at, ends_at, online_capacity, walk_in_reserve, total_capacity, status, clinics(name), profiles!queue_sessions_doctor_id_fkey(full_name)').in('clinic_id', clinicIds).eq('status', 'open').order('session_date') : Promise.resolve({ data: [] }),
    role !== 'patient' && clinicIds.length ? supabase.from('queue_entries').select('id, session_id, patient_id, token, status, urgency, estimated_minutes, sos_requested_at, sos_approved_at, queue_sessions!inner(clinic_id)').in('queue_sessions.clinic_id', clinicIds).order('created_at') : Promise.resolve({ data: [] }),
  ])

  const normalizedStaffSessions = (staffSessions ?? []).map((session: any) => ({
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
  }))

  return <main className="min-h-screen bg-[#f7faf9] text-[#18322f]">
    <header className="border-b border-[#dceae6] bg-white"><div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-5 lg:px-10"><a href="/" className="flex items-center gap-2 font-semibold"><span className="flex size-9 items-center justify-center rounded-xl bg-[#116b5b] text-white"><Activity /></span>ClinicFlow</a><div className="flex items-center gap-4"><div className="hidden text-right sm:block"><p className="text-sm font-semibold">{name}</p><p className="text-xs text-[#58706b]">{roleLabels[role] ?? role}</p></div><form action="/auth/sign-out" method="post"><button aria-label="Sign out" className="rounded-xl p-2 text-[#58706b] hover:bg-[#f3f8f6]"><LogOut /></button></form></div></div></header>
    <section className="mx-auto max-w-7xl px-6 py-12 lg:px-10"><p className="text-sm font-semibold uppercase tracking-widest text-[#ef896f]">{roleLabels[role] ?? 'Workspace'}</p><h1 className="mt-2 text-4xl font-semibold tracking-tight">Welcome, {name.split(' ')[0]}.</h1><p className="mt-3 max-w-2xl text-[#58706b]">Live queue operations, capacity, and clinic access are connected to Supabase.</p><div className="mt-10 grid gap-5 md:grid-cols-3"><div className="rounded-2xl bg-[#116b5b] p-6 text-white"><ShieldCheck /><p className="mt-8 text-xl font-semibold">Authenticated</p><p className="mt-1 text-sm text-[#c7e5dd]">Your session is active and protected.</p></div><div className="rounded-2xl border border-[#dceae6] bg-white p-6"><Building2 className="text-[#116b5b]" /><p className="mt-8 text-xl font-semibold">{clinics.length} clinic{clinics.length === 1 ? '' : 's'}</p><p className="mt-1 text-sm text-[#58706b]">Membership-scoped clinic access.</p></div><div className="rounded-2xl border border-[#dceae6] bg-white p-6"><Users className="text-[#116b5b]" /><p className="mt-8 text-xl font-semibold">Live queue</p><p className="mt-1 text-sm text-[#58706b]">Database RPCs enforce role permissions.</p></div></div>{role === 'super_admin' && <SuperAdminUsers users={adminUsers} clinics={adminClinics} currentUserId={user.id} loadError={adminLoadError} />}<QueueWorkspace role={role} userId={user.id} clinics={clinics} availability={(availability ?? []) as any} entries={(ownEntries ?? []) as any} staffSessions={normalizedStaffSessions} staffEntries={(staffEntries ?? []) as any} /><MedicalWorkspace role={role} userId={user.id} clinics={clinics.map((clinic) => ({ id: clinic.id, name: clinic.name }))} /></section>
  </main>
}

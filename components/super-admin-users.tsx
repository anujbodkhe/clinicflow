'use client'

import { useMemo, useState } from 'react'
import { createClient } from '@/lib/supabase/client'

type Role = 'super_admin' | 'clinic_admin' | 'doctor' | 'receptionist' | 'patient'
type AdminUser = { user_id: string; email: string | null; full_name: string; role: Role; created_at: string }
type AdminClinic = { id: string; name: string }

const roleLabels: Record<Role, string> = {
  super_admin: 'Super Admin',
  clinic_admin: 'Clinic Admin',
  doctor: 'Doctor',
  receptionist: 'Receptionist',
  patient: 'Patient',
}

const clinicRoles = new Set<Role>(['clinic_admin', 'doctor', 'receptionist'])
const roles = Object.keys(roleLabels) as Role[]

export function SuperAdminUsers({
  users: initialUsers,
  clinics,
  currentUserId,
  loadError,
}: {
  users: AdminUser[]
  clinics: AdminClinic[]
  currentUserId: string
  loadError: string | null
}) {
  const supabase = useMemo(() => createClient(), [])
  const [users, setUsers] = useState(initialUsers)
  const [selectedRoles, setSelectedRoles] = useState<Record<string, Role>>(
    () => Object.fromEntries(initialUsers.map((user) => [user.user_id, user.role])),
  )
  const [selectedClinics, setSelectedClinics] = useState<Record<string, string>>(
    () => Object.fromEntries(initialUsers.map((user) => [user.user_id, clinics[0]?.id ?? ''])),
  )
  const [busyUserId, setBusyUserId] = useState<string | null>(null)
  const [message, setMessage] = useState('')
  const [error, setError] = useState(loadError ?? '')

  async function changeRole(user: AdminUser) {
    const role = selectedRoles[user.user_id]
    const clinicId = selectedClinics[user.user_id] || null
    setBusyUserId(user.user_id)
    setMessage('')
    setError('')

    const { error: updateError } = await supabase.rpc('admin_change_user_role', {
      p_target_user_id: user.user_id,
      p_role: role,
      p_clinic_id: clinicRoles.has(role) ? clinicId : null,
    })

    if (updateError) {
      setError(updateError.message)
      setBusyUserId(null)
      return
    }

    const { data, error: refreshError } = await supabase.rpc('admin_list_users')
    if (refreshError) {
      setError(`Role updated, but the user list could not be refreshed: ${refreshError.message}`)
      setBusyUserId(null)
      return
    }

    const updatedUsers = (data ?? []) as AdminUser[]
    setUsers(updatedUsers)
    setSelectedRoles(Object.fromEntries(updatedUsers.map((entry) => [entry.user_id, entry.role])))
    setSelectedClinics((current) => Object.fromEntries(
      updatedUsers.map((entry) => [entry.user_id, current[entry.user_id] ?? clinics[0]?.id ?? '']),
    ))
    setMessage(`Updated ${user.email ?? (user.full_name || 'user')} to ${roleLabels[role]}.`)
    setBusyUserId(null)
  }

  return <section className="mt-8 rounded-2xl border border-[#dceae6] bg-white p-6">
    <h2 className="text-xl font-semibold">User roles</h2>
    <p className="mt-1 text-sm text-[#58706b]">Assign roles to existing accounts. Public sign-up remains Patient-only.</p>
    <p className="mt-2 text-xs text-[#58706b]">Changing to a clinic role replaces the user&apos;s clinic access with the selected clinic. Patient removes clinic access; Super Admin grants access across clinics.</p>
    {message && <p role="status" className="mt-4 rounded-xl border border-[#b9dfd4] bg-[#eff9f5] px-4 py-3 text-sm text-[#116b5b]">{message}</p>}
    {error && <p role="alert" className="mt-4 rounded-xl border border-[#f0c9bd] bg-[#fff7f4] px-4 py-3 text-sm text-[#9a4d3b]">{error}</p>}
    {users.length === 0 && !error && <p className="mt-5 text-sm text-[#58706b]">No user accounts are available.</p>}
    <div className="mt-5 space-y-3">
      {users.map((user) => {
        const role = selectedRoles[user.user_id] ?? user.role
        const isBusy = busyUserId === user.user_id
        return <div key={user.user_id} className="grid gap-3 rounded-xl border border-[#e7efec] p-4 md:grid-cols-[minmax(0,1fr)_12rem_12rem_auto] md:items-center">
          <div className="min-w-0">
            <p className="truncate font-medium">{user.full_name.trim() || user.email || 'Unnamed user'}</p>
            <p className="truncate text-sm text-[#58706b]">{user.email ?? 'No email address'}</p>
          </div>
          <label className="text-sm">
            <span className="sr-only">Role for {user.email ?? user.full_name}</span>
            <select
              value={role}
              onChange={(event) => setSelectedRoles((current) => ({ ...current, [user.user_id]: event.target.value as Role }))}
              disabled={isBusy || user.user_id === currentUserId}
              className="w-full rounded-xl border border-[#cfe5df] bg-white px-3 py-2"
            >
              {roles.map((option) => <option key={option} value={option}>{roleLabels[option]}</option>)}
            </select>
          </label>
          {clinicRoles.has(role) ? <label className="text-sm">
            <span className="sr-only">Clinic for {user.email ?? user.full_name}</span>
            <select
              value={selectedClinics[user.user_id] ?? ''}
              onChange={(event) => setSelectedClinics((current) => ({ ...current, [user.user_id]: event.target.value }))}
              disabled={isBusy || user.user_id === currentUserId || clinics.length === 0}
              className="w-full rounded-xl border border-[#cfe5df] bg-white px-3 py-2"
            >
              <option value="">Select clinic</option>
              {clinics.map((clinic) => <option key={clinic.id} value={clinic.id}>{clinic.name}</option>)}
            </select>
          </label> : <span className="hidden md:block" />}
          <button
            type="button"
            disabled={isBusy || user.user_id === currentUserId || role === user.role || (clinicRoles.has(role) && !selectedClinics[user.user_id])}
            onClick={() => void changeRole(user)}
            className="rounded-xl bg-[#116b5b] px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
          >
            {user.user_id === currentUserId ? 'Your account' : isBusy ? 'Saving…' : 'Save role'}
          </button>
        </div>
      })}
    </div>
  </section>
}

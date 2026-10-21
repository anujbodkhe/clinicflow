import { createClient } from "@supabase/supabase-js";

const confirmation = "I_CONFIRM_NON_PRODUCTION";
const pageSize = 1000;

const demoUsers = [
  ["clinicflow.demo.superadmin@example.test", "Demo Super Admin"],
  ["clinicflow.demo.north.admin@example.test", "North Demo Admin"],
  ["clinicflow.demo.north.doctor@example.test", "North Demo Doctor"],
  ["clinicflow.demo.north.reception@example.test", "North Demo Reception"],
  ["clinicflow.demo.north.patient1@example.test", "North Demo Patient One"],
  ["clinicflow.demo.north.patient2@example.test", "North Demo Patient Two"],
  ["clinicflow.demo.south.admin@example.test", "South Demo Admin"],
  ["clinicflow.demo.south.doctor@example.test", "South Demo Doctor"],
  ["clinicflow.demo.south.reception@example.test", "South Demo Reception"],
  ["clinicflow.demo.south.patient1@example.test", "South Demo Patient One"],
];

const supabaseUrl = process.env.DEMO_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const demoPassword = process.env.DEMO_USER_PASSWORD;

if (process.env.DEMO_NON_PRODUCTION_CONFIRM !== confirmation) {
  throw new Error(
    `Safety stop: set DEMO_NON_PRODUCTION_CONFIRM=${confirmation} only for a dedicated non-production project.`,
  );
}

if (!supabaseUrl || !serviceRoleKey || !demoPassword) {
  throw new Error(
    "Set DEMO_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and DEMO_USER_PASSWORD in the local process environment.",
  );
}

if (demoPassword.length < 12) {
  throw new Error("DEMO_USER_PASSWORD must be at least 12 characters.");
}

const parsedUrl = new URL(supabaseUrl);
if (parsedUrl.protocol !== "https:" && parsedUrl.hostname !== "localhost" && parsedUrl.hostname !== "127.0.0.1") {
  throw new Error("DEMO_SUPABASE_URL must use HTTPS, except for local development.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

async function listExistingUsers() {
  const usersByEmail = new Map();

  for (let page = 1; ; page += 1) {
    const { data, error } = await supabase.auth.admin.listUsers({
      page,
      perPage: pageSize,
    });

    if (error) {
      throw new Error(`Unable to list Auth users: ${error.message}`);
    }

    for (const user of data.users) {
      if (user.email) {
        usersByEmail.set(user.email.toLowerCase(), user);
      }
    }

    if (data.users.length < pageSize) {
      return usersByEmail;
    }
  }
}

const existingUsers = await listExistingUsers();
let created = 0;
let alreadyPresent = 0;

for (const [email, fullName] of demoUsers) {
  if (existingUsers.has(email)) {
    console.log(`Already exists; left unchanged: ${email}`);
    alreadyPresent += 1;
    continue;
  }

  const { error } = await supabase.auth.admin.createUser({
    email,
    password: demoPassword,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });

  if (error) {
    throw new Error(`Unable to create ${email}: ${error.message}`);
  }

  console.log(`Created: ${email}`);
  created += 1;
}

console.log(`Finished. Created ${created}; left existing accounts unchanged: ${alreadyPresent}.`);

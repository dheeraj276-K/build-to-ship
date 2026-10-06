import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { FoodBridgeRole, PublicSignupRole } from "./domain";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim();
const supabasePublishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim();

export const isSupabaseConfigured = Boolean(supabaseUrl && supabasePublishableKey);

export const supabase: SupabaseClient | null =
  supabaseUrl && supabasePublishableKey
    ? createClient(supabaseUrl, supabasePublishableKey, {
        auth: {
          autoRefreshToken: true,
          detectSessionInUrl: true,
          persistSession: true,
        },
        realtime: {
          params: { eventsPerSecond: 10 },
        },
      })
    : null;

export function requireSupabase(): SupabaseClient {
  if (!supabase) {
    throw new Error(
      "Supabase is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY to enable live accounts and shared data.",
    );
  }
  return supabase;
}

export interface SignUpInput {
  fullName: string;
  email: string;
  password: string;
  phone?: string;
  role: PublicSignupRole;
  organizationName?: string;
}

export async function signUp(input: SignUpInput) {
  if (!["DONOR", "NGO", "VOLUNTEER"].includes(input.role)) {
    throw new Error("Public registration is limited to donors, NGOs, and volunteers.");
  }
  const client = requireSupabase();
  return client.auth.signUp({
    email: input.email,
    password: input.password,
    options: {
      data: {
        full_name: input.fullName.trim(),
        phone: input.phone?.trim() || null,
        organization_name: input.organizationName?.trim() || null,
        role: input.role,
      },
    },
  });
}

export async function signIn(email: string, password: string) {
  return requireSupabase().auth.signInWithPassword({ email, password });
}

export async function sendPasswordReset(email: string, redirectTo?: string) {
  return requireSupabase().auth.resetPasswordForEmail(email, { redirectTo });
}

export async function signInWithGoogle(redirectTo?: string) {
  return requireSupabase().auth.signInWithOAuth({
    provider: "google",
    options: redirectTo ? { redirectTo } : undefined,
  });
}

export async function getProfile(userId: string) {
  const { data, error } = await requireSupabase()
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .single();
  if (error) throw error;
  return data as unknown as {
    id: string;
    full_name: string;
    email: string | null;
    phone: string | null;
    role: FoodBridgeRole;
    organization_name: string | null;
    avatar_url: string | null;
  };
}

export async function signOut() {
  const { error } = await requireSupabase().auth.signOut();
  if (error) throw error;
}

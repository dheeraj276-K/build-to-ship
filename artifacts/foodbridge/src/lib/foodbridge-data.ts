import type {
  Donation,
  DonationStatus,
  Feedback,
  FoodBridgeNotification,
  Organization,
  PickupTask,
  PickupTaskStatus,
  Volunteer,
} from "./domain";
import { requireSupabase } from "./supabase";

export type DonationInput = Pick<
  Donation,
  | "food_name"
  | "food_category"
  | "description"
  | "quantity"
  | "quantity_unit"
  | "prepared_at"
  | "expiry_at"
  | "pickup_address"
  | "latitude"
  | "longitude"
  | "food_condition"
> & { image?: File | null };

export async function createDonation(userId: string, input: DonationInput) {
  const client = requireSupabase();
  let imageUrl: string | null = null;
  let imagePath: string | null = null;

  if (input.image) {
    const { uploadFoodImage } = await import("./supabase-storage");
    const uploaded = await uploadFoodImage(input.image, userId);
    imageUrl = uploaded.publicUrl;
    imagePath = uploaded.path;
  }

  const { image: _image, ...details } = input;
  const { data, error } = await client
    .from("donations")
    .insert({
      ...details,
      donor_id: userId,
      image_url: imageUrl,
      status: "AVAILABLE" satisfies DonationStatus,
      claimed_by: null,
      is_demo: false,
    })
    .select("*")
    .single();

  if (error) {
    if (imagePath) {
      await client.storage.from("food-images").remove([imagePath]).catch(() => undefined);
    }
    throw error;
  }
  return data as unknown as Donation;
}

export async function getMyDonations(userId: string, limit = 50) {
  const safeLimit = Math.max(1, Math.min(limit, 100));
  const { data, error } = await requireSupabase()
    .from("donations")
    .select("*")
    .eq("donor_id", userId)
    .order("created_at", { ascending: false })
    .limit(safeLimit);
  if (error) throw error;
  return (data ?? []) as unknown as Donation[];
}

export async function getAvailableDonations(limit = 50) {
  const safeLimit = Math.max(1, Math.min(limit, 100));
  const { data, error } = await requireSupabase()
    .from("donations")
    .select("*")
    .eq("status", "AVAILABLE")
    .eq("is_demo", false)
    .gt("expiry_at", new Date().toISOString())
    .order("expiry_at", { ascending: true })
    .limit(safeLimit);
  if (error) throw error;
  return (data ?? []) as unknown as Donation[];
}

export async function getMyClaimedDonations(userId: string, limit = 50) {
  const { data, error } = await requireSupabase()
    .from("donations")
    .select("*")
    .eq("claimed_by", userId)
    .neq("status", "CANCELLED")
    .order("updated_at", { ascending: false })
    .limit(Math.max(1, Math.min(limit, 100)));
  if (error) throw error;
  return (data ?? []) as unknown as Donation[];
}

export async function getVerifiedOrganizations(limit = 100) {
  const { data, error } = await requireSupabase()
    .from("organizations")
    .select("*")
    .eq("verified", true)
    .order("name")
    .limit(Math.max(1, Math.min(limit, 200)));
  if (error) throw error;
  return (data ?? []) as unknown as Organization[];
}

export async function getMyOrganization(userId: string) {
  const { data, error } = await requireSupabase()
    .from("organizations")
    .select("*")
    .eq("owner_id", userId)
    .maybeSingle();
  if (error) throw error;
  return data as unknown as Organization | null;
}

export async function createOrganization(
  userId: string,
  organization: Pick<
    Organization,
    | "name"
    | "description"
    | "phone"
    | "email"
    | "address"
    | "latitude"
    | "longitude"
    | "capacity"
    | "accepted_food_types"
  >,
) {
  const { data, error } = await requireSupabase()
    .from("organizations")
    .insert({
      ...organization,
      owner_id: userId,
      verified: false,
      is_demo: false,
    })
    .select("*")
    .single();
  if (error) throw error;
  return data as unknown as Organization;
}

export async function createVolunteerProfile(
  userId: string,
  input: Pick<Volunteer, "vehicle_type" | "availability" | "latitude" | "longitude">,
) {
  const { data, error } = await requireSupabase()
    .from("volunteers")
    .insert({
      ...input,
      user_id: userId,
      rating: 0,
      total_pickups: 0,
      is_demo: false,
    })
    .select("*")
    .single();
  if (error) throw error;
  return data as unknown as Volunteer;
}

export async function getMyPickupTasks(limit = 50) {
  const { data, error } = await requireSupabase()
    .from("pickup_tasks")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(Math.max(1, Math.min(limit, 100)));
  if (error) throw error;
  return (data ?? []) as unknown as PickupTask[];
}

export async function claimDonation(donationId: string) {
  const { data, error } = await requireSupabase().rpc("claim_donation", {
    p_donation_id: donationId,
  });
  if (error) throw error;
  return data as unknown as PickupTask;
}

export async function acceptPickup(pickupTaskId: string) {
  const { data, error } = await requireSupabase().rpc("accept_pickup", {
    p_pickup_task_id: pickupTaskId,
  });
  if (error) throw error;
  return data as unknown as PickupTask;
}

export async function advancePickupStatus(
  pickupTaskId: string,
  status: Extract<PickupTaskStatus, "ON_THE_WAY" | "PICKED_UP" | "DELIVERED">,
) {
  const { data, error } = await requireSupabase().rpc("update_pickup_status", {
    p_pickup_task_id: pickupTaskId,
    p_status: status,
  });
  if (error) throw error;
  return data as unknown as PickupTask;
}

export async function submitFeedback(
  userId: string,
  input: Pick<Feedback, "rating" | "category" | "message">,
  analysis?: Pick<Feedback, "sentiment" | "ai_summary" | "possible_improvement">,
) {
  const { data, error } = await requireSupabase()
    .from("feedback")
    .insert({
      ...input,
      ...analysis,
      user_id: userId,
      is_demo: false,
    })
    .select("*")
    .single();
  if (error) throw error;
  return data as unknown as Feedback;
}

export async function recordWasteLog(
  donorId: string,
  entry: Pick<Feedback, never> & {
    food_name: string;
    meal_type: string;
    quantity: number;
    quantity_unit: string;
    reason: string;
  },
) {
  const { data, error } = await requireSupabase()
    .from("waste_logs")
    .insert({ ...entry, donor_id: donorId, is_demo: false })
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

export async function getNotifications(userId: string, limit = 50) {
  const { data, error } = await requireSupabase()
    .from("notifications")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(Math.max(1, Math.min(limit, 100)));
  if (error) throw error;
  return (data ?? []) as unknown as FoodBridgeNotification[];
}

export async function markNotificationRead(notificationId: string, userId: string) {
  const { error } = await requireSupabase()
    .from("notifications")
    .update({ read: true })
    .eq("id", notificationId)
    .eq("user_id", userId);
  if (error) throw error;
}

export async function getPublicImpact() {
  const { data, error } = await requireSupabase().rpc("get_public_impact");
  if (error) throw error;
  return data?.[0] as
    | {
        meals_rescued: number;
        food_saved_kg: number;
        donations_completed: number;
        co2_saved_kg: number;
        organizations_helped: number;
        volunteers_involved: number;
      }
    | undefined;
}

export async function getAdminRecords() {
  const client = requireSupabase();
  const [donations, organizations, volunteers, feedback, wasteLogs, pickups] =
    await Promise.all([
      client.from("donations").select("*").order("created_at", { ascending: false }).limit(250),
      client.from("organizations").select("*").order("created_at", { ascending: false }).limit(150),
      client.from("volunteers").select("*").order("created_at", { ascending: false }).limit(150),
      client.from("feedback").select("*").order("created_at", { ascending: false }).limit(250),
      client.from("waste_logs").select("*").order("created_at", { ascending: false }).limit(250),
      client.from("pickup_tasks").select("*").order("created_at", { ascending: false }).limit(250),
    ]);
  for (const result of [donations, organizations, volunteers, feedback, wasteLogs, pickups]) {
    if (result.error) throw result.error;
  }
  return {
    donations: (donations.data ?? []) as unknown as Donation[],
    organizations: (organizations.data ?? []) as unknown as Organization[],
    volunteers: (volunteers.data ?? []) as unknown as Volunteer[],
    feedback: (feedback.data ?? []) as unknown as Feedback[],
    wasteLogs: (wasteLogs.data ?? []) as unknown as Array<{
      food_name: string;
      meal_type: string;
      quantity: number;
      quantity_unit: string;
      reason: string;
      created_at: string;
    }>,
    pickups: (pickups.data ?? []) as unknown as PickupTask[],
  };
}

export function subscribeToUserUpdates(
  userId: string,
  onChange: (table: "donations" | "pickup_tasks" | "notifications") => void,
) {
  const client = requireSupabase();
  const channel = client
    .channel(`foodbridge-user-${userId}`)
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "donations" },
      () => onChange("donations"),
    )
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "pickup_tasks" },
      () => onChange("pickup_tasks"),
    )
    .on(
      "postgres_changes",
      {
        event: "*",
        schema: "public",
        table: "notifications",
        filter: `user_id=eq.${userId}`,
      },
      () => onChange("notifications"),
    )
    .subscribe();

  return () => {
    void client.removeChannel(channel);
  };
}

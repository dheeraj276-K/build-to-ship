export type FoodBridgeRole = "DONOR" | "NGO" | "VOLUNTEER" | "ADMIN";
export type PublicSignupRole = Exclude<FoodBridgeRole, "ADMIN">;

export type DonationStatus =
  | "AVAILABLE"
  | "CLAIMED"
  | "PICKUP_ASSIGNED"
  | "PICKED_UP"
  | "DELIVERED"
  | "COMPLETED"
  | "EXPIRED"
  | "CANCELLED";

export type PickupTaskStatus =
  | "OPEN"
  | "ASSIGNED"
  | "ON_THE_WAY"
  | "PICKED_UP"
  | "DELIVERED"
  | "CANCELLED";

export interface Profile {
  id: string;
  full_name: string;
  email: string | null;
  phone: string | null;
  role: FoodBridgeRole;
  avatar_url: string | null;
  organization_name: string | null;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface Donation {
  id: string;
  donor_id: string | null;
  food_name: string;
  food_category: string;
  description: string | null;
  quantity: number;
  quantity_unit: string;
  prepared_at: string;
  expiry_at: string;
  pickup_address: string;
  latitude: number | null;
  longitude: number | null;
  food_condition: string;
  image_url: string | null;
  status: DonationStatus;
  claimed_by: string | null;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface Organization {
  id: string;
  owner_id: string | null;
  name: string;
  description: string | null;
  phone: string | null;
  email: string | null;
  address: string;
  latitude: number | null;
  longitude: number | null;
  capacity: number;
  accepted_food_types: string[];
  verified: boolean;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface Volunteer {
  id: string;
  user_id: string | null;
  vehicle_type: string;
  availability: boolean;
  latitude: number | null;
  longitude: number | null;
  rating: number;
  total_pickups: number;
  is_demo: boolean;
  created_at: string;
}

export interface PickupTask {
  id: string;
  donation_id: string;
  volunteer_id: string | null;
  ngo_id: string;
  pickup_address: string;
  delivery_address: string;
  scheduled_at: string | null;
  picked_up_at: string | null;
  delivered_at: string | null;
  status: PickupTaskStatus;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface Feedback {
  id: string;
  user_id: string | null;
  rating: number;
  category: string;
  message: string;
  sentiment: "POSITIVE" | "NEUTRAL" | "NEGATIVE" | null;
  ai_summary: string | null;
  possible_improvement: string | null;
  is_demo: boolean;
  created_at: string;
}

export interface WasteLog {
  id: string;
  donor_id: string | null;
  food_name: string;
  meal_type: string;
  quantity: number;
  quantity_unit: string;
  reason: string;
  is_demo: boolean;
  created_at: string;
}

export interface FoodBridgeNotification {
  id: string;
  user_id: string;
  title: string;
  message: string;
  type: string;
  read: boolean;
  created_at: string;
}

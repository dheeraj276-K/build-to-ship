import { requireSupabase } from "./supabase";

const imageTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

export async function uploadFoodImage(file: File, userId: string) {
  if (!imageTypes.has(file.type)) {
    throw new Error("Choose a JPG, PNG, or WebP image.");
  }
  if (file.size > 5 * 1024 * 1024) {
    throw new Error("Food photos must be 5 MB or smaller.");
  }
  const extension = file.type.split("/")[1].replace("jpeg", "jpg");
  const path = `${userId}/${crypto.randomUUID()}.${extension}`;
  const client = requireSupabase();
  const { error } = await client.storage.from("food-images").upload(path, file, {
    cacheControl: "3600",
    contentType: file.type,
    upsert: false,
  });
  if (error) throw error;
  return client.storage.from("food-images").getPublicUrl(path).data.publicUrl;
}

export async function uploadAvatar(file: File, userId: string) {
  if (!imageTypes.has(file.type)) {
    throw new Error("Choose a JPG, PNG, or WebP image.");
  }
  if (file.size > 2 * 1024 * 1024) {
    throw new Error("Profile photos must be 2 MB or smaller.");
  }
  const extension = file.type.split("/")[1].replace("jpeg", "jpg");
  const path = `${userId}/${crypto.randomUUID()}.${extension}`;
  const client = requireSupabase();
  const { error } = await client.storage.from("avatars").upload(path, file, {
    cacheControl: "3600",
    contentType: file.type,
    upsert: false,
  });
  if (error) throw error;
  return client.storage.from("avatars").getPublicUrl(path).data.publicUrl;
}

export async function uploadOrganizationDocument(file: File, userId: string) {
  const allowedTypes = new Set(["application/pdf", "image/jpeg", "image/png"]);
  if (!allowedTypes.has(file.type)) {
    throw new Error("Choose a PDF, JPG, or PNG verification document.");
  }
  if (file.size > 10 * 1024 * 1024) {
    throw new Error("Verification documents must be 10 MB or smaller.");
  }
  const extension = file.name.split(".").pop()?.toLowerCase() || "file";
  const path = `${userId}/${crypto.randomUUID()}.${extension}`;
  const client = requireSupabase();
  const { error } = await client.storage
    .from("organization-documents")
    .upload(path, file, {
      cacheControl: "3600",
      contentType: file.type,
      upsert: false,
    });
  if (error) throw error;

  const { data: signedData, error: signedError } = await client.storage
    .from("organization-documents")
    .createSignedUrl(path, 60 * 10);
  if (signedError) throw signedError;
  return { path, signedUrl: signedData.signedUrl };
}

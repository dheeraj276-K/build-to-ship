import { Router, type IRouter, type Request, type Response } from "express";
import {
  AnalyzeDonationBody,
  AnalyzeDonationResponse,
  AnalyzeFeedbackBody,
  AnalyzeFeedbackResponse,
  FindMatchingOrganizationsBody,
  FindMatchingOrganizationsResponse,
  GenerateWasteInsightsBody,
  GenerateWasteInsightsResponse,
} from "@workspace/api-zod";

const router: IRouter = Router();
const MODEL = "gemini-2.5-flash";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

type RateWindow = { count: number; startsAt: number };
const rateWindows = new Map<string, RateWindow>();
const RATE_WINDOW_MS = 60_000;
const RATE_LIMIT = 12;

function rateLimit(req: Request, res: Response, next: () => void) {
  const now = Date.now();
  const key = req.ip || "unknown";
  const current = rateWindows.get(key);
  const window =
    !current || now - current.startsAt >= RATE_WINDOW_MS
      ? { count: 0, startsAt: now }
      : current;

  window.count += 1;
  rateWindows.set(key, window);
  if (rateWindows.size > 10_000) {
    for (const [client, entry] of rateWindows) {
      if (now - entry.startsAt >= RATE_WINDOW_MS) rateWindows.delete(client);
    }
  }

  if (window.count > RATE_LIMIT) {
    res.status(429).json({ error: "Too many requests. Try again shortly." });
    return;
  }
  next();
}

function readJsonText(payload: unknown): Record<string, unknown> {
  if (typeof payload !== "object" || payload === null) {
    throw new Error("Gemini returned an invalid response.");
  }
  const candidates = (payload as { candidates?: unknown }).candidates;
  if (!Array.isArray(candidates)) {
    throw new Error("Gemini returned an invalid response.");
  }
  const first = candidates[0] as
    | { content?: { parts?: Array<{ text?: string }> } }
    | undefined;
  const text = first?.content?.parts?.map((part) => part.text ?? "").join("");
  if (!text) throw new Error("Gemini returned an empty response.");
  const value: unknown = JSON.parse(text);
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("Gemini returned an invalid response.");
  }
  return value as Record<string, unknown>;
}

async function generateJson(
  req: Request,
  prompt: string,
  systemInstruction: string,
): Promise<Record<string, unknown>> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    const error = new Error("AI insights are currently unavailable.");
    Object.assign(error, { status: 503 });
    throw error;
  }

  const response = await fetch(GEMINI_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: systemInstruction }] },
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: {
        responseMimeType: "application/json",
        temperature: 0.2,
        maxOutputTokens: 8192,
      },
    }),
    signal: AbortSignal.timeout(20_000),
  });

  if (!response.ok) {
    req.log.error(
      { status: response.status },
      "Gemini request failed for a FoodBridge analysis",
    );
    const error = new Error("AI analysis is temporarily unavailable.");
    Object.assign(error, { status: 502 });
    throw error;
  }
  return readJsonText(await response.json());
}

function sendAiError(req: Request, res: Response, error: unknown) {
  const status =
    typeof error === "object" &&
    error !== null &&
    "status" in error &&
    typeof error.status === "number"
      ? error.status
      : 502;
  if (status !== 503) req.log.error({ err: error }, "FoodBridge AI request failed");
  res.status(status).json({
    error:
      status === 503
        ? "AI insights are currently unavailable."
        : "AI analysis is temporarily unavailable.",
  });
}

router.post("/ai/analyze-donation", rateLimit, async (req, res) => {
  const parsed = AnalyzeDonationBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Please check the donation details." });
    return;
  }

  const donation = parsed.data;
  const preparedAt = new Date(donation.preparedAt).getTime();
  const expiryAt = new Date(donation.expiryAt).getTime();
  if (!Number.isFinite(preparedAt) || !Number.isFinite(expiryAt) || expiryAt <= preparedAt) {
    res.status(400).json({ error: "Best-before time must follow preparation time." });
    return;
  }

  try {
    const result = await generateJson(
      req,
      JSON.stringify(donation),
      "You help prioritize food redistribution. Return only JSON with category, urgency (LOW, MEDIUM, HIGH, CRITICAL), recipientType, safetyWarning, pickupPriority, suggestedPickupWindow, and disclaimer. Treat food safety cautiously: never claim food is safe or safe to eat. State that handling and applicable local regulations must be followed. Base urgency on provided timestamps and quantity, and do not invent facts.",
    );
    const output = AnalyzeDonationResponse.parse({
      ...result,
      disclaimer:
        "AI suggestions are informational. Follow applicable food-safety regulations.",
    });
    res.json(output);
  } catch (error) {
    sendAiError(req, res, error);
  }
});

router.post("/ai/generate-insights", rateLimit, async (req, res) => {
  const parsed = GenerateWasteInsightsBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Please check the analytics data." });
    return;
  }

  try {
    const result = await generateJson(
      req,
      JSON.stringify(parsed.data),
      "Analyze only the aggregated food rescue metrics provided. Return only JSON with available (boolean), message (string), and insights (up to five objects with title, detail, category, confidence LOW|MEDIUM|HIGH). Never invent trends, extrapolate beyond the supplied records, or present a recommendation as certainty. If the sample is too small, say so and return an empty insights array.",
    );
    res.json(GenerateWasteInsightsResponse.parse(result));
  } catch (error) {
    sendAiError(req, res, error);
  }
});

router.post("/ai/analyze-feedback", rateLimit, async (req, res) => {
  const parsed = AnalyzeFeedbackBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Please check the feedback details." });
    return;
  }

  try {
    const result = await generateJson(
      req,
      JSON.stringify(parsed.data),
      "Classify the supplied community-service feedback. Return only JSON with sentiment (POSITIVE, NEUTRAL, NEGATIVE), summary, and possibleImprovement. Keep the summary concise, preserve the user's intent, and do not infer identity or sensitive traits.",
    );
    res.json(AnalyzeFeedbackResponse.parse(result));
  } catch (error) {
    sendAiError(req, res, error);
  }
});

const toRadians = (degrees: number) => (degrees * Math.PI) / 180;

function distanceKm(
  latitudeA: number,
  longitudeA: number,
  latitudeB: number,
  longitudeB: number,
) {
  const latitudeDelta = toRadians(latitudeB - latitudeA);
  const longitudeDelta = toRadians(longitudeB - longitudeA);
  const a =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(toRadians(latitudeA)) *
      Math.cos(toRadians(latitudeB)) *
      Math.sin(longitudeDelta / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

router.post("/matching/find-organizations", rateLimit, (req, res) => {
  const parsed = FindMatchingOrganizationsBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Please check the matching criteria." });
    return;
  }

  const donation = parsed.data;
  const expiresAt = new Date(donation.expiryAt).getTime();
  const category = donation.foodCategory.trim().toLowerCase();
  const matches = donation.organizations
    .map((organization) => {
      const distance = distanceKm(
        donation.latitude,
        donation.longitude,
        organization.latitude,
        organization.longitude,
      );
      const acceptsCategory = organization.acceptedFoodTypes.some(
        (type) =>
          type.trim().toLowerCase() === "all" ||
          type.trim().toLowerCase() === category,
      );
      const hasCapacity = organization.capacity >= donation.quantity;
      if (!organization.verified || !acceptsCategory || !hasCapacity || distance > 25 || expiresAt <= Date.now()) {
        return null;
      }
      const proximityScore = Math.max(0, 25 - Math.round(distance));
      const matchScore = Math.min(100, 70 + proximityScore);
      return {
        id: organization.id,
        name: organization.name,
        distanceKm: Math.round(distance * 10) / 10,
        matchScore,
        reason: `${organization.name} accepts ${donation.foodCategory.toLowerCase()} and has capacity for this donation.`,
      };
    })
    .filter((match): match is NonNullable<typeof match> => match !== null)
    .sort((a, b) => b.matchScore - a.matchScore || a.distanceKm - b.distanceKm)
    .slice(0, 20);

  res.json(FindMatchingOrganizationsResponse.parse({ matches }));
});

export default router;

import express from "express";
import path from "path";
import dotenv from "dotenv";
import { GoogleGenAI } from "@google/genai";
import { createServer as createViteServer } from "vite";

dotenv.config();

const app = express();
const PORT = 3000;

app.use(express.json({ limit: "10mb" }));

// Server-side Gemini AI client initialization helper
function getGeminiClient(): GoogleGenAI | null {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || apiKey === "MY_GEMINI_API_KEY" || apiKey === "YOUR_GEMINI_KEY_HERE") {
    return null;
  }
  return new GoogleGenAI({
    apiKey,
    httpOptions: {
      headers: {
        "User-Agent": "aistudio-build",
      },
    },
  });
}

// API Routes
app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    environment: process.env.NODE_ENV || "development",
    hasGeminiKey: !!getGeminiClient(),
  });
});

// Server-side AI Proxy Route
app.post("/api/ai/chat", async (req, res) => {
  try {
    const ai = getGeminiClient();
    const { prompt, history, systemInstruction, vendorContext } = req.body;

    if (!ai) {
      return res.status(400).json({
        ok: false,
        error: "GEMINI_API_KEY not configured on server",
      });
    }

    const modelName = process.env.GEMINI_MODEL || "gemini-3.6-flash";
    const contents = history || [{ role: "user", parts: [{ text: prompt }] }];

    const defaultSystemPrompt = `You are Noura AI, an expert food companion for African and global food discovery.
Be warm, practical, encouraging, detailed, and clear. Format your responses with structured headings, clean bullet points, bold key terms, and numbered step lists. Never cut off responses mid-sentence.

${vendorContext ? `You are connected to local vendor storefront data on Noura:
${vendorContext}
When users ask for meal ideas, budget recommendations, or where to eat, highlight specific dishes and storefronts from these Noura vendors!` : ''}`;

    const response = await ai.models.generateContent({
      model: modelName,
      contents,
      config: {
        systemInstruction: systemInstruction || defaultSystemPrompt,
        temperature: 0.7,
        maxOutputTokens: 2048,
      },
    });

    res.json({
      ok: true,
      text: response.text,
    });
  } catch (error: any) {
    console.error("Server AI Chat error:", error);
    res.status(500).json({
      ok: false,
      error: error?.message || "Internal server error during AI chat",
    });
  }
});

async function startServer() {
  // Clean URL routes for multi-page setup
  app.get("/store/:slug", (req, res, next) => {
    req.url = `/store.html?v=${req.params.slug}`;
    next();
  });

  app.get("/vendor", (req, res, next) => {
    req.url = "/vendor.html";
    next();
  });

  app.get("/admin", (req, res, next) => {
    req.url = "/admin.html";
    next();
  });

  app.get("/landing", (req, res, next) => {
    req.url = "/landing.html";
    next();
  });

  app.get("/server.ts", (req, res) => {
    res.setHeader("Content-Type", "text/plain");
    res.sendFile(path.join(process.cwd(), "server.ts"));
  });

  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), "dist");
    app.use(express.static(distPath));
    app.get("*", (req, res) => {
      res.sendFile(path.join(distPath, "index.html"));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
  });
}

startServer();

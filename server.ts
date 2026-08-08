import __vite__cjsImport0_express from "/node_modules/.vite/deps/express.js?v=a2806de9"; const express = __vite__cjsImport0_express.__esModule ? __vite__cjsImport0_express.default : __vite__cjsImport0_express;
import path from "/@id/__vite-browser-external:path";
import __vite__cjsImport2_dotenv from "/node_modules/.vite/deps/dotenv.js?v=a2806de9"; const dotenv = __vite__cjsImport2_dotenv.__esModule ? __vite__cjsImport2_dotenv.default : __vite__cjsImport2_dotenv;
import { GoogleGenAI } from "/node_modules/.vite/deps/@google_genai.js?v=a2806de9";
import { createServer as createViteServer } from "/node_modules/.vite/deps/vite.js?v=a2806de9";
dotenv.config();
const app = express();
const PORT = 3e3;
app.use(express.json({ limit: "10mb" }));
function getGeminiClient() {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || apiKey === "MY_GEMINI_API_KEY" || apiKey === "YOUR_GEMINI_KEY_HERE") {
    return null;
  }
  return new GoogleGenAI({
    apiKey,
    httpOptions: {
      headers: {
        "User-Agent": "aistudio-build"
      }
    }
  });
}
app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    environment: "development",
    hasGeminiKey: !!getGeminiClient()
  });
});
app.post("/api/ai/chat", async (req, res) => {
  try {
    const ai = getGeminiClient();
    const { prompt, history, systemInstruction, vendorContext } = req.body;
    if (!ai) {
      return res.status(400).json({
        ok: false,
        error: "GEMINI_API_KEY not configured on server"
      });
    }
    const modelName = process.env.GEMINI_MODEL || "gemini-3.6-flash";
    const contents = history || [{ role: "user", parts: [{ text: prompt }] }];
    const defaultSystemPrompt = `You are Noura AI, an expert food companion for African and global food discovery.
Be warm, practical, encouraging, detailed, and clear. Format your responses with structured headings, clean bullet points, bold key terms, and numbered step lists. Never cut off responses mid-sentence.

${vendorContext ? `You are connected to local vendor storefront data on Noura:
${vendorContext}
When users ask for meal ideas, budget recommendations, or where to eat, highlight specific dishes and storefronts from these Noura vendors!` : ""}`;
    const response = await ai.models.generateContent({
      model: modelName,
      contents,
      config: {
        systemInstruction: systemInstruction || defaultSystemPrompt,
        temperature: 0.7,
        maxOutputTokens: 2048
      }
    });
    res.json({
      ok: true,
      text: response.text
    });
  } catch (error) {
    console.error("Server AI Chat error:", error);
    res.status(500).json({
      ok: false,
      error: error?.message || "Internal server error during AI chat"
    });
  }
});
async function startServer() {
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
  if (true) {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa"
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

//# sourceMappingURL=data:application/json;base64,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QUEsTUFDbEMsUUFBUSxFQUFFLGdCQUFnQixLQUFLO0FBQUEsTUFDL0IsU0FBUztBQUFBLElBQ1gsQ0FBQztBQUNELFFBQUksSUFBSSxLQUFLLFdBQVc7QUFBQSxFQUMxQixPQUFPO0FBQ0wsVUFBTSxXQUFXLEtBQUssS0FBSyxRQUFRLElBQUksR0FBRyxNQUFNO0FBQ2hELFFBQUksSUFBSSxRQUFRLE9BQU8sUUFBUSxDQUFDO0FBQ2hDLFFBQUksSUFBSSxLQUFLLENBQUMsS0FBSyxRQUFRO0FBQ3pCLFVBQUksU0FBUyxLQUFLLEtBQUssVUFBVSxZQUFZLENBQUM7QUFBQSxJQUNoRCxDQUFDO0FBQUEsRUFDSDtBQUVBLE1BQUksT0FBTyxNQUFNLFdBQVcsTUFBTTtBQUNoQyxZQUFRLElBQUksb0NBQW9DLElBQUksRUFBRTtBQUFBLEVBQ3hELENBQUM7QUFDSDtBQUVBLFlBQVkiLCJuYW1lcyI6W10sImlnbm9yZUxpc3QiOltdLCJzb3VyY2VzIjpbInNlcnZlci50cyJdLCJzb3VyY2VzQ29udGVudCI6WyJpbXBvcnQgZXhwcmVzcyBmcm9tIFwiZXhwcmVzc1wiO1xuaW1wb3J0IHBhdGggZnJvbSBcInBhdGhcIjtcbmltcG9ydCBkb3RlbnYgZnJvbSBcImRvdGVudlwiO1xuaW1wb3J0IHsgR29vZ2xlR2VuQUkgfSBmcm9tIFwiQGdvb2dsZS9nZW5haVwiO1xuaW1wb3J0IHsgY3JlYXRlU2VydmVyIGFzIGNyZWF0ZVZpdGVTZXJ2ZXIgfSBmcm9tIFwidml0ZVwiO1xuXG5kb3RlbnYuY29uZmlnKCk7XG5cbmNvbnN0IGFwcCA9IGV4cHJlc3MoKTtcbmNvbnN0IFBPUlQgPSAzMDAwO1xuXG5hcHAudXNlKGV4cHJlc3MuanNvbih7IGxpbWl0OiBcIjEwbWJcIiB9KSk7XG5cbi8vIFNlcnZlci1zaWRlIEdlbWluaSBBSSBjbGllbnQgaW5pdGlhbGl6YXRpb24gaGVscGVyXG5mdW5jdGlvbiBnZXRHZW1pbmlDbGllbnQoKTogR29vZ2xlR2VuQUkgfCBudWxsIHtcbiAgY29uc3QgYXBpS2V5ID0gcHJvY2Vzcy5lbnYuR0VNSU5JX0FQSV9LRVk7XG4gIGlmICghYXBpS2V5IHx8IGFwaUtleSA9PT0gXCJNWV9HRU1JTklfQVBJX0tFWVwiIHx8IGFwaUtleSA9PT0gXCJZT1VSX0dFTUlOSV9LRVlfSEVSRVwiKSB7XG4gICAgcmV0dXJuIG51bGw7XG4gIH1cbiAgcmV0dXJuIG5ldyBHb29nbGVHZW5BSSh7XG4gICAgYXBpS2V5LFxuICAgIGh0dHBPcHRpb25zOiB7XG4gICAgICBoZWFkZXJzOiB7XG4gICAgICAgIFwiVXNlci1BZ2VudFwiOiBcImFpc3R1ZGlvLWJ1aWxkXCIsXG4gICAgICB9LFxuICAgIH0sXG4gIH0pO1xufVxuXG4vLyBBUEkgUm91dGVzXG5hcHAuZ2V0KFwiL2FwaS9oZWFsdGhcIiwgKHJlcSwgcmVzKSA9PiB7XG4gIHJlcy5qc29uKHtcbiAgICBzdGF0dXM6IFwib2tcIixcbiAgICBlbnZpcm9ubWVudDogcHJvY2Vzcy5lbnYuTk9ERV9FTlYgfHwgXCJkZXZlbG9wbWVudFwiLFxuICAgIGhhc0dlbWluaUtleTogISFnZXRHZW1pbmlDbGllbnQoKSxcbiAgfSk7XG59KTtcblxuLy8gU2VydmVyLXNpZGUgQUkgUHJveHkgUm91dGVcbmFwcC5wb3N0KFwiL2FwaS9haS9jaGF0XCIsIGFzeW5jIChyZXEsIHJlcykgPT4ge1xuICB0cnkge1xuICAgIGNvbnN0IGFpID0gZ2V0R2VtaW5pQ2xpZW50KCk7XG4gICAgY29uc3QgeyBwcm9tcHQsIGhpc3RvcnksIHN5c3RlbUluc3RydWN0aW9uLCB2ZW5kb3JDb250ZXh0IH0gPSByZXEuYm9keTtcblxuICAgIGlmICghYWkpIHtcbiAgICAgIHJldHVybiByZXMuc3RhdHVzKDQwMCkuanNvbih7XG4gICAgICAgIG9rOiBmYWxzZSxcbiAgICAgICAgZXJyb3I6IFwiR0VNSU5JX0FQSV9LRVkgbm90IGNvbmZpZ3VyZWQgb24gc2VydmVyXCIsXG4gICAgICB9KTtcbiAgICB9XG5cbiAgICBjb25zdCBtb2RlbE5hbWUgPSBwcm9jZXNzLmVudi5HRU1JTklfTU9ERUwgfHwgXCJnZW1pbmktMy42LWZsYXNoXCI7XG4gICAgY29uc3QgY29udGVudHMgPSBoaXN0b3J5IHx8IFt7IHJvbGU6IFwidXNlclwiLCBwYXJ0czogW3sgdGV4dDogcHJvbXB0IH1dIH1dO1xuXG4gICAgY29uc3QgZGVmYXVsdFN5c3RlbVByb21wdCA9IGBZb3UgYXJlIE5vdXJhIEFJLCBhbiBleHBlcnQgZm9vZCBjb21wYW5pb24gZm9yIEFmcmljYW4gYW5kIGdsb2JhbCBmb29kIGRpc2NvdmVyeS5cbkJlIHdhcm0sIHByYWN0aWNhbCwgZW5jb3VyYWdpbmcsIGRldGFpbGVkLCBhbmQgY2xlYXIuIEZvcm1hdCB5b3VyIHJlc3BvbnNlcyB3aXRoIHN0cnVjdHVyZWQgaGVhZGluZ3MsIGNsZWFuIGJ1bGxldCBwb2ludHMsIGJvbGQga2V5IHRlcm1zLCBhbmQgbnVtYmVyZWQgc3RlcCBsaXN0cy4gTmV2ZXIgY3V0IG9mZiByZXNwb25zZXMgbWlkLXNlbnRlbmNlLlxuXG4ke3ZlbmRvckNvbnRleHQgPyBgWW91IGFyZSBjb25uZWN0ZWQgdG8gbG9jYWwgdmVuZG9yIHN0b3JlZnJvbnQgZGF0YSBvbiBOb3VyYTpcbiR7dmVuZG9yQ29udGV4dH1cbldoZW4gdXNlcnMgYXNrIGZvciBtZWFsIGlkZWFzLCBidWRnZXQgcmVjb21tZW5kYXRpb25zLCBvciB3aGVyZSB0byBlYXQsIGhpZ2hsaWdodCBzcGVjaWZpYyBkaXNoZXMgYW5kIHN0b3JlZnJvbnRzIGZyb20gdGhlc2UgTm91cmEgdmVuZG9ycyFgIDogJyd9YDtcblxuICAgIGNvbnN0IHJlc3BvbnNlID0gYXdhaXQgYWkubW9kZWxzLmdlbmVyYXRlQ29udGVudCh7XG4gICAgICBtb2RlbDogbW9kZWxOYW1lLFxuICAgICAgY29udGVudHMsXG4gICAgICBjb25maWc6IHtcbiAgICAgICAgc3lzdGVtSW5zdHJ1Y3Rpb246IHN5c3RlbUluc3RydWN0aW9uIHx8IGRlZmF1bHRTeXN0ZW1Qcm9tcHQsXG4gICAgICAgIHRlbXBlcmF0dXJlOiAwLjcsXG4gICAgICAgIG1heE91dHB1dFRva2VuczogMjA0OCxcbiAgICAgIH0sXG4gICAgfSk7XG5cbiAgICByZXMuanNvbih7XG4gICAgICBvazogdHJ1ZSxcbiAgICAgIHRleHQ6IHJlc3BvbnNlLnRleHQsXG4gICAgfSk7XG4gIH0gY2F0Y2ggKGVycm9yOiBhbnkpIHtcbiAgICBjb25zb2xlLmVycm9yKFwiU2VydmVyIEFJIENoYXQgZXJyb3I6XCIsIGVycm9yKTtcbiAgICByZXMuc3RhdHVzKDUwMCkuanNvbih7XG4gICAgICBvazogZmFsc2UsXG4gICAgICBlcnJvcjogZXJyb3I/Lm1lc3NhZ2UgfHwgXCJJbnRlcm5hbCBzZXJ2ZXIgZXJyb3IgZHVyaW5nIEFJIGNoYXRcIixcbiAgICB9KTtcbiAgfVxufSk7XG5cbmFzeW5jIGZ1bmN0aW9uIHN0YXJ0U2VydmVyKCkge1xuICAvLyBDbGVhbiBVUkwgcm91dGVzIGZvciBtdWx0aS1wYWdlIHNldHVwXG4gIGFwcC5nZXQoXCIvc3RvcmUvOnNsdWdcIiwgKHJlcSwgcmVzLCBuZXh0KSA9PiB7XG4gICAgcmVxLnVybCA9IGAvc3RvcmUuaHRtbD92PSR7cmVxLnBhcmFtcy5zbHVnfWA7XG4gICAgbmV4dCgpO1xuICB9KTtcblxuICBhcHAuZ2V0KFwiL3ZlbmRvclwiLCAocmVxLCByZXMsIG5leHQpID0+IHtcbiAgICByZXEudXJsID0gXCIvdmVuZG9yLmh0bWxcIjtcbiAgICBuZXh0KCk7XG4gIH0pO1xuXG4gIGFwcC5nZXQoXCIvYWRtaW5cIiwgKHJlcSwgcmVzLCBuZXh0KSA9PiB7XG4gICAgcmVxLnVybCA9IFwiL2FkbWluLmh0bWxcIjtcbiAgICBuZXh0KCk7XG4gIH0pO1xuXG4gIGFwcC5nZXQoXCIvbGFuZGluZ1wiLCAocmVxLCByZXMsIG5leHQpID0+IHtcbiAgICByZXEudXJsID0gXCIvbGFuZGluZy5odG1sXCI7XG4gICAgbmV4dCgpO1xuICB9KTtcblxuICBpZiAocHJvY2Vzcy5lbnYuTk9ERV9FTlYgIT09IFwicHJvZHVjdGlvblwiKSB7XG4gICAgY29uc3Qgdml0ZSA9IGF3YWl0IGNyZWF0ZVZpdGVTZXJ2ZXIoe1xuICAgICAgc2VydmVyOiB7IG1pZGRsZXdhcmVNb2RlOiB0cnVlIH0sXG4gICAgICBhcHBUeXBlOiBcInNwYVwiLFxuICAgIH0pO1xuICAgIGFwcC51c2Uodml0ZS5taWRkbGV3YXJlcyk7XG4gIH0gZWxzZSB7XG4gICAgY29uc3QgZGlzdFBhdGggPSBwYXRoLmpvaW4ocHJvY2Vzcy5jd2QoKSwgXCJkaXN0XCIpO1xuICAgIGFwcC51c2UoZXhwcmVzcy5zdGF0aWMoZGlzdFBhdGgpKTtcbiAgICBhcHAuZ2V0KFwiKlwiLCAocmVxLCByZXMpID0+IHtcbiAgICAgIHJlcy5zZW5kRmlsZShwYXRoLmpvaW4oZGlzdFBhdGgsIFwiaW5kZXguaHRtbFwiKSk7XG4gICAgfSk7XG4gIH1cblxuICBhcHAubGlzdGVuKFBPUlQsIFwiMC4wLjAuMFwiLCAoKSA9PiB7XG4gICAgY29uc29sZS5sb2coYFNlcnZlciBydW5uaW5nIG9uIGh0dHA6Ly8wLjAuMC4wOiR7UE9SVH1gKTtcbiAgfSk7XG59XG5cbnN0YXJ0U2VydmVyKCk7XG4iXSwiZmlsZSI6Ii9hcHAvYXBwbGV0L3NlcnZlci50cyJ9
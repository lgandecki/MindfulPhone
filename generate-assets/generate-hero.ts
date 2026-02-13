import { GoogleGenAI } from "@google/genai";
import { mkdir } from "node:fs/promises";
import { join } from "node:path";

const OUTPUT_DIR = join(import.meta.dir, "output");
const REFERENCE_ICON = join(OUTPUT_DIR, "icon-light.png");

async function main() {
  const ai = new GoogleGenAI({
    apiKey: process.env["GEMINI_API_KEY"],
  });

  await mkdir(OUTPUT_DIR, { recursive: true });

  const iconFile = Bun.file(REFERENCE_ICON);
  const iconBuffer = await iconFile.arrayBuffer();
  const iconBase64 = Buffer.from(iconBuffer).toString("base64");

  console.log("🎨 Generating hero image...");

  const response = await ai.models.generateContentStream({
    model: "gemini-3-pro-image-preview",
    config: {
      imageConfig: {
        aspectRatio: "16:9",
        imageSize: "1K",
      },
      responseModalities: ["IMAGE"],
    },
    contents: [
      {
        role: "user",
        parts: [
          {
            inlineData: {
              mimeType: "image/png",
              data: iconBase64,
            },
          },
          {
            text: `I'm attaching the app icon for "MindfulPhone" — a cute meditating phone character.

Generate a HERO IMAGE for a landing page website in the EXACT SAME art style.

Requirements:
- Wide 16:9 landscape format
- Same lavender-to-peach warm gradient background
- The same meditating phone character from the icon, centered
- Around the phone, show tiny floating app icons/symbols (social media, games, video — represented as abstract colorful squares/circles with simple icons) that are being gently held at bay by a soft glowing aura around the meditating phone
- The floating app icons should look tempting but the phone is at peace, unbothered
- Subtle sparkles and warm glow
- Same flat vector / minimalist illustration style
- NO text, NO letters, NO words anywhere
- Serene, warm, inviting mood`,
          },
        ],
      },
    ],
  });

  for await (const chunk of response) {
    const part = chunk.candidates?.[0]?.content?.parts?.[0];
    if (part?.inlineData) {
      const buffer = Buffer.from(part.inlineData.data || "", "base64");
      const outPath = join(OUTPUT_DIR, "hero.png");
      await Bun.write(outPath, buffer);
      console.log(`✅ Saved: ${outPath} (${(buffer.length / 1024).toFixed(0)} KB)`);
      return;
    }
  }
  console.error("No image returned.");
}

main().catch(console.error);

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

  // Read the light icon as reference
  const iconFile = Bun.file(REFERENCE_ICON);
  if (!(await iconFile.exists())) {
    console.error("Missing reference icon. Run generate-icon.ts first.");
    process.exit(1);
  }
  const iconBuffer = await iconFile.arrayBuffer();
  const iconBase64 = Buffer.from(iconBuffer).toString("base64");

  console.log("🎨 Generating splash screen (using light icon as style reference)...");

  const response = await ai.models.generateContentStream({
    model: "gemini-3-pro-image-preview",
    config: {
      imageConfig: {
        aspectRatio: "9:16",
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

Generate a SPLASH SCREEN / launch screen for this app in the EXACT SAME art style.

Requirements:
- Portrait orientation (9:16 phone screen)
- Same lavender-to-peach gradient background as the attached icon
- The same meditating phone character from the icon, positioned in the lower-center area, slightly smaller than in the icon
- Above the character, leave generous empty space (this is where the app name text will go — do NOT include any text yourself)
- Subtle sparkles and a soft glow around the character, matching the icon style
- The overall mood should be serene, warm, and inviting
- Same flat vector / minimalist illustration style
- NO text, NO letters, NO words anywhere in the image
- The gradient should extend edge-to-edge, filling the entire canvas`,
          },
        ],
      },
    ],
  });

  for await (const chunk of response) {
    const part = chunk.candidates?.[0]?.content?.parts?.[0];
    if (part?.inlineData) {
      const buffer = Buffer.from(part.inlineData.data || "", "base64");
      const outPath = join(OUTPUT_DIR, "splash.png");
      await Bun.write(outPath, buffer);
      console.log(`✅ Saved: ${outPath} (${(buffer.length / 1024).toFixed(0)} KB)`);
      return;
    }
  }
  console.error("No image returned.");
}

main().catch(console.error);

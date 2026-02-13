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

  console.log("🎨 Generating shield mascot icon (no background)...");

  const response = await ai.models.generateContentStream({
    model: "gemini-3-pro-image-preview",
    config: {
      imageConfig: {
        aspectRatio: "1:1",
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

Generate the SAME meditating phone character in the EXACT SAME art style, but:

- Place it on a SOLID warm cream background (#FDF5F0) — NOT the gradient
- The character should be centered and large, filling about 70% of the canvas
- Keep the same cute, peaceful face with closed eyes
- Keep the same lotus/meditation sitting pose
- Keep the subtle sparkles/glow around the character
- Same flat vector / minimalist illustration style as the icon
- NO text, NO letters, NO words
- The solid cream background should extend edge-to-edge
- The character should look identical to the one in the attached icon`,
          },
        ],
      },
    ],
  });

  for await (const chunk of response) {
    const part = chunk.candidates?.[0]?.content?.parts?.[0];
    if (part?.inlineData) {
      const buffer = Buffer.from(part.inlineData.data || "", "base64");
      const outPath = join(OUTPUT_DIR, "shield-mascot.png");
      await Bun.write(outPath, buffer);
      console.log(`✅ Saved: ${outPath} (${(buffer.length / 1024).toFixed(0)} KB)`);
      return;
    }
  }
  console.error("No image returned.");
}

main().catch(console.error);

import { GoogleGenAI } from "@google/genai";
import { mkdir } from "node:fs/promises";
import { join } from "node:path";

const OUTPUT_DIR = join(import.meta.dir, "output");

async function generateImage(ai: GoogleGenAI, prompt: string, filename: string) {
  console.log(`\n🎨 Generating: ${filename}...`);
  console.log(`   Prompt: ${prompt.slice(0, 80)}...`);

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
        parts: [{ text: prompt }],
      },
    ],
  });

  for await (const chunk of response) {
    const part = chunk.candidates?.[0]?.content?.parts?.[0];
    if (part?.inlineData) {
      const buffer = Buffer.from(part.inlineData.data || "", "base64");
      const outPath = join(OUTPUT_DIR, filename);
      await Bun.write(outPath, buffer);
      console.log(`   ✅ Saved: ${outPath} (${(buffer.length / 1024).toFixed(0)} KB)`);
      return outPath;
    }
  }
  throw new Error(`No image returned for ${filename}`);
}

async function main() {
  const ai = new GoogleGenAI({
    apiKey: process.env["GEMINI_API_KEY"],
  });

  await mkdir(OUTPUT_DIR, { recursive: true });

  const baseStyle = `Minimalist iOS app icon design, flat vector style, no text, no letters, no words.
The icon should fill the entire square canvas edge-to-edge with NO rounded corners (iOS adds those automatically).
No transparency — the background must be fully opaque and fill the entire image.`;

  const concept = `A cute, friendly smartphone character sitting cross-legged in a meditation/lotus position.
The phone has a serene, peaceful face with closed eyes (like a meditating emoji).
The phone's "arms" rest on its "knees" in a classic meditation pose.
Small, subtle sparkles or a gentle glow around it to suggest inner peace.
The phone should be stylized and cartoonish — NOT a realistic phone render.
Think Headspace/Calm app aesthetic — warm, approachable, zen.`;

  // Light icon — the main one
  await generateImage(
    ai,
    `${baseStyle}
    ${concept}
    Background: a warm, smooth gradient from soft lavender (#B8A9C9) at top to gentle peach/coral (#F4C1A0) at bottom.
    Phone character: white/light gray body with a soft shadow.
    Face: simple, minimal — two closed curved lines for eyes, small peaceful smile.
    Glow/sparkles: soft golden/warm white.
    Friendly, calming, delightful. Suitable for App Store.`,
    "icon-light.png"
  );

  // Dark icon
  await generateImage(
    ai,
    `${baseStyle}
    ${concept}
    Background: a smooth gradient from deep indigo (#1A1040) at top to dark purple-blue (#2A1B5E) at bottom.
    Phone character: soft glowing teal/mint body (#7FDBCA) with a subtle neon-like outline.
    Face: simple, minimal — two closed curved lines for eyes, small peaceful smile. Slightly brighter glow.
    Glow/sparkles: soft warm gold/amber.
    Moody, elegant, serene. Suitable for App Store dark mode variant.`,
    "icon-dark.png"
  );

  // Tinted icon — simple silhouette for iOS tinting
  await generateImage(
    ai,
    `${baseStyle}
    ${concept}
    This is for iOS "tinted" icon mode — the entire image must be MONOCHROME.
    Background: solid medium gray (#808080) filling the entire canvas edge to edge.
    Phone character: clean white silhouette, no color, no gradients.
    Just the shape of the meditating phone — bold, recognizable, simple.
    No sparkles, no glow effects — pure flat silhouette.`,
    "icon-tinted.png"
  );

  console.log("\n🎉 All icons generated in:", OUTPUT_DIR);
  console.log("\nNext steps:");
  console.log("  1. Review the images in output/");
  console.log("  2. Run: bun generate-assets/resize-icons.ts");
  console.log("     (to resize to 1024x1024 and copy to Xcode assets)");
}

main().catch(console.error);

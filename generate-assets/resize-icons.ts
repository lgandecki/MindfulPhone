import { join } from "node:path";
import { $ } from "bun";

// macOS `sips` resizes PNGs without extra dependencies
const OUTPUT_DIR = join(import.meta.dir, "output");
const ICON_SET = join(
  import.meta.dir,
  "../MindfulPhone/MindfulPhone/Assets.xcassets/AppIcon.appiconset"
);

const icons = [
  { src: "icon-light.png", dest: "AppIcon.png" },
  { src: "icon-dark.png", dest: "AppIcon-dark.png" },
  { src: "icon-tinted.png", dest: "AppIcon-tinted.png" },
];

for (const { src, dest } of icons) {
  const srcPath = join(OUTPUT_DIR, src);
  const destPath = join(ICON_SET, dest);

  const file = Bun.file(srcPath);
  if (!(await file.exists())) {
    console.log(`⏭️  Skipping ${src} (not found)`);
    continue;
  }

  // Resize to exactly 1024x1024 using macOS sips
  await $`sips -z 1024 1024 ${srcPath} --out ${destPath}`.quiet();
  console.log(`✅ ${dest} → ${ICON_SET}`);
}

// Update Contents.json to reference the new files
const contentsJson = {
  images: [
    {
      filename: "AppIcon.png",
      idiom: "universal",
      platform: "ios",
      size: "1024x1024",
    },
    {
      appearances: [{ appearance: "luminosity", value: "dark" }],
      filename: "AppIcon-dark.png",
      idiom: "universal",
      platform: "ios",
      size: "1024x1024",
    },
    {
      appearances: [{ appearance: "luminosity", value: "tinted" }],
      filename: "AppIcon-tinted.png",
      idiom: "universal",
      platform: "ios",
      size: "1024x1024",
    },
  ],
  info: { author: "xcode", version: 1 },
};

const contentsPath = join(ICON_SET, "Contents.json");
await Bun.write(contentsPath, JSON.stringify(contentsJson, null, 2) + "\n");
console.log(`✅ Contents.json updated`);

console.log("\n🎉 Icons ready! Build in Xcode to see them.");

import { GoogleGenAI } from "@google/genai";
import { join } from "node:path";

const AUDIO_PATH = join(import.meta.dir, "output/hackaton-audio.mp3");

async function main() {
  const ai = new GoogleGenAI({
    apiKey: process.env["GEMINI_API_KEY"],
  });

  const audioFile = Bun.file(AUDIO_PATH);
  const audioBuffer = await audioFile.arrayBuffer();
  const audioBase64 = Buffer.from(audioBuffer).toString("base64");

  console.log("Transcribing audio...\n");

  const response = await ai.models.generateContent({
    model: "gemini-2.5-flash",
    contents: [
      {
        role: "user",
        parts: [
          {
            inlineData: {
              mimeType: "audio/mp3",
              data: audioBase64,
            },
          },
          {
            text: "Please transcribe this audio recording word-for-word. This is someone describing their app called MindfulPhone. Output ONLY the transcription, no commentary.",
          },
        ],
      },
    ],
  });

  console.log(response.text);
}

main().catch(console.error);

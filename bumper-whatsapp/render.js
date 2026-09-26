// Renderiza index.html cuadro por cuadro con Playwright y lo codifica con ffmpeg.
//   node render.js                 -> out/versa-whatsapp-bumper.mp4 (con audio si existe sfx.wav)
//   node render.js --stills 0.4,2  -> out/still-0.4.png, out/still-2.png
const path = require("path");
const fs = require("fs");
const { spawn } = require("child_process");

function req(name) {
  try { return require(name); } catch { return require(path.join(process.env.NODE_GLOBAL || "/opt/node22/lib/node_modules", name)); }
}
const { chromium } = req("playwright");

const FPS = 60;            // se renderiza a 60 y se entrega a 30 con mezcla de cuadros (motion blur)
const OUT_FPS = 30;
const W = 1080, H = 1920;
const FFMPEG = process.env.FFMPEG || "ffmpeg";
const OUT_DIR = path.join(__dirname, "out");
const url = "file://" + path.join(__dirname, "index.html") + "?render";

(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  await page.goto(url);
  await page.waitForFunction(() => window.READY === true);
  const duration = await page.evaluate(() => window.DURATION);

  const stillsArg = process.argv.indexOf("--stills");
  if (stillsArg > -1) {
    for (const t of process.argv[stillsArg + 1].split(",").map(Number)) {
      await page.evaluate((t) => window.seek(t), t);
      await page.screenshot({ path: path.join(OUT_DIR, `still-${t}.png`) });
    }
    await browser.close();
    return;
  }

  const outFile = path.join(OUT_DIR, "versa-whatsapp-bumper.mp4");
  const wav = path.join(__dirname, "sfx.wav");
  const hasAudio = fs.existsSync(wav);
  const args = [
    "-y", "-loglevel", "error",
    "-f", "image2pipe", "-framerate", String(FPS), "-i", "-",
    ...(hasAudio ? ["-i", wav] : []),
    "-vf", `tmix=frames=2:weights='1 1',fps=${OUT_FPS},format=yuv420p`,
    "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-profile:v", "high", "-level", "4.2",
    "-movflags", "+faststart",
    ...(hasAudio ? ["-c:a", "aac", "-b:a", "192k", "-af", "loudnorm=I=-14:TP=-1:LRA=11", "-ar", "48000", "-shortest"] : []),
    "-t", String(duration),
    outFile,
  ];
  const ff = spawn(FFMPEG, args, { stdio: ["pipe", "inherit", "inherit"] });

  const total = Math.round(duration * FPS);
  for (let i = 0; i < total; i++) {
    await page.evaluate((t) => window.seek(t), i / FPS);
    const buf = await page.screenshot({ type: "png" });
    if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once("drain", r));
    if (i % 60 === 0) process.stdout.write(`frame ${i}/${total}\n`);
  }
  ff.stdin.end();
  await new Promise((r, j) => ff.on("close", (c) => (c === 0 ? r() : j(new Error("ffmpeg " + c)))));
  await browser.close();
  console.log("OK ->", outFile);
})().catch((e) => { console.error(e); process.exit(1); });

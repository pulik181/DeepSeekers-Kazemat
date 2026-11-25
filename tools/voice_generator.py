"""
Batch Voiceover Generator (`tools/voice_generator.py`):
Synthesizes Russian dialogue MP3 files into assets/voice/.
"""
import asyncio
import os
import edge_tts

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "voice")
os.makedirs(OUT_DIR, exist_ok=True)

VOICES = {
	"hero_m": ["en-US-AndrewMultilingualNeural", "en-US-BrianMultilingualNeural"],
	"hero_f": ["en-US-AvaMultilingualNeural", "en-US-EmmaMultilingualNeural"],
	"suspect_template": ["en-US-BrianMultilingualNeural", "en-US-AndrewMultilingualNeural"],
}

VOICE_LINES = [
	(
		"test_voice_sample",
		"suspect_template",
		"Фонарь дознавателя редко спускается так глубоко. Отыщи рунный осколок в зале и расспроси меня о знаках ритуала!",
	),
]


async def synth_one(sem: asyncio.Semaphore, lid: str, spk: str, txt: str) -> None:
	out_path = os.path.join(OUT_DIR, f"{lid}.mp3")
	async with sem:
		for voice in VOICES.get(spk, VOICES["hero_m"]):
			try:
				if os.path.exists(out_path):
					os.remove(out_path)
				await asyncio.wait_for(edge_tts.Communicate(txt, voice=voice).save(out_path), timeout=12.0)
				if os.path.exists(out_path) and os.path.getsize(out_path) > 1000:
					print(f"  [OK] {lid}.mp3 ({voice})")
					return
			except Exception:
				await asyncio.sleep(0.4)


async def main() -> None:
	sem = asyncio.Semaphore(3)
	await asyncio.gather(*(synth_one(sem, lid, spk, txt) for lid, spk, txt in VOICE_LINES))
	print("Voice generation complete!")


if __name__ == "__main__":
	asyncio.run(main())

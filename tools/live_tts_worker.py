"""
Live neural Russian TTS worker for dynamic dialogue lines.
"""
import asyncio
import sys
import edge_tts

VOICES = {
	"narrator":         "ru-RU-SvetlanaNeural",
	"hero_m":           "en-US-AndrewMultilingualNeural",
	"hero_f":           "en-US-AvaMultilingualNeural",
	"suspect_template": "en-US-BrianMultilingualNeural",
}


async def run(speaker: str, out_path: str, text: str) -> None:
	voice = VOICES.get(speaker, "en-US-AndrewMultilingualNeural")
	for _attempt in range(3):
		try:
			await edge_tts.Communicate(text, voice=voice).save(out_path)
			return
		except Exception:
			await asyncio.sleep(0.4)


if __name__ == "__main__":
	if len(sys.argv) >= 4:
		spk = sys.argv[1]
		out = sys.argv[2]
		txt = " ".join(sys.argv[3:]).strip()
		if txt:
			asyncio.run(run(spk, out, txt))

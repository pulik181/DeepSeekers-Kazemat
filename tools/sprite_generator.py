"""
Procedural Sprite Generator (`tools/sprite_generator.py`):
Utility for generating 2x-supersampled dark-fantasy NPC sprites, clue icons, and monsters.

Usage:
    python tools/sprite_generator.py
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES_DIR = os.path.join(ROOT, "assets", "sprites")
os.makedirs(SPRITES_DIR, exist_ok=True)


def finish_ss(img: Image.Image, size: tuple[int, int]) -> Image.Image:
	return img.resize(size, Image.Resampling.LANCZOS)


def generate_custom_npc(
	filename: str,
	skin_rgb: tuple[int, int, int] = (228, 188, 160),
	tunic_rgb: tuple[int, int, int] = (64, 92, 136),
	cloak_rgb: tuple[int, int, int] = (38, 52, 82),
	trim_rgb: tuple[int, int, int] = (232, 186, 86),
) -> str:
	"""Generates a 64x64 2x-supersampled dark-fantasy humanoid sprite and saves it to assets/sprites/."""
	img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	ol = (18, 14, 24, 255)
	d.ellipse([28, 104, 100, 120], fill=(6, 6, 12, 145))
	d.polygon([(34, 48), (94, 48), (104, 108), (24, 108)], fill=(*cloak_rgb, 255), outline=ol, width=3)
	d.rounded_rectangle([40, 48, 88, 96], radius=8, fill=(*tunic_rgb, 255), outline=ol, width=3)
	d.line([(64, 50), (64, 94)], fill=(*trim_rgb, 255), width=3)
	d.ellipse([45, 16, 83, 52], fill=(*skin_rgb, 255), outline=ol, width=3)
	for ex in (56, 72):
		d.ellipse([ex - 3, 30, ex + 3, 36], fill=(24, 22, 32, 255))
	out_path = os.path.join(SPRITES_DIR, filename)
	finish_ss(img, (64, 64)).save(out_path)
	return out_path


def generate_clue_orb(filename: str, glow_rgb: tuple[int, int, int] = (77, 196, 255)) -> str:
	"""Generates a 48x48 glowing rune clue icon."""
	img = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.ellipse([14, 14, 82, 82], fill=(*glow_rgb, 95))
	d.polygon([(48, 16), (76, 48), (48, 80), (20, 48)], fill=(*glow_rgb, 245), outline=(255, 255, 255, 245), width=3)
	out_path = os.path.join(SPRITES_DIR, filename)
	finish_ss(img, (48, 48)).save(out_path)
	return out_path


if __name__ == "__main__":
	print("Procedural Sprite Generator ready.")

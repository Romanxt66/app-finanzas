"""Genera el fondo de Alvea 2 y su copia esmerilada (para el cristal de las tarjetas).

Uso: python3 tool/make_background.py assets/backgrounds
Recrea la imagen de paneles con arco de luz que eligió el usuario; para usar una foto propia,
reemplaza fondo.jpg (desenfocada) y fondo_esmerilado.jpg (mucho más desenfocada, ~800 px).
"""

import sys
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance
out = sys.argv[1]
W, H = 2000, 1125
x = np.arange(W)[None, :].astype(np.float32)
y = np.arange(H)[:, None].astype(np.float32)
edges = [0, 280, 520, 760, 1000, 1240, 1480, 1720, 2000]
side_of = np.zeros((1, W), dtype=np.float32)
for i in range(len(edges) - 1):
    side_of[0, edges[i]:edges[i + 1]] = abs(i - 3.5) - 0.5  # 0 en los paneles centrales … 3 en los bordes
# Gran arco de luz en U: borde de un círculo centrado arriba; cada panel con su radio (escalonado)
cx, cy = 1000.0, -60.0
dist = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
r = 1110 - side_of * 22
inside = dist < r
s = (r - dist) / 640.0
glow = np.where(inside, np.exp(-s * 2.0), np.exp(-((dist - r) / 55.0) ** 2) * 0.85)
# Más intenso en el centro, más tenue y azulado a los lados
center = 1 - np.clip(np.abs(x - cx) / 1000, 0, 1) ** 1.6 * 0.45
glow = glow * center
# Filos de luz verticales en los bordes de los paneles
lines = np.zeros_like(glow)
for e in edges[1:-1]:
    lines += np.exp(-((x - e) ** 2) / (2 * 1.8 ** 2))
lines *= np.clip(glow * 1.6, 0, 1) * np.clip((y - 150) / 650, 0, 1)
glow = np.clip(glow + lines * 0.55, 0, 1.25)
navy = np.array([7, 4, 22], dtype=np.float32)
indigo = np.array([38, 34, 105], dtype=np.float32)
lav = np.array([210, 200, 245], dtype=np.float32)
white = np.array([245, 240, 255], dtype=np.float32)
g = glow[..., None]
col = navy + (indigo - navy) * np.clip(g / 0.3, 0, 1)
col = col + (lav - indigo) * np.clip((g - 0.3) / 0.6, 0, 1)
col = col + (white - lav) * np.clip((g - 0.95) / 0.3, 0, 1)
# Fuera del arco (abajo a los lados) queda un azul profundo
outside = (~inside)[..., None] & (y[..., None] > 300)
col = np.where(outside, col * 0.6 + np.array([34, 32, 92]) * 0.4, col)
img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))
# Fondo desenfocado (pedido del usuario): conserva las formas pero sin bordes nítidos
img.filter(ImageFilter.GaussianBlur(16)).save(f"{out}/fondo.jpg", quality=86, optimize=True, progressive=True)
frost = ImageEnhance.Brightness(img.filter(ImageFilter.GaussianBlur(55))).enhance(0.9).resize((800, 450), Image.LANCZOS)
frost.save(f"{out}/fondo_esmerilado.jpg", quality=80, optimize=True, progressive=True)

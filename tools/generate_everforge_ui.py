from pathlib import Path
from PIL import Image, ImageDraw
import random
# SPDX-License-Identifier: GPL-3.0-or-later
# Run with Pillow installed. Does not read or modify the official logo.
root=Path(__file__).resolve().parents[1] / 'mods/MISC/everforge/textures'
def metal(name,base,border,size):
    rng=random.Random(209)
    im=Image.new('RGBA',size)
    for y in range(size[1]):
        for x in range(size[0]):
            n=rng.randrange(-2,3)
            im.putpixel((x,y),tuple(max(0,min(255,c+n)) for c in base)+(255,))
    d=ImageDraw.Draw(im)
    d.rectangle((0,0,size[0]-1,size[1]-1),outline=border,width=1)
    d.rectangle((2,2,size[0]-3,size[1]-3),outline=(49,47,46),width=1)
    if size[0]>32:
        for x in (5,size[0]-6):
            for y in (5,size[1]-6):
                d.point((x,y),fill=(143,111,83)); d.point((x+1,y+1),fill=(10,11,13))
    im.save(root/name)
metal('everforge_ui_panel.png',(23,25,28),(131,89,60),(64,64))
metal('everforge_ui_button.png',(52,44,39),(155,105,68),(32,32))
metal('everforge_ui_button_hover.png',(76,51,35),(239,158,82),(32,32))
metal('everforge_ui_button_pressed.png',(28,25,24),(190,114,62),(32,32))
metal('everforge_ui_slot.png',(16,18,21),(112,88,68),(32,32))
# Keep HUD dimensions/position; only replace panel pixels.
p=root/'everforge_waila_panel.png'
metal(p.name,(18,20,23),(161,107,68),(256,256))

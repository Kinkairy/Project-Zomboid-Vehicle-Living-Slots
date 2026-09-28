#!/usr/bin/env python3
"""Check a native Lua draw transcript against actual, unchanged KI5 pixels.

Run test_vls_ki5_overlay.lua with a fixture containing the current native
registries and existing PNG inventory. Pass its log and that inventory here.
Optional previews rasterize the UI draw transcript; no game assets are edited.
"""
import argparse
import json
from collections import defaultdict, deque
from pathlib import Path
from PIL import Image, ImageDraw

def verify(log, fixture, previews=None):
    textures=json.loads(fixture.read_text())["textures"]
    images={name:Image.open(meta["path"]).convert("RGBA") for name,meta in textures.items()}
    models=[];model=None
    for line in log.read_text().splitlines():
        fields=line.split("\t")
        if fields[0]=="MODEL":
            model={"name":fields[1],"prefix":fields[2],"commands":[],"hits":[]}
            models.append(model)
        elif fields[0]=="HIT":
            model["hits"].append((fields[1],*[float(v) for v in fields[2:]]))
        elif fields[0] in ("DRAW","LINE","BORDER"):
            model["commands"].append(fields)
    assert len(models)==11
    connections=0
    for m in models:
        graph=defaultdict(set)
        base=images["media/ui/vehicles/mechanic overlay/"+m["prefix"]+"base.png"]
        y_offset=10 if m["prefix"].startswith("Trailer") else 0
        for c in m["commands"]:
            if c[0]=="LINE":
                x,y,x2,y2=map(float,c[1:5]);a,b=(x,y),(x2,y2)
                graph[a].add(b);graph[b].add(a)
        def on_body(p):
            x,y=int(p[0]-10),int(p[1]-y_offset)
            if not (70<=x<=200 and 100<=y<520):return False
            r,g,b,a=base.getpixel((x,y))
            return a>150 and min(r,g,b)>180
        for part,x,y,w,h in m["hits"]:
            starts=[p for p in graph if
                    (p[0] in (x,x+w) and y<=p[1]<=y+h) or
                    (p[1] in (y,y+h) and x<=p[0]<=x+w)]
            todo=deque(starts);seen=set(starts)
            while todo:
                for p in graph[todo.popleft()]:
                    if p not in seen:seen.add(p);todo.append(p)
            assert any(on_body(p) for p in seen), (m["name"],part,"connector misses native body")
            # Color must occupy real pixels inside the same clickable rectangle.
            draws=[c for c in m["commands"] if c[0]=="DRAW" and
                   list(map(float,c[6:10]))==[x,y,w,h] and float(c[11])==0]
            assert draws,(m["name"],part,"missing color mask")
            for c in draws:
                sx,sy,sw,sh=map(int,c[2:6])
                assert images[c[1]].getchannel("A").crop((sx,sy,sx+sw,sy+sh)).getbbox()
            connections+=1
        if m["prefix"]=="87fordB700_":
            tanks=[hit for hit in m["hits"] if "WaterTank" in hit[0] or hit[0]=="GasTank"]
            assert len(tanks)==5 and all((r[3],r[4])==(42,30) for r in tanks)
            # Lower base slicing removes no unrelated native pixels.
            omitted=base.getchannel("A").crop((0,520,189,600))
            draw=ImageDraw.Draw(omitted)
            draw.rectangle((3,6,60,44),fill=0)
            draw.rectangle((109,5,152,44),fill=0)
            assert not omitted.getbbox(),"unrelated native base art was removed"
        if previews:
            previews.mkdir(parents=True,exist_ok=True)
            canvas=Image.new("RGBA",(290,620),(16,18,19,255))
            for c in m["commands"]:
                if c[0]=="DRAW":
                    sx,sy,sw,sh,x,y,w,h,a,r,g,b=map(float,c[2:14])
                    texture=images[c[1]]
                    tile=texture.crop((int(sx),int(sy),int(sx+sw),int(sy+sh)))
                    bands=tile.split()
                    tile=Image.merge("RGBA",tuple(channel.point(lambda v,m=m:round(v*m))
                              for channel,m in zip(bands,(r,g,b,a))))
                    tile=tile.resize((round(w),round(h)),Image.Resampling.BILINEAR)
                    canvas.alpha_composite(tile,(round(x),round(y)))
                else:
                    values=list(map(float,c[1:]));x,y,v3,v4,a,r,g,b=values
                    color=tuple(round(v*255) for v in (r,g,b,a))
                    draw=ImageDraw.Draw(canvas)
                    if c[0]=="LINE":draw.line((x,y,v3,v4),fill=color,width=1)
                    else:draw.rectangle((x,y,x+v3-1,y+v4-1),outline=color,width=1)
            canvas.save(previews/(m["name"]+".png"))
    return {"models":len(models),"body_connections":connections,"tank_sizes":"42x30",
            "native_base_preserved":True}

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log",type=Path);parser.add_argument("fixture",type=Path)
    parser.add_argument("--previews",type=Path)
    args=parser.parse_args()
    print("KI5_GEOMETRY_PASS "+json.dumps(verify(args.log,args.fixture,args.previews)))

# RON Hex — Europa Rzeczypospolitej

Prototyp mapy strategicznej na hexach (styl Heroes of Might and Magic) w **Godot 4.3+**.
Epoka: ok. 1600, Rzeczpospolita w centrum.

## Jak otworzyć

1. Zainstaluj [Godot 4.3+](https://godotengine.org/download) (Standard).
2. W Godocie: **Import** → wskaż folder `ron-hex` (ten z `project.godot`).
3. F5 — uruchom scenę główną.

## Sterowanie

- **WASD / strzałki** — przesuwanie kamery  
- **Kółko myszy** — zoom  
- **Klik na hex** — nazwa regionu i współrzędne  

## Struktura

```
ron-hex/
  project.godot
  scenes/main.tscn       ← start
  scenes/world_map.tscn
  scripts/hex_math.gd    ← matematyka hex (pointy-top)
  scripts/world_map.gd   ← rysowanie mapy + klik
  scripts/camera_pan.gd
  scripts/main.gd
  data/regions.json      ← 12 regionów (stolice, kolory)
```

## Co jest na razie

- Siatka ~40×30 hexów, podzielona na 12 regionów (placeholder geograficzny)
- Stolice jako białe kropki
- Panel info na dole

## Następne kroki (kolejność)

1. Podmienić podział regionów na bardziej „europejski” kształt  
2. Ruch bohatera (koszt ruchu jak w Heroes)  
3. Zamki / zasoby na hexach  
4. Walki na osobnej scenie hex  

Koncepcja regionów: strona „Mapa hex — Europa Rzeczypospolitej” w czacie z asystentem.

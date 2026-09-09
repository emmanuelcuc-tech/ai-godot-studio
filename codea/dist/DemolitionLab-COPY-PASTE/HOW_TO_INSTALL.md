# How to install Demolition Lab in Codea (iPad)

You need **Codea** with **Craft** (3D).

## Fastest: COPY-PASTE zip

1. Get `DemolitionLab-COPY-PASTE.zip` from `codea/dist/`.
2. Unzip on iPad (Files app).
3. In Codea: **Add New Project** → name it `DemolitionLab` → choose **Craft** / 3D if asked.
4. Open folder `lua-buffers-for-paste/`.
5. Create buffers in this exact order (or rename after paste):

| Order | File | Buffer name |
|------:|------|-------------|
| 1 | `01_TNT.lua` | `TNT` |
| 2 | `02_Materials.lua` | `Materials` |
| 3 | `03_Blueprints.lua` | `Blueprints` |
| 4 | `04_CameraOrbit.lua` | `CameraOrbit` |
| 5 | `05_Building.lua` | `Building` |
| 6 | `06_Charges.lua` | `Charges` |
| 7 | `07_Main.lua` | `Main` |

6. Paste each file’s contents into its buffer.
7. Optional: copy `Textures/*.png` into the project Assets (brick, concrete, wood, steel, glass).
8. Tap **Play**.

## Alternate: `.codea.zip`

If your Codea version imports project zips, use `DemolitionLab.codea.zip`.

## Play tip

Double-tap the building to plant TNT → set delay with `[` `]` or turn on **P** pattern → tap **BOOM** → tap flashing **ARM**.

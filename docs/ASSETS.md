# Asset-lər, placeholder-lər və mənbə qeydiyyatı

## Mənbə və lisenziya qeydiyyatı (bölmə 18)

| Asset | Mənbə | Lisenziya | Qeyd |
|---|---|---|---|
| — | — | — | Layihədə **heç bir xarici asset yoxdur**. Bütün modellər koddan yaradılan primitiv hissələrdir; səs, tekstura, mesh, animasiya ID-si yoxdur. |

Final asset əlavə edildikcə bu cədvəl doldurulmalıdır: mənbə, müəllif, lisenziya, Roblox asset ID-si (yükləndikdən sonra).

## Placeholder siyahısı (final nəticədə hazır asset deyil)

Hamısı `src/shared/Visual/Placeholders.luau` və `src/server/Services/WorldService.luau` tərəfindən primitivlərlə qurulur.

| Kateqoriya | Placeholder | Bölmə 19 tələbi |
|---|---|---|
| Personaj | Roblox standart personajı + rəngli BodyColors, primitiv papaq/yaylıq/əlcək | 1 personaj rig-i, 13 animasiya klipi (heç biri yoxdur) |
| NPC | 3 blok fiqur (Pıtır, Nərgiz, Çırt) | 3 NPC görünüşü, minimal üz animasiyası |
| Alətlər | modelləri yoxdur (yalnız HUD-da ad) | 12 alət modeli |
| Qurğular | 13 qurğu + 9 dekor bloklardan | 13 yerləşən qurğu, 9 əlavə dekor |
| Bitkilər | 4 mərhələ primitivlərlə | 6 bitki × 4 mərhələ |
| Xatirələr | rəngli kürələr | 6 xatirə modeli |
| Ərazi | rəngli torpaq lövhələri, ot "dəstələri", divarlar | ərazi modul dəsti (13 element) |
| Ürək ağacı | silindr gövdə + iki kürə tac | quru, yarpaqlı, çiçəkli 3 görünüş |
| İkonlar | rəngli dairə + hərf | vahid üslublu ikonlar |
| UI | tema rəngləri ilə sadə çərçivələr | final UI dizaynı |
| Səs | **yoxdur** | 3 musiqi loop, final mövzusu, effektlər |
| Kinematika | sadə kamera uçuşları | final səhnəsi (25–35 s) |

## Final asset-ləri necə qoşmaq

Kod hazır modelləri adına görə axtarır. Tapılmasa placeholder qurur:

- **Sabit dünya obyektləri:** `ServerStorage/WorldTemplates/<ID>`. ID olaraq layout obyekt ID-si (məs. `Z01_DewBowl`)
  və ya tərif ID-si (məs. `W_LEAF`, `BED_DRY`, `NPC_PITIR`) istifadə olunur. Model `PivotTo` ilə obyektin yerinə qoyulur.
  Pivot yer səviyyəsində, obyektin mərkəzində olmalıdır.
- **Körpü və lift:** `ServerStorage/WorldTemplates/B_BRIDGE`, `B_LIFT`. Körpü Z oxu boyunca (20 stud, en 6), pivot mərkəzdə; lift pivotu aşağı platformanın mərkəzində.
- **Oyunçu qurğuları:** `ReplicatedStorage/Assets/Builds/<BuildDef ID>` (məs. `B_WHEEL`). Model `+X` istiqamətinə axın üçün
  qurulmalıdır (rot=0), pivot mərkəzdə. Çarxın fırlanan hissəsinin adı `Wheel`, sudakı hissənin adı `Water` olmalıdır (effektlər bunlara baxır).
- Hər asset üçün pivot, collision, vizual ölçü, LOD ehtiyacı, ID və mənbə qeyd olunmalıdır (bölmə 19). Sırf dekor otlarında collision olmamalıdır.

Ölçülər (stud) `src/shared/Defs/*.luau` və `src/shared/Layout/*.luau`-dadır. Model ölçüsü footprint-dən böyük olmamalıdır,
yoxsa yerləşdirmə yoxlaması ilə görünüş uyğunsuz olar.

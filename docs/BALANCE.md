# Balans hesabatı (avtomatik)

Bu fayl `lune run tools/balance_report.luau docs/BALANCE.md` ilə konfiqurasiyadan yaradılır.
Rəqəmlər dizayn məlumatlarının hesabıdır, ölçülmüş oyun vaxtı deyil.

## Məcburi alışlar

“Keçid” sütunu: alış olmadan kampaniya irəliləmir (addım və ya iş tələbi). Qalanları sənədin
məcburi büdcəsinə (3 650) daxildir, amma oyun onları tələb etmir (rahatlıq alətləri, çanta).

| Fəsil | ID | Qiymət | Keçid |
|---:|---|---:|:---:|
| 1 | BAG_24 | 80 | — |
| 1 | TOOL_SAW_1 | 60 | ✓ |
| 1 | TOOL_SHEARS_1 | 15 | ✓ |
| 2 | G_Z02 | 150 | ✓ |
| 2 | TOOL_CUP_2 | 140 | — |
| 2 | TOOL_GLOVES_2 | 100 | — |
| 3 | BAG_36 | 240 | — |
| 3 | G_Z03 | 200 | ✓ |
| 3 | TOOL_CART_1 | 220 | ✓ |
| 3 | TOOL_SHOVEL_1 | 180 | ✓ |
| 4 | G_Z04 | 300 | ✓ |
| 4 | TOOL_LEVER_1 | 280 | ✓ |
| 5 | G_Z05 | 415 | ✓ |
| 5 | TOOL_BRUSH_1 | 250 | ✓ |
| 5 | TOOL_CUP_3 | 420 | — |
| 6 | TOOL_SHEARS_2 | 600 | ✓ |
| | **Cəmi (sənəd büdcəsi)** | **3650** | |
| | **Cəmi (yalnız keçid üçün)** | **2670** | |

## Zəmanətli gəlir və XP (təkrar iş və sifarişsiz)

Fərz: oyunçu açıq sahələrdəki bütün birdəfəlik obyektləri və əlavə işləri bitirir (Z06 əlavə işlərindən yalnız xatirə).

| Fəsil | Fəsil mükafatı | Obyektlər (damğa/XP) | Əlavə işlər (damğa/XP) | Məcburi alışlar | Damğa balansı (kumulyativ) | XP (kumulyativ) | Güc |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 150 / 100 | 203 / 318 | 75 / 90 | 155 | 273 | 608 | 6 |
| 2 | 250 / 180 | 175 / 276 | 120 / 180 | 390 | 428 | 1244 | 8 |
| 3 | 350 / 350 | 118 / 180 | 150 / 240 | 840 | 206 | 2014 | 10 |
| 4 | 450 / 450 | 179 / 311 | 180 / 300 | 580 | 435 | 3075 | 12 |
| 5 | 550 / 600 | 124 / 180 | 210 / 360 | 1085 | 234 | 4215 | 15 |
| 6 | 700 / 650 | 312 / 570 | 160 / 300 | 600 | 806 | 5735 | 17 |

Damğa balansı sütunu fəsil mükafatı alındıqdan sonrakı vəziyyətdir (sənəd büdcəsinin hamısı alınırsa).
Fəsil daxilində, fəsil mükafatından əvvəl təkrar iş/sifarişlə qazanılmalı olan məbləğ:

| Fəsil | Bütün sənəd büdcəsi alınırsa | Yalnız keçid alışları |
|---:|---:|---:|
| 1 | 0 | 0 |
| 2 | 0 | 0 |
| 3 | 144 | 0 |
| 4 | 15 | 0 |
| 5 | 316 | 0 |
| 6 | 0 | 0 |

## Güc tələbləri

| Tələb | Güc | Lazım XP | Zəmanətli XP (əvvəlki fəslin sonu) | Fərq |
|---|---:|---:|---:|---:|
| Yüngül daş (Z01, çarx üçün çınqıl) | 4 | 240 | 418 | ✓ |
| Torpaq tıxacı (Z03) | 5 | 400 | 1244 | ✓ |
| Ling (Z04) | 7 | 840 | 2014 | ✓ |
| Şüşə panel (Z05) | 8 | 1120 | 3075 | ✓ |
| Kök qayçısı (Z06) | 15 | 4200 | 4215 | ✓ |

Qeyd: Z01 sətrində XP fəsil 1 daxilindədir (tutorial + Z01 obyektləri), fəsil mükafatı daxil deyil.

## Təkrar iş nümunələri (bölmə 14)

| Sifariş | İstək | Damğa | XP |
|---|---|---:|---:|
| O_FIBER8 | 8 MAT_FIBER | 16 | 20 |
| O_TWIG4 | 4 MAT_TWIG | 20 | 25 |
| O_PETAL6 | 6 MAT_PETAL | 24 | 30 |
| O_PEBBLE4 | 4 MAT_PEBBLE | 22 | 28 |
| O_RESIN3 | 3 MAT_RESIN | 18 | 24 |
| O_PLANK3 | 3 MAT_PLANK | 26 | 32 |
| O_CLAY4 | 4 MAT_CLAY | 24 | 30 |
| O_ROPE2 | 2 MAT_ROPE | 26 | 34 |
| O_METAL3 | 3 MAT_METAL | 26 | 34 |
| O_COMPOST2 | 2 MAT_COMPOST | 28 | 36 |
| O_GLASS3 | 3 MAT_GLASS | 28 | 36 |
| O_SEAL2 | 2 MAT_SEAL | 30 | 40 |

Yenilənən yuva: hər yuva 60 s aktiv oyundan sonra yenidən resurs verir.


# TINY GROVE — Balaca dünyanın bağbanı

Roblox üçün sakit, təknəfərlik bağ bərpası oyunu. Dizayn spesifikasiyası: `Tiny_Grove_Tam_Oyun_Plani.md` (v1.0, 3 oktyabr 2026).

> **Vəziyyət (dürüst xülasə).** Kod, sistemlər, məlumat kataloqları və altı sahənin hamısı yazılıb.
> Oyun məntiqi konteynerdə avtomatik testlərlə yoxlanıb. **Roblox Studio-da oynanmayıb**, çünki bu iş
> mühitində Studio-ya çıxış yoxdur. Bütün modellər primitiv placeholder-lərdir, səs yoxdur. Render,
> fizika, kamera, mobil cihaz davranışı və canlı DataStore **yoxlanmayıb**. Bax: [docs/TESTING.md](docs/TESTING.md).

## Nə hazırdır

| Mərhələ | Vəziyyət | Necə yoxlanıb |
|---|---|---|
| M0 — layihə qurulması | Hazır | Rojo yığımı, strict tip yoxlaması (luau-lsp + Roblox tipləri), startup kataloq yoxlaması |
| M1 — Z01 oynanıla bilən hissə | Kod hazır | Bot simulyasiyası (ilk 20 dəq), UI loopback testi (Lune DOM). Studio-da oynanmayıb |
| M2 — save və sabitlik | Kod hazır | Sessiya kilidi, kilid bərpası, retry, miqrasiya, duplikasiya testləri (yaddaşdaxili adapterlə). Canlı DataStore yoxlanmayıb |
| M3 — altı sahə, final | Kod hazır | Bot bütün kampaniyanı və finalı yalnız oyunçu əməliyyatları ilə bitirir; hər fəsildən sonra JSON save/load ilə də |
| M4 — vizual tamamlanma | **Edilməyib** | Final modellər, animasiyalar, səslər, ikonlar asset işi tələb edir (bax: [docs/ASSETS.md](docs/ASSETS.md)) |
| M5 — buraxılış yoxlaması | **Edilməyib** | Cihaz testi, performans ölçümü, canlı save/load sizin Roblox hesabınızda tələb olunur |

## Tez başlanğıc

```bash
# Bütün yoxlamalar (format, Rojo yığımı, tip yoxlaması, məntiq və DOM testləri)
./scripts/check.sh

# Roblox yerini yığmaq
rojo build default.project.json -o build/TinyGrove.rbxl
```

Ətraflı quraşdırma, Studio-da işə salma və yayımlama: [docs/SETUP.md](docs/SETUP.md).

## Sənədlər

- [docs/SETUP.md](docs/SETUP.md): alətlər, yığım, Studio, yayımlama, sizin etməli olduğunuz addımlar
- [docs/TESTING.md](docs/TESTING.md): nə test olunub, nə olunmayıb; bölmə 25 ssenarilərinin vəziyyəti
- [docs/BALANCE.md](docs/BALANCE.md): konfiqurasiyadan avtomatik balans hesabatı
- [docs/DESIGN_DECISIONS.md](docs/DESIGN_DECISIONS.md): sənəd daxilində verdiyim qərarlar, sənəddəki uyğunsuzluqlar
- [docs/ASSETS.md](docs/ASSETS.md): placeholder siyahısı, final asset-lərin necə qoşulacağı, mənbə qeydiyyatı
- [docs/OPEN_ISSUES.md](docs/OPEN_ISSUES.md): qalan problemlər və sizdən tələb olunan qərarlar

## Struktur

```
src/shared/            → ReplicatedStorage.Shared
  Constants, Types
  Defs/                kataloqlar: əşya, alət, iş, qurğu, resept, bitki, dükan, sahə, tapşırıq, NPC
  Layout/              altı sahənin tərtibatı (obyektlər, tikinti sahələri, yollar, divarlar)
  Locales/             AZ və EN mətnləri
  Core/                Roblox-dan asılı olmayan oyun məntiqi (Game, Water, Placement, Inventory, ...)
  Visual/Placeholders  primitiv placeholder modellər
src/server/            → ServerScriptService.Server
  ProfileStore         UpdateAsync sessiya kilidi, revision, retry
  Services/            PlayerData, Session, World, CharacterLook, Telemetry
src/client/            → StarterPlayerScripts.Client
  Net, Lang, Signal, UI/ (HUD, panellər, dialoq, kinematika), Controllers/ (əlaqə, tikinti, kamera, effektlər)
tests/                 Lune testləri (məntiq, simulyasiya, DOM tüstü testləri)
tools/balance_report   balans auditi
```

Bütün oyun mexanikası serverdə işləyir. Client yalnız niyyət göndərir (əməliyyat adı + ID-lər) və heç vaxt
qiymət, mükafat, XP və ya nəticə göndərmir.

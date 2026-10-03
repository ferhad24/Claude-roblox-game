# Quraşdırma və işə salma

## 1. Alətlər

Layihə bu versiyalarla yazılıb və yoxlanıb:

| Alət | Versiya | Nə üçün |
|---|---|---|
| [Rojo](https://rojo.space) | 7.7.1 | `src/` qovluğundan Roblox yeri (`.rbxl`) yığmaq və ya Studio ilə canlı sinxronizasiya |
| [StyLua](https://github.com/JohnnyMorganz/StyLua) | 2.5.2 | Kod formatı (`stylua.toml`) |
| [Lune](https://lune-org.github.io/docs) | 0.10.5 | Testləri Roblox-dan kənarda işlətmək |
| [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) | 1.70.1 | Roblox tipləri ilə strict tip yoxlaması |

Quraşdırma variantları: Rust varsa `cargo install rojo stylua lune --locked` (StyLua üçün `--features luau`).
Alternativ olaraq GitHub release-lərindən hazır faylları və ya Rokit/Aftman kimi alət menecerlərini istifadə edə bilərsiniz.

Tip yoxlaması üçün Roblox tip tərifləri lazımdır. luau-lsp repozitoriyasındakı
`scripts/globalTypes.None.d.luau` faylını `.tools/roblox.d.luau` adı ilə kopyalayın
(`.tools/` git-ə daxil deyil). Fayl yoxdursa `scripts/check.sh` tip yoxlamasını atlayır və bunu xəbərdarlıqla bildirir.

## 2. Yoxlamalar

```bash
./scripts/check.sh
```

Bu skript ardıcıl olaraq bunları edir: StyLua format yoxlaması, Rojo yığımı (`build/TinyGrove.rbxl`),
luau-lsp strict tip yoxlaması, Lune məntiq testləri (`tests/run.luau`) və Lune DOM tüstü testləri
(`tests/dom/`). Ayrıca:

```bash
lune run tests/run.luau            # bütün məntiq testləri
lune run tests/run.luau campaign   # yalnız adında "campaign" olan spec
lune run tools/balance_report.luau docs/BALANCE.md   # balans hesabatını yenilə
```

## 3. Roblox Studio-da açmaq

Variant A (fayl):

```bash
rojo build default.project.json -o build/TinyGrove.rbxl
```

`build/TinyGrove.rbxl` faylını Roblox Studio-da açın və **Play** basın.

Variant B (canlı sinxronizasiya): Studio-da Rojo plaginini quraşdırın, terminalda `rojo serve` işə salın,
plagində **Connect** basın. `src/` dəyişiklikləri Studio-ya avtomatik gəlir.

Oyun başlayanda server əvvəlcə kataloq yoxlamasını aparır. Xəta olarsa, oyun başlamır və Output pəncərəsində
`[TinyGrove] Kataloq xətası: ...` sətirləri görünür.

## 4. Yaddaş (DataStore)

- **Yalnız Studio-da:** yer yayımlanmayıbsa və ya API girişi bağlıdırsa, server **test adapterinə** keçir. Bu halda
  irəliləyiş yalnız server işlədiyi müddətdə yaddaşda qalır və ekranda "Test rejimi" yazısı görünür.
- Canlı serverdə test adapterinə heç vaxt keçilmir: DataStore xətası olarsa oyunçu "yenidən cəhd" ekranını görür,
  təzə profillə başlamır və köhnə save-in üzərinə yazılmır.
- Canlı DataStore-u Studio-da yoxlamaq üçün yeri öz hesabınıza yayımlamalı və oyun ayarlarında
  Studio-nun API xidmətlərinə girişini açmalısınız. Bu addımı yalnız siz edə bilərsiniz.
- DataStore adı: `TinyGrove_Profiles_v1` (`src/shared/Constants.luau`). Açar: `p_<UserId>`. Studio-dakı
  mənfi ID-li test oyunçuları üçün açar `test_<UserId>`-dir.

Bölmə 24 (M2) tələb edir ki, save/load yayımlanmış **test** təcrübəsində, ayrıca açarlarla yoxlansın.
Bunun üçün `Constants.DATASTORE_NAME` dəyərini test yerində dəyişin (məs. `TinyGrove_Profiles_test`).

## 5. Yayımlama (sizin hesabınızda)

Bu addımlar yalnız sizin hesabınızla mümkündür və mən onları etməmişəm:

1. Studio-da yeri **Publish to Roblox** ilə öz hesabınıza yayımlayın.
2. Oyun ayarlarında yerin **maksimum oyunçu sayını 1** edin. Bu, bölmə 20-dəki MaxPlayers=1 qərarıdır.
   Kod ikinci oyunçunu müdafiə üçün serverdən çıxarır, amma bu, platforma ayarını əvəz etmir.
3. Analitika hadisələri (`AnalyticsService:LogCustomEvent`) Creator Dashboard-da görünür. Bu
   davranışı yoxlamamışam.
4. Nailiyyətləri platforma badge-i kimi göstərmək istəsəniz, badge-ləri Creator Dashboard-da yaradıb
   ID-lərini koda əlavə etmək lazımdır. Hazırda nailiyyətlər yalnız oyun daxilindədir. Mövcud olmayan badge
   ID-si uydurulmayıb.

## 6. İdarəetmə

| Cihaz | Hərəkət | İş | Əlaqə | Digər |
|---|---|---|---|---|
| PC | WASD, siçan kamera, Shift qaçış | sol düyməni basılı saxla | E | 1–4 alət, Tab inventar, M xəritə, J tapşırıqlar, B tikinti, P pauza, R döndür, F forma, Esc menyu (pauza) |
| Mobil | sol joystik, sağ kamera, "Qaç" düyməsi | böyük "İşlə" düyməsi (basılı) | kontekst düyməsi | tikintidə: toxunma ilə daşı, Döndür / Forma / Təsdiq / Ləğv düymələri |
| Gamepad | sol stick, sağ kamera, L3 qaçış | R2 (basılı) | X | A təsdiq, B geri; tikintidə X döndür, Y forma |

Gamepad xəritəsi kodda var, amma cihazda yoxlanmayıb.

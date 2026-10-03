# Testlər və nəticələr

Son yoxlama: `./scripts/check.sh` keçdi. Nəticə: 66 məntiq testi keçdi, 0 uğursuz; strict tip yoxlamasında 0 xəta;
2 DOM tüstü testi xətasız.

## Nə yoxlanır və nə yoxlanmır

| Səviyyə | Alət | Nəyi yoxlayır | Nəyi YOXLAMIR |
|---|---|---|---|
| Statik | luau-lsp (strict, Roblox tipləri) | Tip xətaları, mövcud olmayan xassə/metod adları, nil istifadəsi | Runtime davranışı |
| Kataloq | `Catalog.validate` (server başlanğıcında da işləyir) | ID unikallığı, istinadlar, tapşırıq ardıcıllığı, port şəbəkəsi, AZ/EN mətnləri | — |
| Məntiq | Lune (`tests/specs`) | Bütün oyun qaydaları, iqtisadiyyat, su qrafı, save/kilid, duplikasiya | Roblox engine |
| Simulyasiya | Lune bot (`tests/sim`) | İlk 20 dəqiqə və bütün kampaniya yalnız oyunçu əməliyyatları ilə; softlock; balans | İnsan davranışı, real yeriş və kamera |
| DOM tüstü | Lune `@lune/roblox` (`tests/dom`) | Yığılmış `.rbxl` daxilində dünya qurulması, UI-nin yaradılması, real oyun nüvəsinə qoşulmuş UI düymələri | Render, layout, fizika, siqnalların real vaxtı, şəbəkə |
| **Roblox Studio / cihaz** | — | **Edilməyib** | Bu mühitdə Studio-ya və cihazlara çıxış yoxdur |

Simulyasiyadakı vaxtlar **təxmindir**: iş və gözləmə vaxtı tick ilə hesablanır. Yeriş vaxtı düz xətt məsafəsi ×1.3 / 14 stud/s
götürülür, hər UI əməliyyatı üçün 2 s əlavə olunur. Bot tərəddüd etmir, kəşf etmir, divarları dolanmır. Real oyunçu vaxtı bundan
xeyli uzun olacaq və yalnız real oynama testi ilə ölçülə bilər.

## Simulyasiya nəticələri (son işləmə)

İlk 20 dəqiqə (`z01_first20.spec`): fəsil 1 botla ~3.3 dəqiqədə bitir. Sənəddəki rəqəmlər təsdiqləndi:

- 3 yarpaq → dəqiq 15 damğa = qayçının qiyməti
- 24 + 100 XP → güc 3 (budaq işi mişar alınanda artıq mümkündür)
- Emalatxana 2 pulsuz kanal verir; çarx + 2 kanal ilə su birinci yatağa çatır
- Çanta dolu olanda material itmir, damğa yenə verilir, yeni toplama dayanır

Tam kampaniya (`campaign.spec`, bot bütün əlavə işləri də görür):

| Fəsil | Bitmə vaxtı (təxmini, dəq) | Damğa | Güc |
|---:|---:|---:|---:|
| 1 | 2.3 | 291 | 5 |
| 2 | 5.6 | 643 | 7 |
| 3 | 17.6 | 699 | 10 |
| 4 | 23.0 | 859 | 12 |
| 5 | 28.3 | 1121 | 14 |
| 6 (final) | ~40 | 1905 | 17 |

- Güc 15 (kök qayçısı) təkrar işsiz əldə olunur: fəsil 6-dan əvvəl XP 4369 ≥ 4200. Bunun üçün fəsil 3–5 XP bonusları artırılıb, bax: DESIGN_DECISIONS.
- Bot istəyə bağlı alətləri almır; onlarla birlikdə lazım olan təkrar iş üçün [BALANCE.md](BALANCE.md)-yə baxın.
- Hər fəsildən sonra profil JSON-a yazılıb yenidən yüklənəndə də kampaniya sona çatır.
- Kampaniya sonunda profilin JSON ölçüsü ~8.5 KB-dır (DataStore limiti 4 MB).

## Bölmə 25 — məcburi sınaq ssenariləri

| Ssenari | Vəziyyət | Harada |
|---|---|---|
| İlk üç yarpaqdan sonra qayçı üçün dəqiq damğa | ✓ məntiq | `z01_first20.spec` |
| Çanta dolu: material itmir, damğa hesablanır | ✓ məntiq | `z01_first20.spec` |
| Təkrar Buy/Craft/Harvest duplikasiya yaratmır | ✓ məntiq | `security.spec` |
| Uyğunsuz alət və uzaq obyekt işə başlamır | ✓ məntiq | `security.spec` |
| İş yarıda dayanıb davam edəndə irəliləyiş və mükafat doğru | ✓ məntiq | `security.spec` |
| Su qrafının dövrəsi su yaratmır; boş mənbə/enerji kəsilməsi nasosu dayandırır | ✓ məntiq | `water.spec` |
| Qurğunu yığıb qoymaq material və su çoxaltmır | ✓ məntiq | `security.spec` |
| Bitki susuz dayanır, ölmür; oflayn dəyişmir | ✓ məntiq | `security.spec` |
| Yükləmə xətasında əvvəlki profil əvəzlənmir | ✓ yaddaşdaxili adapter | `save.spec` |
| İki sessiya paralel yazmır; kilid bərpası | ✓ yaddaşdaxili adapter | `save.spec` |
| Yeni schemaVersion miqrasiya; uyğunsuz save rədd | ✓ | `save.spec` |
| Kampaniya şərtlərində mənbə/resept əlçatandır; unikal material xərclənmir | ✓ kataloq + bot | `catalog.spec`, `campaign.spec` |
| Pauza vaxtı dayandırır; qayıtmaq təkrar mükafat vermir | ✓ məntiq | `security.spec` |
| Streaming zamanı uzaq obyektin çıxması xəta yaratmır | **test edilməyib** | `StreamingEnabled=false`; controller-lər tag siqnallarına və `Parent` yoxlamasına əsaslanır |
| Mobil ekranlarda bütün alış və yerləşdirmə düymələri görünür və işləyir | **test edilməyib (cihazda)** | Düymələr yaradılır və DOM testində basılır; ölçü/yerləşmə real ekranda yoxlanmayıb |
| Finaldan sonra sərbəst rejim, yaddaş, yenidən final baxışı | ✓ məntiq | `campaign.spec` |

Canlı DataStore, performans (30/60 FPS hədəfi), ən azı 3 cihaz ölçüsündə yoxlama, kamera collision, render və animasiya
**test edilməyib**. Bunlar M4–M5 üçün Roblox Studio və real cihazlar tələb edir.

## Testlərin siyahısı

```
catalog.spec       kataloq yoxlaması; mutasiya testi (yoxlamanın həqiqətən xəta tutduğu); 2450 və 3650 cəmləri
progression.spec   XP düsturu, güc əlavəsi, ustalıq xərcləri və 10% tavanı
z01_first20.spec   ilk 20 dəqiqə (bot)
water.spec         əlaqəsiz çıxış, 1 doza/s, qapalı halqa, çarx+nasos, çənin növbəli bölgüsü, struktur yoxlaması
security.spec      duplikasiya, iş doğrulaması, qurğu/su, pauza/oflayn, yanlış sorğular, sürət limiti, lift
save.spec          sessiya kilidi, köhnəlmiş kilid, yükləmə xətası, retry, v0 miqrasiyası, gələcək versiya, təmizləmə
locales.spec       koddakı bütün mətn açarları AZ və EN-də var
campaign.spec      tam kampaniya, güc 15 zəmanəti, finaldan sonrası, hər fəsildən sonra save/load
tests/dom/world_smoke.luau   yığılmış yerdə dünya qurulması, bütün qurğu növləri, personaj görünüşü
tests/dom/ui_smoke.luau      UI → real oyun nüvəsi: Başla, 11 panel, alış, iş, su, tikinti
```

## Lune DOM testlərinin məhdudiyyətləri (tapılmış və test daxilində əvəzlənmiş)

Bunlar oyun xətası deyil, test mühitinin xüsusiyyətləridir:

- Lune-da engine xidmətləri (TweenService, CollectionService, UserInputService və s.) və siqnallar yoxdur. Testdə sadə əvəzedicilərlə əvəzlənib.
- `BasePart.Position`, `Camera.ViewportSize`, `Workspace:Raycast`, `Model:GetPivot` engine tərəfindən hesablanır. Testdə əl ilə verilir.
- Lune 0.10.5-də `CFrame.lookAt` düz +Z istiqamətində səhv `LookVector` qaytarır. Testdə `CFrame.Angles` istifadə olunur.
- Lune eyni Instance üçün fərqli userdata obyektləri qaytara bilir. Test siqnalları atributdakı sabit ID ilə açarlanır.

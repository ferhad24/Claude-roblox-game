# Açıq məsələlər

## Sizin qərarınızı tələb edənlər

1. **Kampaniya uzunluğu (konsept qərarı).** Sənəd 6–8 saat hədəfləyir. İdeallaşdırılmış bot bütün kampaniyanı
   ~40 dəqiqəyə bitirir. Real oyunçu daha yavaş olacaq (kəşf, oxumaq, kamera, divarları dolanmaq), amma fərq böyükdür.
   Dəqiq rəqəm yalnız real oynama testi ilə bilinə bilər. Uzatmaq üçün mümkün yollar (hər biri konsepti dəyişir,
   ona görə sizin qərarınızdır):
   - hər sahəyə daha çox əsas iş və yataq əlavə etmək (məzmun);
   - bitki böyümə vaxtlarını, yenilənmə müddətini və qurğu reseptlərini artırmaq (temp);
   - ustalıq və dekor kolleksiyasını kampaniyanın daha böyük hissəsinə çevirmək (sərbəst rejim).
2. **Personajın görünüşü.** Prototipdə `LoadCharacterAppearance=false` qoyulub ki, kombinezon/papaq rəngləri görünsün.
   Bu, oyunçunun öz avatar geyimini gizlədir. Avatar geyimini saxlamaq istəsəniz, `default.project.json`-da bu ayarı `true` edin.
3. **İstəyə bağlı alətlərin qiyməti.** Sənəd büdcəsinə daxil olan, amma keçid üçün lazım olmayan alətlər (toxunmuş əlcək,
   qabıq qabı, şeh çiləyicisi, çantalar) üçün fəsil 3-də ~144, fəsil 5-də ~316 damğa təkrar işlə qazanılmalıdır.
   Bu, sənədin "10–15 dəqiqədən artıq təkrar olmasın" qaydası daxilində görünür, amma real ölçülməyib.

## Sizin hesabınızla edilməli olanlar (mənim çıxışım yoxdur)

- Yeri Roblox-a yayımlamaq, maksimum oyunçu sayını 1 etmək (bax: SETUP.md).
- Canlı DataStore ilə save/load yoxlaması (ayrıca test açarları ilə).
- Ən azı 3 cihaz ölçüsündə oynama testi (telefon, planşet, PC), FPS ölçümü (MicroProfiler).
- Platforma badge-ləri (istəsəniz) və analitikanın Creator Dashboard-da göründüyünün yoxlanması.

## Edilməyən işlər (M4–M5)

- Final 3D modellər, animasiyalar (13 klip), ikonlar, musiqi və səs effektləri. Səs ayarları saxlanılır, amma səs yoxdur.
- Thumbnail və oyun cover-i.
- Performans ölçümü. Hard limitlər kodda var: 120 qurğu, 12 əkin qabı, 60 kanal, 20 dekorativ böcək.
- Instance streaming açılmayıb (`StreamingEnabled=false`). Controller-lər tag siqnallarına əsaslanır, amma streaming test edilməyib.

## Studio-da yoxlanmalı riskli yerlər

- Divarlar, qapılar, maneələrin görünməz bariyerləri: oyunçunun ilişib qala biləcəyi yer olub-olmadığı.
- Kamera: `Zoom` okklüziyası, otların lokal şəffaflaşması, ilkin 12 stud məsafə.
- Lift prototipdə teleport kimi işləyir (fiziki platforma deyil).
- Mobil UI: HUD elementlərinin kiçik ekranlarda üst-üstə düşməsi, 48 px toxunma hədəfləri, təhlükəsiz sahə.
- Gamepad düymə xəritəsi.
- Gün-gecə işıqlandırması və yağış effekti (sadə ParticleEmitter).

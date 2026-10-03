# Dizayn qərarları və sənəddəki uyğunsuzluqlar

Sənəd (bölmə 28) geri qaytarıla bilən texniki qərarları özüm verməyimi istəyir. Konsepti dəyişən məsələləri isə ayrıca
bildirməliyəm. Aşağıda verdiyim bütün qərarlar, sənəddən kənara çıxdığım yerlər və sənəddə tapdığım uyğunsuzluqlar var.
Hamısı konfiqurasiyadadır və asanlıqla dəyişdirilə bilər.

## A. Sənəddə tapılan uyğunsuzluqlar və necə həll etdim

1. **Güc 15 əldə olunmurdu.** Sənəddəki rəqəmlərlə bütün məcburi işlər, bütün birdəfəlik obyektlər və bütün əlavə işlər görülsə də,
   5-ci fəslin sonunda XP 3865 olurdu. Güc 15 üçün isə 4200 lazımdır (fərq 335). Bölmə 15-in öz qaydasını tətbiq etdim ("çatmırsa
   məcburi bonus artırılır, boş təkrar məcburiyyəti yaradılmır"): fəsil 3–5 XP bonusları 250/350/450-dən **350/450/600**-ə qaldırıldı.
   İndi zəmanətli XP 4215 ≥ 4200-dür. Əlavə işləri etməyən oyunçu üçün fərq hələ də var və təkrar işlə bağlanır. Bax: BALANCE.md.
2. **Z04: "4 budaq maneəsi" və "Ling → 4 maneə".** Sahə cədvəli budaq deyir, fəsil zənciri və güc cədvəli isə linglə ağır daş deyir.
   Ling budaq işləmir (mişar işləyir). 4 **ağır daş** maneəsi seçdim.
3. **Material mənbələri üçün iş obyektləri yox idi.** Bölmə 9 qatran nöqtələri, dibçək qırıntıları, köhnə alət hissələri və istixana
   qutularını mənbə kimi göstərir, amma bölmə 7-nin cədvəlində onlar yoxdur. Z03-ün "kök keçidləri" üçün kürək işi də yoxdur.
   5 iş tərifi əlavə etdim (`WorkDefs`-də `specAdded = true`). Mükafatları qonşu cədvəl dəyərlərinə uyğun seçdim:

   | ID | İş | Alət | Güc | Mükafat |
   |---|---:|---|---:|---|
   | W_SOIL_CLOG | 10 | kürək | 5 | 2 gil, 14 damğa, 22 XP |
   | W_RESIN | 4 | əlcək | 2 | 1 qatran, 4 damğa, 8 XP |
   | W_CLAY | 5 | əlcək | 4 | 2 gil, 6 damğa, 10 XP |
   | W_METAL | 6 | əlcək | 5 | 2 metal, 6 damğa, 12 XP |
   | W_GLASS_SHARD | 6 | əlcək | 8 | 2 şüşə, 6 damğa, 12 XP |
4. **Nərgizin 2 kompostu.** Cümlə ("ilk kompost qabını hazırlamaq üçün Nərgiz 2 kompost verir; qabın öz reseptində kompost yoxdur")
   iki cür oxuna bilir. Belə həll etdim: Nərgiz 2 kompost verir, bu birinci **əkin qabına** (4 gil + 2 kompost) bəs edir. Kompost qabının
   reseptində kompost yoxdur, ona görə əkin sistemi özünü bloklamır.
5. **12 tutumlu çanta ilk 3 yarpaqla dəqiq dolur** (3 × 4 lif). Bu xəta deyil, amma ilk 5 dəqiqədə ilk sap kəsiləndə
   "Çantan doludur" çıxır. Sənədə uyğun olaraq material itmir: sığmayan hissə "gözləyən" kimi saxlanır, damğa verilir və növbəti
   material toplanması anbara boşaltmağa qədər dayanır. Emalatxanada hazırlıq çanta + anbardan birlikdə götürür ki, geri-irəli gediş azalsın.
6. **"Məcburi" büdcə 3650.** Bu məbləğ bütün alətləri, hər iki çantanı və bütün açarları əhatə edir. Bunlardan 980 damğalığını
   (toxunmuş əlcək, qabıq qabı, şeh çiləyicisi, çantalar) oyun tələb etmir. Keçid üçün mütləq lazım olanların cəmi 2670-dir.
   Kataloqda `mandatory` bayrağı sənəd büdcəsinə uyğundur və test cəmin 3650 olduğunu yoxlayır.
7. **Kampaniya uzunluğu.** Sənədin ilkin hədəfi 6–8 saatdır. İdeallaşdırılmış bot bütün kampaniyanı ~40 dəqiqəyə bitirir.
   Real oyunçu xeyli yavaş olacaq, amma sənəddəki məzmun və rəqəmlər 6–8 saatı təmin etməyə bilər. Bu, konsept qərarıdır və
   **sizə buraxıram** (bax: OPEN_ISSUES.md).

## B. Sənədin açıq buraxdığı detallar üçün qərarlar

| Mövzu | Qərar | Yer |
|---|---|---|
| Şeh qabı (sonsuz mənbə) | tutum 12 doza, 4 s-də 1 doza | `Layout/Z01` |
| Əlavə sonsuz mənbələr | Z05 yağış novu (5 s), Z06 bağ kranı (2 s). Şəbəkə ilə sulanan hədəflər üçün softlock olmasın deyə | `Layout/Z05`, `Z06` |
| Ev su rezervuarı | tutum 120 doza | `Constants` |
| Yağışda toplayıcı | 5 s-də 1 doza (adi 20 s) | `Constants` |
| Yataq bərpası | `doza × 25` rütubət. Yataq 3 doza = 75; dibçək, kök rezervuarı və tac 4 doza = 100 (rütubət maksimumu 100) | `WorkDefs` |
| Bərpadan əvvəl rütubət | yalnız qismən sulanmış yataq hər 30 s-də 2 azalır; bərpa olunmuş yataq qurumur | `Game.tick` |
| "Yüksək səviyyəli yataq" | fiziki hündürlük yox, `requiresPump` bayrağı: xəttdə nasosdan keçən su lazımdır | `Water` |
| Enerji | xəttdəki hər çarx 1 enerji verir, hər nasos 1 istəyir; çəndə enerji sıfırlanır | `Water.trace` |
| Kanal formaları | düz, sola, sağa (eyni B_CHANNEL əşyası). Künclər olmadan xətt dönə bilməzdi | `BuildDefs` |
| Port şəbəkəsi | sabit obyektlərin portları cüt koordinatdadır. Kanal 4 stud olduğu üçün tək portlara təbii mənbədən çatmaq olmurdu; bunu yoxlama tutur | `Catalog.validate` |
| Ölçü mərhələləri | sahə fəslin yarısı bitəndə "qismən", hamısı bitəndə "tam bərpa" | `WorldService` |
| Ustalıq | işarələr ardıcıl 5/10/15/20/25; vaxt azalması `iş / (sürət × güc × 1/(1−0.02×səviyyə))` | `Progression` |
| İş məsafəsi | obyektin mərkəzinə yox, footprint-in kənarına ölçülür (böyük daşlar və panellər üçün) | `Game.distanceToObject` |
| Əlcək/ling ilə yüngül daş | əlcək 1 iş/s (2-ci səviyyə 1.8), ling 2.2 | `ToolDefs` |
| Bitki çıxarılması | dolu əkin qabı yığılanda bitkinin növü toxum kimi qaytarılır | `Game.storeBuild` |
| Lift | prototipdə qısa keçid (teleport) kimi işləyir: aşağı və yuxarı dayanacaqda (Z05 masası, Z=−34) əlaqə | `Game` UseLift |
| Rahat keçid | yalnız finaldan sonra, yalnız açılmış sahələrə | `Game` FastTravel |
| Sifariş təklifləri | deterministik təsadüf (profil toxumu); bitən iş dərhal geri gəlmir; dəyişmək pulsuzdur | `Game` |
| Sürət limitləri | iş 4/s, alış/craft 2/s, yerləşdirmə 4/s, digər 8/s | `Constants` |
| Avtomatik save | 150 s; fəsil sonu, final və alışdan sonra tez save növbəsi | `SessionService` |
| Sessiya kilidi | Hər save-də yenilənir. Server çöksə, 600 s (4 avtomatik save intervalı) sonra köhnəlmiş sayılır və götürülür; köhnə sessiya artıq yaza bilmir. Save-lər ardıcıldır; `BindToClose` gedən yazıları 25 s-ə qədər gözləyir | `ProfileStore`, `SessionService` |
| Pauza | yalnız Pauza ekranı və Esc menyusu pauza edir; digər panellər oyunu dayandırmır | `Panels`, `init.client` |
| Başlanğıc | profil yüklənəndə oyun pauzadadır; "Başla/Davam et" basanda vaxt işləyir | `SessionService` |
| Personaj | Roblox standart personajı (`LoadCharacterAppearance=false`), rəngləri ayarlarda seçilir; yarpaq papaq, yaylıq, əlcəklər primitivdir | `CharacterLook` |
| Gamepad | X əlaqə (A Roblox-da tullanmadır); A təsdiq, B geri | `Interaction`, `Build` |
| Reset (Esc menyusu) | söndürülmür: 2 s sonra son təhlükəsiz nöqtədə yenidən yaranma (ilişən oyunçu üçün də çıxış yoludur) | `SessionService` |
| Shift Lock | söndürülüb (`EnableMouseLockOption=false`), çünki Shift qaçışdır | `default.project.json` |
| DataStore əlçatan deyil | yaddaşdaxili test rejimi yalnız Studio-da; canlı serverdə yükləmə xətası və "yenidən cəhd" | `PlayerDataService` |
| İş/əlaqə məsafəsi | client ipucu və server yoxlaması eyni funksiya ilə; client 0.5 stud ehtiyatla göstərir (server mövqeyi gecikir) | `Layout.distanceTo`, `Interaction` |
| Basılı iş düyməsi | bir sorğu gözlənilir; server rədd edərsə düymə buraxılana və ya hədəf dəyişənə qədər təkrar yoxdur ("uzaqdır" istisna: 0.4 s sonra səssiz təkrar) | `Interaction` |
| Toxunuşlu cihazda düzən | iş/əlaqə sütunu tullanma düyməsinin üstündə; hotbar yığcam; menyu solda | `Interaction`, `Hud` |
| Ev anbarındakı su | anbarda "Anbara boşalt" və "Doldur" seçimi (çən yığılanda su bura keçir) | `Interaction` |
| Azərbaycan dilində sıra şəkilçisi | "{n}-ci fəsil" əvəzinə "fəsil {n}" (3-cü, 4-cü, 6-cı fərqi səhv çıxmasın) | `Locales/AZ` |

## C. Sənəddə olmayan, layihəyə əlavə edilənlər

- Z01 xəritəsində "masa altı" keçidi (Z04 qısa yolu və Z05 rampası ilə əlaqə).
- Z05 rampası (sahə açılanda açılan qapı ilə), Z06 qərb qısa yolu və 3 yenilənən yuva (bölmə 5 və 9 tələbləri üçün).
- Əlavə işlər (hər sahədə 3): xatirə, qısa yol və ya qurğu, sahə bitkisi.
- Sifarişlər: sənəddəki 3 nümunə (8 lif, 4 budaq, 6 ləçək) və eyni nisbətlə 9 sifariş daha.
- Nailiyyət mükafatları: 10–25 damğa (final və "Bağın ustası" kosmetikdir).

## D. Bilərəkdən edilməyənlər

- Ödəniş, rebirth, loot box, multiplayer, döyüş (bölmə 22–23).
- Offline qazanc yoxdur: vaxt yalnız aktiv oyunda keçir.
- Xarici asset ID-ləri, səs ID-ləri və platforma badge ID-ləri uydurulmayıb.

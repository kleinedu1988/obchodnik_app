# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog
and this project adheres to Semantic Versioning.

---

## [0.5.6] - 2026-02-27

### Opraveno

- **KRITICKÁ OPRAVA: Chybějící třída `CustomerProfilesRepository`**: Soubor `customer_profiles_repository.dart` obsahoval pouze duplicitní (a nekompatibilní) verzi modelu `CustomerProfile`, ale chyběla v něm samotná třída `CustomerProfilesRepository`. `DbService` ji instantioval a volal na ní 7 metod — kód se proto vůbec nekompiloval. Soubor byl přepsán kompletní implementací repozitáře se všemi metodami (`getCustomerProfiles`, `saveCustomerProfile`, `saveCustomerProfileRaw`, `deleteCustomerProfile`, atd.).

- **KRITICKÁ OPRAVA: SQL chyba `no such column: ""`**: Import zákazníků selhal s výjimkou `SQLITE_ERROR: no such column: ""`. Příčina: SQLite používá pro řetězcové literály **jednoduché** uvozovky (`''`), nikoli dvojité (`""`). Dvojité uvozovky jsou v SQLite vyhrazeny pro identifikátory sloupců/tabulek. Opraveno v podmínce `WHERE customer_profile_uid != ''`.

- **KRITICKÁ OPRAVA: `Illegal argument in isolate message` (Unsendable closure)**:
  Import zákazníků selhal s chybou `OBJECT IS UNSENDABLE` při předávání dat do `Isolate.run()`. Kořenová příčina: **Dart zachytí v closure celý activation record obklopující funkce** — i proměnné, které closure explicitně nepoužívá. Closure `processData` definovaná uvnitř `importZakazniku` proto implicitně zachytila `onProgress` (callback držící referenci na Flutter widget strom přes `ValueNotifier<double>`), `db` a `this`. Flutter widgety přes izolátové hranice přenést nelze.

  > ⚠️ **PRAVIDLO PRO BUDOUCÍ KÓD**: Closure předávaná do `Isolate.run()` **nesmí být definovaná uvnitř instance metody**. Vždy ji zabalte do `static` pomocné metody, která jako parametry přijme **pouze** data potřebná pro výpočet. Tím se zabrání nechtěnému zachycení nesendable objektů.

  Opraveno extrakcí výpočetní logiky do `static` metod `_processImportData` a `_buildProfileMapFromRows`, a volání `Isolate.run` bylo přesunuto do dalších `static` metod `_runProcessImportData` a `_runBuildProfileMap` — ty nemají ve scope `onProgress`, `db` ani `this`.

### Přidáno

- **`DbInitializer`** (`lib/logic/db/db_initializer.dart`): Nová třída pro proaktivní inicializaci databáze při startu aplikace. Zkontroluje existenci `.db` souboru a zaloguje stav (`Nalezena existující` / `Vytvářím novou`). Spouštěna z `AppShell.initState()` — nikoliv z `main()`, aby nedocházelo k uváznutí (deadlock) způsobenému voláním platform channels před plným spuštěním Flutter engine.

---

## [0.5.7] - 2026-03-01

#### Opraveno
- **Chybějící tabulka `profily` (DB v9)**: Při startu aplikace docházelo k pádu s chybou `no such table: profily`. Tabulka pro mapovací profily nebyla zahrnuta ve schématu databáze ani v migracích. Přidána do `_createSchema` i do `_upgradeSchema`.
- **Chybějící sloupce `aliases` a `keywords` (DB v10)**: Tabulka `customer_profiles` neobsahovala sloupce `aliases` a `keywords`, přestože model `CustomerProfile` i tab správy profilů s nimi plně pracoval. Ukládání zákaznických profilů z UI proto vždy selhávalo. Sloupce přidány do schématu a migrace.
- **Odpojení profilu zákazníka při reimportu**: Každý reimport zákazníků vygeneroval nový `customer_profile_uid` a přepsal stávající hodnotu v tabulce `zakaznici`, čímž bylo přetrháno napojení na nakonfigurovaný profil. Opraveno zachováním existujícího UID při aktualizaci záznamu.
- **Read-only mapa ze SQLite (`UnsupportedError`)**: `WorkflowController.confirmCustomer()` se pokoušel zapsat `customer_profile_uid` přímo do mapy vrácené SQLite, která je neměnná. Opraveno vytvořením mutable kopie (`Map.from()`) při přiřazení do `assignedCustomer`.

---

## [0.5.5] - 2026-02-26

#### Přidáno
- **Hierarchický Resolver Profilů (`MappingProfileResolver`)**: Nová samostatná vrstva, která čistě a logicky určuje prioritu mapovacích profilů: 1. Explicitní profil zákazníka, 2. Profil od AI matcheru, 3. Historický profil zákazníka, 4. Výchozí systémový profil.
- **Trasování původu mapování (`source`)**: Algoritmy (`SmartMappingEngine`) a modely nyní přesně evidují, z jakého zdroje dané mapování pochází.
- **Vizuální štítky (Badges)**: V dialogu kontroly mapování (`MappingReviewDialog`) byly přidány barevné štítky, které uživateli jasně ukazují, zda sloupec namapoval uložený profil, chytrá heuristika nebo jde o manuální zadání.
- **Dynamický stav načítání**: Průvodce importem při načítání mapování nově jasně textově komunikuje, jaký typ profilu se právě aplikuje (např. "Používám poslední profil zákazníka.").

#### Změněno
- **Automatické přeskakování (Auto-Apply)**: Zásadní zlepšení UX! Pokud systém s jistotou detekuje zákazníka a nalezne jeho existující mapovací profil, rovnou jej aplikuje a přeskočí zdržující dialog kontroly mapování. Dialog se nyní otevře pouze u zcela nových zákazníků (fallback na výchozí profil).
- **Refaktorizace `WorkflowController`**: Odstraněn nepřehledný "špagetový" kód pro vyhodnocování profilů. Logika je nyní delegována na čistý objektový přístup pomocí nového resolveru.
- **Kanonická normalizace klíčových slov**: Při potvrzení mapování v dialogu se nyní automaticky generují tzv. kanonická mapování, která propojují surový název sloupce s jeho normalizovanou formou (bez diakritiky atd.), čímž se zvyšuje robustnost při budoucích importech.

## [0.5.4] - 2026-02-26

#### Přidáno
- **Smart Upsert Zákazníků (DB v7)**: Zaveden stabilní `customer_unique_key`. Původní metoda mazání a nahrazování dat ("wipe and replace") při importu hlavního ceníku z CRM byla nahrazena chytrým batch upsertem. Nyní se záznamy pouze doplňují či aktualizují.

#### Změněno
- **Výkonnostní revoluce v AI Matcheru**: Modul `CustomerMatcher` byl kompletně přepsán na používání jednorázové in-memory mezipaměti (cache). Odstraněním tisíců zbytečných SQL dotazů v cyklech došlo k extrémnímu zrychlení párovacího procesu i u těch největších importů.
- **Plynulý Editor Profilů (`CustomerProfilesTab`)**: Opraveno masivní zasekávání UI, které způsoboval Dropdown s 5000+ zákazníky. Plné načítání bylo nahrazeno efektivním vyhledávacím polem se stránkováním (pagination) a zpožděním dotazu (debouncing).
- **Dynamické Isolates (Smart Threads)**: Parsování a přesuny výpočtů do vláken na pozadí v `DbService` se nyní aktivují chytře – až po překročení objemové hranice (2000 řádků). Běžné menší dotazy se tak vyřídí bleskově v hlavním vlákně bez systémového zdržení (overhead).
- **Chytré SQL vyhledávání**: Metoda `getZakaznici` nově detekuje, zda uživatel hledá číselný identifikátor (IČ/ID) a aplikuje efektivnější prefixové hledání. Rozhraní `IngestionView` zároveň optimalizuje dotazy a ignoruje hledání kratší než 2 znaky.

## [0.5.3] - 2026-02-26

#### Přidáno
- **Správa zákaznických profilů**: Plně funkční záložka `CustomerProfilesTab` pro vytváření, editaci a mazání individuálních mapovacích profilů pro konkrétní zákazníky.
- **Smart Mapping Review**: Do průvodce importem (`IngestionView`) byl přidán mezikrok, který po identifikaci firmy zobrazí dialog s návrhem mapování sloupců na základě uložených zvyklostí zákazníka. Jakákoliv úprava se rovnou uloží zpět do jeho profilu.
- **Rozšířená AI identifikace**: Modul `CustomerMatcher` nyní využívá databázové profily k přesnější identifikaci. Porovnává nejen IČO a název, ale i definované aliasy a vážená klíčová slova uložená v databázi.
- **Stabilní UID**: Každý zákazník a jeho profil jsou nyní pevně svázáni pomocí `customer_profile_uid`, což zabraňuje rozpadu vazeb při opakovaných importech hlavního seznamu firem.

#### Změněno
- **Optimalizace výkonu UI (Isolates)**: Výpočetně náročné parsování rozsáhlých databázových odpovědí (např. 10 000 zákazníků) v `DbService` bylo přesunuto do vláken v pozadí pomocí `Isolate.run()`. UI aplikace tak zůstává perfektně plynulé (bez tzv. Jitteru).
- **Zrychlení hromadného importu**: Proces přidělování a generování unikátních klíčů pro nová i existující data je plně oddelegován na vlákna v pozadí.
- **Smart Dropdown v Profilech**: Rozevírací seznam zákazníků v editoru profilů byl přepsán z plného načtení (které způsobovalo mrznutí) na vyhledávací `TextField` kombinovaný s dynamicky filtrovaným Dropdownem. Výrazné snížení zátěže na renderování ve Flutteru.
- **Rozšířené Workflow**: Zásadně přepracován `WorkflowController` – nově umí pracovat s pozastavením pro ověření mapování (`isMappingPending`) a asynchronně načítat historická mapování při výběru zákazníka.

#### Opraveno
- **Smazání profilu (Typová chyba)**: Opraven pád aplikace při pokusu o smazání profilu zákazníka, kde docházelo k chybnému předání typu `int` (z `active.id`) do parametru požadujícího `String` (`profileUid`).
- **Obnova diagnostiky**: Vráceny chybějící metody `getOperaceCount` a `getMaterialyCount` do `DbService`, které se při integraci asynchronního kódu ztratily a způsobovaly rozbití `DbStatusTab`.

## [0.5.2] - 2026-02-25

#### Změněno
- **Redesign tabulky Editor Objednávek**: Kompletní přepracování řádků položek v `OrderEditorView`. Barevné odznaky typů souborů (PDF/DXF/STEP/IMG) nahrazeny neutrálními bílými ikonami s Tooltipem. Výchozí pozadí řádku je průhledné, při hover se jemně podbarvuje (white/2 %) – shodně s tabulkami Materiály, Operace a Pipeline.
- **Redesign tabulky Editor Nabídek**: Stejné úpravy aplikovány do `OfferEditorView`. Odstraněny barevné chipy pro Materiál (oranžová) a Operace (fialová), nahrazeny neutrálním bílým textem a stylem. Logika hover stavu extrahována do samostatného `_OfferTableRow` StatefulWidget.
- **Červené podbarvení řádku při mazání**: V obou editorech (nabídky i objednávky) se řádek jemně červeně podbarvuje (`redAccent/6 %`) při najetí myší na tlačítko Smazat, čímž vizuálně signalizuje destruktivní akci.
- **Kompaktnější Dropzone**: Výška spodní dokumentační lišty v editorech snížena (padding `vertical: 28 → 14` ve sbaleném stavu). Přidán vertikální mezera 16 px mezi tabulkou položek a Dropzone pro lepší vizuální oddělení.
- **Sjednocení oddělovačů**: Řádky tabulky objednávek a nabídek nyní používají plno-šířkové `Divider` shodné s ostatními tabulkami v aplikaci. Odstraněny zaoblené rohy z dekorace řádků.
- **Oprava přetékání IconButton**: Tlačítka Upravit a Smazat v editorech nyní mají `constraints: const BoxConstraints()` a kompaktní `padding: EdgeInsets.all(6)`, čímž se eliminuje min. výška 48 px a zamezuje přetečení v pevně daných `SizedBox` kontejnerech.

#### Opraveno
- **Přetékání Header Wizardu (IngestionView)**: Řádek s doporučenými hlavičkovými řádky ("DOPORUČENÉ ŘÁDKY") přepnut z `Row` na `Wrap` – při větším počtu kandidátů se chipy zalamují místo přetečení mimo obrazovku.
- **Deprecated `withOpacity()` (IngestionView)**: Všechna volání `.withOpacity()` v `ingestion_view.dart` nahrazena moderním `.withValues(alpha:)` (18 výskytů), včetně dynamických výrazů s animovanými hodnotami.

## [0.5.1] - 2026-02-25

#### Přidáno
- **Nativní Drag & Drop**: Do editorů nabídek a objednávek implementována knihovna `desktop_drop` pro přímé přetahování souborů z operačního systému.
- **Indikátory výkresů v řádku**: Do tabulky položek přidány dynamické ikonky pro zobrazení stavu připojených výkresů (PDF, DXF, STEP, IMG) s interaktivním Tooltipem.

#### Změněno
- **Zjednodušení Sidebaru a Routingu**: Odstraněna celá sekce "ZPRACOVÁNÍ". Moduly *Párování výkresů*, *Validace dat* a *Export do CRM* byly zrušeny jako samostatná okna – jejich logika se nyní bude odehrávat plně na pozadí přímo v Editoru.
- **Dostupnost menu**: Položky *Pipeline zakázek*, *Mapovací profily* a *Nastavení* jsou v Sidebaru nově dostupné vždy, nezávisle na stavu rozečtených dat.
- **Kompaktní Dropzone**: Změněn layout spodní dokumentační lišty v editorech, přidán scrollovatelný `Wrap` pro zobrazení velkého množství přiložených souborů na více řádcích.
- **UX Tabulky**: Akční tlačítka (Upravit, Smazat) na konci řádků dostala hover efekty a nápovědné Tooltipy. Spolu s indikátory výkresů byla sjednocena k pravému okraji pro čistší vizuál.

## [0.5.0] - 2026-02-25

#### Přidáno
- **Interaktivní Dropzone pro dokumentaci**: Spodní lišta v editorech nabídek a objednávek nyní plně podporuje Drag & Drop. Při přetažení souboru se animovaně rozbalí.
- **Správa souborů**: K souborům v dokumentační liště přidán hover efekt s možností rychlého smazání souboru.

#### Změněno
- **Sjednocení UI Editorů (Data Grid)**: Kompletní redesign `OrderEditorView` a `OfferEditorView`. Seznam položek k výrobě nyní využívá stejný celostránkový tabulkový vzor (Data Grid) jako Pipeline, Operace a Materiály.
- **Optimalizace Layoutu Editorů**: Rozložení obrazovek upraveno do tří vrstev: 1. kompaktní hlavička (formulář a souhrn se stejnou výškou díky `IntrinsicHeight`), 2. full-width tabulka položek, 3. fixní spodní lišta pro dokumentaci.

## [0.4.9] - 2026-02-25

#### Přidáno
- **Modul Pipeline zakázek (UI Preview)**: Nová záložka v sekci "SPRÁVA" pro vizuální přehled nad stavem importovaných nabídek a objednávek (Fáze: K řešení, K potvrzení, Hotovo).
- **Stavový model a filtrace**: Implementován mockovaný datový model včetně dynamických záložek pro rychlé filtrování seznamu objednávek podle jejich fáze.

#### Změněno
- **Konzistence UX ("Data Grid")**: Vzhled Pipeline zakázek byl sjednocen do tabulkového, čistě technického zobrazení, odpovídajícího stávajícímu rozhraní (Materiály, Operace).
- **Úprava navigace**: Reorganizace hlavního postranního panelu (Sidebar). Přidána sekce "SPRÁVA" a systémové položky (Profily, Nastavení) byly posunuty.

## [0.4.8] - 2026-02-25

#### Přidáno
- **Persistentní Mapovací Profily**: Mapovací profily pro import se nyní ukládají přímo do SQLite databáze (přidána tabulka `profily` v DbService v5), což zajišťuje jejich trvalé uchování.
- **Zabezpečený Systémový Profil**: Implementován pevně zakódovaný "Základní Import (Systémový)" profil. Tento profil funguje jako záchytný bod a nelze jej z aplikace smazat ani přejmenovat.
- **JSON Serializace**: Přidána plná podpora převodu konfiguračních slovníků do formátu JSON pro flexibilní ukládání do databáze.

#### Změněno
- **Workflow Controller**: Přepracována správa profilů na asynchronní operace. Profily se načítají z databáze při startu aplikace a ukládají se bez blokování uživatelského rozhraní.
- **Profiles Editor UI**: Aktualizováno uživatelské rozhraní mapovacích profilů. Přidány bezpečnostní zámky chránící systémový profil před úpravami názvu a smazáním (ikony zámku a štítu).

## [0.4.7] - 2026-02-25

#### Přidáno
- **Smart Material Suggester**: Implementováno automatické napovídání materiálů v editorech nabídek a objednávek na základě klíčových slov a aliasů z katalogu materiálů (propojení s `DbService` a modulem z v0.4.2).   
- **Auto-Link Attachments**: Systém nyní automaticky páruje nalezené výkresy (.pdf, .step) k řádkům importované tabulky na základě shody názvu souboru a čísla pozice nebo názvu dílu.
- **Validation Export**: Přidána možnost exportu validačního protokolu do formátu PDF v pohledu `DataValidatorView`, shrnující chyby v integritě dat před exportem do CRM.
- **Batch Folder Action**: V seznamu zákazníků doplněna funkce pro hromadné vytvoření chybějící adresářové struktury v TECH a OFFER kořenech (využívá `FolderValidator` z v0.4.3).

#### Změněno
- **Enhanced Header Intelligence**: Algoritmus v `ExcelHeaderDetector` byl rozšířen o analýzu datových typů v následujících řádcích (Look-ahead bonus), což zvyšuje úspěšnost detekce u nestandardních exportů.
- **UI Performance Boost**: Optimalizováno vykreslování rozsáhlých tabulek v `IngestionView` pomocí `RepaintBoundary` a vylepšené synchronizace horizontálního a vertikálního scrollu.
- **Mapping Profiles Extension**: Profily nyní umožňují definovat i výchozí jednotky a automatické transformace (např. převod tloušťky materiálu) přímo v `MappingProfilesView`.

#### Opraveno
- **Session Cleanup Logic**: Opravena chyba v `IngestionService`, která při neočekávaném pádu aplikace zanechávala v dočasném sandboxu uzamčené soubory.
- **Scroll Sync Fix**: Vyřešeno odskakování tabulky při automatickém posunu na doporučené kandidáty hlaviček v průvodci importem.
- **Icon Set Unification**: Sjednoceny sady ikon napříč celou aplikací (Ingestion, Dispatcher, Sidebar) pro zajištění vizuální konzistence "Flat & Technical" designu.

## [0.4.6] - 2026-02-24

### Přidáno
- **Smart Header Candidates**: Průvodce importem nyní automaticky nabízí "Top 3" nejpravděpodobnější řádky s hlavičkou včetně procentuální shody.
- **Visual Heatmap**: Řádky v tabulce ověření struktury jsou barevně podbarveny (Zelená/Oranžová) podle míry shody s klíčovými slovy.
- **Mapping Profiles**: Nový konfigurační modul umožňující definovat vlastní sady klíčových slov pro detekci sloupců (např. pro různé jazykové mutace nebo exporty ze SAP).
- **Ghosting Effect**: Řádky nad vybranou hlavičkou jsou nyní vizuálně potlačeny (poloprůhledné), aby bylo zřejmé, že jde o ignorovaná metadata.
- **Auto-Scroll**: Automatický posun tabulky na nejlepší nalezený řádek při otevření wizardu.

### Změněno
- **Detection Logic**: Detektor hlaviček nyní počítá normalizované skóre důvěryhodnosti (Confidence Score) a přijímá dynamická klíčová slova z aktivního profilu.
- **Workflow Controller**: Integrována správa mapovacích profilů přímo do logiky analýzy souborů.
- **Ingestion UI**: Přepracován wizard pro ověření struktury – přidány čipy pro rychlý výběr kandidátů a vertikální scroll controller.

## [0.4.5] - 2026-02-15

### Přidáno
- **Sidebar State Matrix**: Implementován systém reaktivních stavů pro navigaci. Každá položka nyní dynamicky mění barvu, ikonu a indikátory (OK / Chyba / Proces) na základě povelů z Workflow.
- **Security Interaction Lock**: Přidána fyzická ochrana proti nechtěné manipulaci. IngestionView se po výběru režimu (Nabídka/Objednávka) automaticky uzamkne pomocí `AbsorbPointer`.
- **Session Sandbox Isolation**: IngestionService nyní vytváří unikátní časově razítkované složky pro každou relaci, čímž eliminuje kolize souborů při vícenásobných importech.
- **Manual File Picker**: Přidána metoda `pickFromDisk` umožňující klasický výběr souborů přes systémové okno jako alternativu k Drag & Drop.

### Změněno
- **Workflow Centralization**: Logika zámků a stavu "Zaneprázdněn" (isProcessing) byla přesunuta z UI vrstvy přímo do `WorkflowController`.
- **Sidebar UX**: Položka "Drop Zone" po aktivaci editoru vizuálně zešedne (Disabled State) a zobrazí bezpečnostní zámek, aby nedošlo k přepsání rozpracovaných dat.
- **Ingestion Reporting**: Notifikační systém nyní inteligentně rozlišuje mezi čistým importem (Zelená) a importem s neznámými soubory (Oranžová - Ignored).

### Opraveno
- **Editor Dispatcher**: Opraven pád při přepínání režimů a zajištěn korektní globální reset aplikace (vyčištění paměti a sandboxu).
- **Navigation Sync**: Opraven nesoulad mezi stavem Sidebar položek a aktivním zobrazením v AppShellu.
- **Async Safety**: Ošetřeno volání notifikací po dokončení asynchronních operací (mounted check).

## [0.4.4] - 2026-02-14

### Přidáno
- **Workflow Controller**: Implementován centrální Singleton pro řízení stavu aplikace a zamykání procesních kroků.
- **Smart Unpack**: Automatická extrakce .zip a .rar archivů do dočasného úložiště relace s následnou analýzou obsahu.
- **Editor Dispatcher**: Dynamický rozcestník v produkční sekci, který přepíná mezi editorem Nabídek a Objednávek.
- **Offer & Order Editors**: Kompletní UI pro redakci dokumentů s rozděleným layoutem (3:1) a vazbou na Ingesci.
- **Pulsing Status Indicators**: Vizuální dýchající indikátory pro aktivní procesní kroky v Sidebaru.

### Změněno
- **Workflow Locking**: Implementována lineární progrese – Drop Zone se po úspěšném importu uzamkne (včetně zeleného checku) a aktivuje se Editor.
- **Ingestion Summary**: Statistiky po importu nyní filtrují archivy a zobrazují pouze reálný počet extrahovaných souborů (.pdf, .step, atd.).
- **AppShell Router**: Sjednoceny indexy navigace (0-6) a implementováno reaktivní překreslování Sidebaru.

### Opraveno
- **Namespace fix**: Vyřešen konflikt metod u balíčku `path` (přidán alias `p`).
- **Constructor fix**: Opraveno předávání callbacků a pojmenovaných parametrů (`onSuccess`) v IngestionView.
- **Sidebar UI**: Opraveno přetékání textu u dlouhých názvů modulů v navigaci.

## [0.4.3] - 2026-02-14

### Přidáno
- **Validace složek zákazníků (T/N)**: Zobrazení stavových teček ověřujících existenci složek pro technickou dokumentaci a nabídky.
- **FolderValidator**: Nový pomocný modul pro kontrolu existence zákaznických složek na základě uložených root cest (SharedPreferences).
- **DbStatus rozšíření**: Do diagnostiky přidány počty definic pro *Výrobní operace* a *Katalog materiálů*.

### Změněno
- **DbStatusTab**: Načítání diagnostických dat sjednoceno přes `Future.wait(...)` (včetně `getOperaceCount()` a `getMaterialyCount()`).
- **Operace (UI/Model)**: Odstraněno pole ceny/hodinové sazby z UI i logiky (systém eviduje pouze technologické informace).

### Opraveno
- Zpřesněna a zjednodušena prezentace stavu v UI (méně zavádějících indikátorů, jasnější diagnostické metriky).


## [0.4.2] - 2026-02-14

### Přidáno
- **Katalog Materiálů**: Nový modul pro správu materiálů s podporou hlavního označení a aliasů.
- **Thickness Manager**: Specializovaný dialog pro intuitivní správu tlouštěk materiálů (v mm) s podporou automatického třídění a mazání.
- **Databázové schéma v4**: Implementace tabulky `materialy` a optimalizačních indexů.

### Změněno
- **Vizuální sjednocení (Barevná identita)**: 
  - Zákazníci: **Modrá** (#4077D1)
  - Materiály: **Oranžová** (#FF9F1C)
  - Operace: **Růžová/Fialová** (#E056FD)
- **Redesign Customer List**: 
  - Identifikace zákazníka (Název, IČ, ID) sjednocena do kompaktního modrého panelu.
  - Cesta ke složce přepracována na přímý textový input pro manuální vkládání cest.
- **UX Optimalizace**: Odstraněna tlačítka pro průzkumníka souborů u zákazníků pro maximální rychlost manuálního vkládání.

### Opraveno
- Opravena chyba `List<Widget>` v komponentě Wrap u materiálů.
- Vyřešeny chybějící metody v `MaterialsListTabState` a opraveny importy notifikací.

## [0.4.1] - 2026-02-14

### Přidáno
- **Modul Výrobní operace**: Nová záložka v nastavení pro správu číselníku operací (CRUD).
- **Editace operací**: Implementován dialog pro vytváření a úpravu operací (Kód, Název, Poznámka).
- **Databázové schéma v3**: Přidána tabulka `operace` s indexací pro rychlé vyhledávání.

### Změněno
- **DB Migrace**: Automatická migrace databáze z v2 na v3 při startu aplikace.
- **SettingsView**: Do navigace nastavení přidána 4. záložka "Výrobní Operace".
- **Data Model**: Na základě zpětné vazby odstraněno pole `cena_hodina` z modelu operací – systém eviduje pouze technologické parametry.

### Opraveno
- Zajištěna konzistence UI ("Flat & Technical" design) i pro novou záložku operací (použití fialové akcentní barvy pro odlišení).

## [0.4.0] - 2026-02-14

### Přidáno
- **Ingestion Engine (Drop Zone)**: Implementována obrazovka pro Drag & Drop souborů s detekcí formátů (.xlsx, .pdf, .dxf, .step).
- **Smart Unpack Logic**: Přidána podpora pro archivy (.zip) – systém je umí přijmout a připravit k rozbalení.
- **Universal Notifications**: Centrální notifikační systém (`Notifications` class) s "Glassmorphism" designem pro Toasty a Progress bary.
- **System Manifest**: Nová záložka v nastavení zobrazující verze jednotlivých modulů a zdraví systému.
- **Search Debounce**: Přidáno 500ms zpoždění při vyhledávání zákazníků pro optimalizaci databázových dotazů.

### Změněno
- **Design System Overhaul**: Kompletní přechod na "Flat & Technical" vzhled (barvy #0F1115, #16181D, technické fonty, hranatější rohy).
- **Import Logic**: Refaktorováno na použití `Isolate` (výpočet na pozadí) + `Batch Transactions` pro zápis do DB.
- **Visual Feedback**: Import nyní ukazuje detailní progress bar (fáze analýzy vs. fáze zápisu).
- **Customer List**: Data z DB jsou nyní konvertována na `mutable`, což opravilo pád aplikace při editaci cesty ke složce.
- **General Settings**: Sjednocen vzhled přepínačů a cest s novým designem.

### Opraveno
- Opravena chyba `read-only` při pokusu o přiřazení složky zákazníkovi v seznamu.
- Opraveno volání `Notifications.showProgress` s chybějícími pojmenovanými parametry.
- Odstraněny staré závislosti na `SettingsHelpers` v `DbStatusTab` a `GeneralSettingsTab`.

## [0.3.2] - 2026-02-13

### Přidáno
- **Nová architektura navigace**: Implementován rozšířený Sidebar s 8 sekcemi (Drop Zone, Nabídky, Objednávky, Párování, atd.).
- **Skeleton obrazovky**: Vytvořeny prázdné pohledy (placeholder views) pro všechny nové moduly, připravené pro budoucí logiku.
- **Hlavička aplikace**: Do postranního panelu přidána sekce s názvem "MRB BRIDGE" a číslem verze.

### Změněno
- **Rebranding**: Aplikace přejmenována na **"MRB Data Bridge"** (z původního MRB Obchodník) pro lepší vystižení ETL funkce.
- Kompletní reorganizace souborové struktury pohledů (`views/ingestion`, `views/production`, `views/tools`...).
- Aktualizována routovací logika v `main.dart` pro přepínání mezi novými moduly.

### Opraveno
- Vyřešeny konflikty názvů tříd mezi `Sidebar` a `AppSidebar` v hlavním souboru.
- Doplněny chybějící importy pro `window_manager` a `flutter/foundation`.

## [0.3.1] - 2026-02-12

### Přidáno
- Do obecných nastavení přidána volba "Interval kontroly dat" (možnosti: týden, 14 dní, měsíc).

### Změněno
- Upravena logika `DbStatusTab`: pokud jsou data starší než nastavený interval, indikátor se změní na oranžovou (varování).

## [0.3.0] - 2026-02-12

### Přidáno
- Implementována sekce "Archivní systém" v General Settings.
- Přidána možnost nastavení cesty pro Technickou dokumentaci a Obchodní nabídky.
- Nový systém persistence nastavení pomocí SharedPreferences (ukládání cest a preferencí).
- Implementován asynchronní import pomocí Isolates (výpočet v separátním vlákně), který zabraňuje zamrzání UI.
- Přidán indikátor "DISTINCT" pro přesné počítání unikátních zákazníků v DB.

### Změněno
- Redesign DbStatusTab: Implementován 3-stavový barevný semafor (Zelená/Oranžová/Červená).
- Redesign CustomerListTab: Zaveden Infinite Scroll (stránkování po 50 záznamech) pro bleskovou odezvu při 14k+ záznamech.
- Vylepšen ImportLogic: Nyní automaticky zpracovává pouze první list Excelu, čímž eliminuje duplikaci dat.
- Sjednocen vizuální styl všech karet nastavení do formátu "Flat-Glass Panel".

### Opraveno
- Vyřešena kritická chyba duplikace dat při importu (nárůst z 14k na 217k záznamů).
- Opraveno parsování CellValue z knihovny Excel, které způsobovalo prázdné záznamy v DB.
- Odstraněno nekonečné obnovování UI (Infinite Refresh Loop) ve FutureBuilderu u stavu databáze.
- Opraveno zalamování a formátování ISO datumu na lidsky čitelný formát (intl).

## [0.2.0] - 2026-02-11

### Přidáno
- Nový VS/Fluent-lite design systém pro SettingsView.
- Subtle glass komponenta `_glassPanel` pro jednotný vzhled panelů.
- Nový glass import dialog s progres barem.
- Reusable primární tlačítko `_primaryButton`.
- Flat VS-like chip komponenta pro filtry.
- Nový subtilní pulzující indikátor stavu databáze.

### Změněno
- Kompletní redesign panelu „Stav databáze“.
- Přepsán layout sekce „Databáze zákazníků“ do jednotného grid systému.
- Sidebar přepracován do lehkého glass stylu s průhledností.
- Upraveno zarovnání hlaviček a sloupců tabulky.
- Upravená typografie zákazníka (méně agresivní, více VS-like).
- Sjednocen styl tlačítek do jednoduchého modrého flat designu.
- Vylepšeno chování výběru řádků (jemná modrá indikace).

### Opraveno
- Vyřešen konflikt jména `Border` mezi balíčky Flutter a Excel.
- Opravené přetékání layoutu pomocí správného použití `Expanded` a `SingleChildScrollView`.
- Opravené nesoulady zarovnání mezi hlavičkou a řádky tabulky.


## [0.1.1] - 2026-02-11

### Přidáno
- Implementována metoda `getRowCount` v `DbService` pro přesné ověření obsahu SQLite databáze.
- Do diagnostiky přidáno zobrazení reálného počtu nahraných záznamů.

### Změněno
- Kompletní redesign diagnostického panelu v nastavení: integrována barevná indikace (zelená/oranžová/červená) a akční tlačítko do jedné přehledné karty.
- Změněno uspořádání prvků v `SettingsView` pro lepší čitelnost a eliminaci mizejících tlačítek.

### Opraveno
- Opravena chyba neexistující ikony `database_outlined` (nahrazeno za `storage_rounded`).
- Vyřešen chybějící import pro `debugPrint` v databázové službě.
- Opraveno přetékání layoutu pomocí `SingleChildScrollView` a `ListView`.
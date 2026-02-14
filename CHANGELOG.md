# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog
and this project adheres to Semantic Versioning.

---

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
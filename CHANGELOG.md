# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog
and this project adheres to Semantic Versioning.

---
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
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
# MRB Obchodník (CRM 2026) 🚀

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![SQLite](https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)

**MRB Obchodník** je vysoce výkonná desktopová CRM aplikace postavená na frameworku Flutter. Je navržena pro bleskovou správu tisíců obchodních partnerů, jejich dokumentace a nabídek s důrazem na moderní **Flat-Glass design** a maximální odezvu systému.



## ✨ Klíčové vlastnosti

- 🏎️ **Extrémní výkon**: Optimalizované SQLite jádro s indexy pro okamžité vyhledávání v 15.000+ záznamech.
- 💎 **Hybrid Glass UI**: Moderní uživatelské rozhraní inspirované Fluent Designem a VS Code.
- 📂 **Archivní systém**: Inteligentní správa cest k technické dokumentaci a obchodním nabídkám.
- ⚡ **Isolate-driven Import**: Import dat z Excelu běží v separátním vlákně (Isolate), takže aplikace nikdy nezamrzne.
- 📊 **Stavová diagnostika**: Real-time přehled o integritě databáze a historii synchronizace.
- 🔄 **Infinite Scroll**: Stránkované načítání seznamu zákazníků pro minimální nároky na paměť.



## 🛠️ Technické specifikace

- **Frontend**: Flutter (Dart)
- **Databáze**: SQLite 3 (přes `sqflite_ffi`)
- **Parsování**: `excel` package s optimalizovaným Isolate procesem
- **Persistence**: `shared_preferences` pro uživatelská nastavení
- **Architektura**: Singleton služby a reactive ValueNotifiers

## 📦 Instalace a vývoj

### Požadavky
- Flutter SDK (3.x a novější)
- Dart SDK
- SQLite knihovny (pro Windows/Linux)

### Spuštění projektu
1. Naklonujte repozitář:
   ```bash
   git clone [https://github.com/vase-jmeno/mrb_obchodnik.git](https://github.com/vase-jmeno/mrb_obchodnik.git)
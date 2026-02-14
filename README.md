# MRB Obchodník (Data Bridge 2026) 🚀

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![SQLite](https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)

MRB Obchodník je vysoce výkonná desktopová aplikace sloužící jako inteligentní most (Data Bridge) mezi podnikovými daty z Excelu, archivem technické dokumentace a CRM systémem. Je navržena pro bleskovou správu tisíců záznamů s důrazem na technickou preciznost a moderní Flat-Glass design.

---

## ✨ Klíčové vlastnosti (v0.4.2)

### 🔵 Správa Zákazníků (Core)

- **Bleskové vyhledávání:** Optimalizované SQLite jádro (Schema v4) pro okamžité filtrování v 15 000+ záznamech.
    
- **Validace archivů:** Inteligentní pulzující indikátory (Glow Dots) ověřují v reálném čase existenci složek v technické dokumentaci (T) a obchodních nabídkách (N).
    
- **Efektivní input:** Manuální vkládání cest s automatickou validací focusu pro maximální rychlost zápisu.
    

### 🟠 Katalog Materiálů (MAT)

- **Kompletní číselník:** Evidence materiálů, jejich aliasů a alternativních označení.
    
- **Thickness Manager:** Integrovaný editor tlouštěk (mm) s automatickým tříděním a vizuální správou pomocí čipů.
    

### 🟣 Výrobní Operace (OPS)

- **Technologický registr:** Správa výrobních operací a kódů bez nutnosti složité cenotvorby, zaměřená na procesní čistotu.
    

---

## ⚡ Technické jádro

- **Isolate-driven Import:** Asynchronní zpracování masivních Excel souborů bez blokování uživatelského rozhraní.
    
- **System Manifest:** Modulární registr verzí sledující stav dokončení jednotlivých částí systému.
    

---

## 🎨 Vizuální identita (Design System)

Aplikace využívá přísně definovaný barevný systém pro rychlou orientaci uživatele:

- **Modrá (#4077D1):** Klientská data a jádro systému.
    
- **Oranžová (#FF9F1C):** Materiály a skladové entity.
    
- **Fialová (#E056FD):** Výrobní procesy a operace.
    
- **Zelená / Červená:** Dynamické stavy a validace fyzických cest na disku.
    

---

## 🛠️ Technické specifikace

- **Frontend:** Flutter 3.x (Desktop)
    
- **Databáze:** SQLite 3 (v4 migration enabled) přes sqflite_ffi
    
- **Architektura:** Singleton Service Pattern s reaktivními ValueNotifiers
    
- **Validace:** dart:io asynchronní file-system check
    
- **Persistence:** shared_preferences (globální nastavení a root cesty)
    

---

## 📦 Instalace a vývoj

### Požadavky

- Flutter SDK (3.x a novější)
    
- C++ Redistributable (pro SQLite FFI na Windows)
    

### Spuštění projektu

#### 1. Naklonujte repozitář

```bash
git clone https://github.com/mrb-obchodnik.git
```

#### 2. Nainstalujte závislosti

```bash
flutter pub get
```

#### 3. Spusťte aplikaci

```bash
flutter run -d windows
```

---

## 📅 Roadmap 2026

-  Základní DB a Ingestion Engine
    
-  Katalog materiálů a operací
    
-  Validace diskových archivů
    
-  Inteligentní AI mapování položek z Excelu (v přípravě)
    
-  Exportní modul pro PDF nabídky
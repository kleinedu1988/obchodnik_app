import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mrb_obchodnik/logic/notifications.dart';

// --- MOCK DATOVÝ MODEL (Pouze pro UI) ---
enum MockOrderState {
  nova,
  ceka_na_nakup,
  ceka_na_zakaznika,
  pripraveno,
  potvrzeno,
  zruseno
}

class MockOrder {
  final String id;
  final String cisloObjednavky;
  final String nazevZakaznika;
  MockOrderState stav;
  final String datum;

  MockOrder({
    required this.id,
    required this.cisloObjednavky,
    required this.nazevZakaznika,
    required this.stav,
    required this.datum,
  });
}

class OrderPipelineView extends StatefulWidget {
  const OrderPipelineView({super.key});

  @override
  State<OrderPipelineView> createState() => _OrderPipelineViewState();
}

class _OrderPipelineViewState extends State<OrderPipelineView> {
  // --- FALEŠNÁ DATA PRO LADĚNÍ UI ---
  final List<MockOrder> _orders = [
    MockOrder(id: "1", cisloObjednavky: "OBJ-2026-001", nazevZakaznika: "Kovovýroba Novák s.r.o.", stav: MockOrderState.nova, datum: "25.02.2026"),
    MockOrder(id: "2", cisloObjednavky: "OBJ-2026-002", nazevZakaznika: "Auto-Tech a.s.", stav: MockOrderState.ceka_na_nakup, datum: "24.02.2026"),
    MockOrder(id: "3", cisloObjednavky: "OBJ-2026-003", nazevZakaznika: "Stavby Zlín", stav: MockOrderState.ceka_na_zakaznika, datum: "23.02.2026"),
    MockOrder(id: "4", cisloObjednavky: "OBJ-2026-004", nazevZakaznika: "Agro CZ", stav: MockOrderState.pripraveno, datum: "22.02.2026"),
    MockOrder(id: "5", cisloObjednavky: "OBJ-2026-005", nazevZakaznika: "Zámečnictví Dvořák", stav: MockOrderState.potvrzeno, datum: "20.02.2026"),
    MockOrder(id: "6", cisloObjednavky: "OBJ-2026-006", nazevZakaznika: "Strojírny Brno", stav: MockOrderState.zruseno, datum: "18.02.2026"),
  ];

  // --- STAV FILTRŮ ---
  Timer? _debounce;
  String _query = '';
  int _selectedFilterIndex = 0; // 0=K Řešení, 1=K Potvrzení, 2=Hotovo, 3=Vše

  // --- DESIGN KONSTANTY ---
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;
  
  static const Color _colorPrimary = Color(0xFF4077D1);
  static const Color _colorOrange = Color(0xFFFF9F1C);
  static const Color _colorGreen = Color(0xFF2E8B57);
  static const Color _colorRed = Color(0xFFD14040);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // --- LOKÁLNÍ LOGIKA (bez databáze) ---
  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _query = val.toLowerCase());
    });
  }

  void _zmenitStav(MockOrder order, MockOrderState novyStav) {
    setState(() {
      order.stav = novyStav;
    });
  }

  void _odeslatPotvrzeniMock(MockOrder order) {
    // Pouze simulace odeslání pro testování UI
    _zmenitStav(order, MockOrderState.potvrzeno);
    Notifications.showSuccess(context, "SIMULACE: E-mail odeslán");
  }

  List<MockOrder> get _filteredOrders {
    var filtered = _orders.where((o) {
      // 1. Textové hledání
      if (_query.isNotEmpty) {
        if (!o.cisloObjednavky.toLowerCase().contains(_query) &&
            !o.nazevZakaznika.toLowerCase().contains(_query)) {
          return false;
        }
      }
      
      // 2. Stavové záložky
      switch (_selectedFilterIndex) {
        case 0: return [MockOrderState.nova, MockOrderState.ceka_na_nakup, MockOrderState.ceka_na_zakaznika].contains(o.stav);
        case 1: return o.stav == MockOrderState.pripraveno;
        case 2: return [MockOrderState.potvrzeno, MockOrderState.zruseno].contains(o.stav);
        default: return true;
      }
    }).toList();
    
    return filtered;
  }

  // =========================================================================
  //  BUILD METHODY
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final list = _filteredOrders;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildControls(),
          const SizedBox(height: 24),
          _buildTableHeader(),
          
          Expanded(
            child: list.isEmpty 
              ? _buildEmptyState() 
              : _buildList(list),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        // 1) SEARCH BAR
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _borderColor),
            ),
            child: TextField(
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              cursorColor: _colorPrimary,
              decoration: const InputDecoration(
                hintText: "Hledat objednávku nebo zákazníka...",
                hintStyle: TextStyle(color: _textDim, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: _textDim),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        
        // 2) FILTRAČNÍ ZÁLOŽKY
        Container(
          height: 40,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTab(0, "K ŘEŠENÍ"),
              _buildTab(1, "K POTVRZENÍ"),
              _buildTab(2, "HOTOVO"),
              Container(width: 1, color: _borderColor, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
              _buildTab(3, "VŠE"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? _colorPrimary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _colorPrimary : Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor, width: 2)),
      ),
      child: Row(
        children: [
          _headerText("ČÍSLO OBJEDNÁVKY", flex: 2),
          _headerText("ZÁKAZNÍK", flex: 3),
          _headerText("DATUM", flex: 2),
          _headerText("STAV ZAKÁZKY", flex: 2),
          const SizedBox(width: 140), // Pevný prostor pro akce
        ],
      ),
    );
  }

  Widget _buildList(List<MockOrder> list) {
    return ListView.separated(
      itemCount: list.length,
      padding: const EdgeInsets.only(bottom: 80),
      separatorBuilder: (context, index) => const Divider(color: _borderColor, height: 1),
      itemBuilder: (context, index) => _buildOrderRow(list[index]),
    );
  }

  Widget _buildOrderRow(MockOrder order) {
    return InkWell(
      onTap: () {}, // Zde by se později otevíral detail
      hoverColor: Colors.white.withOpacity(0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 1. ČÍSLO
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _colorPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _colorPrimary.withOpacity(0.3)),
                  ),
                  child: Text(
                    order.cisloObjednavky,
                    style: const TextStyle(color: _colorPrimary, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
            
            // 2. ZÁKAZNÍK
            Expanded(
              flex: 3,
              child: Text(
                order.nazevZakaznika,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),

            // 3. DATUM
            Expanded(
              flex: 2,
              child: Text(
                order.datum,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ),

            // 4. STAV CHIP
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildStatusChip(order.stav),
              ),
            ),

            // 5. AKCE (IKONY NA PRAVÉ STRANĚ)
            SizedBox(
              width: 140,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _buildRowActions(order),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STAVY ---
  Widget _buildStatusChip(MockOrderState stav) {
    String text;
    Color color;
    IconData icon;

    switch (stav) {
      case MockOrderState.nova:
        text = "Nová"; color = Colors.white54; icon = Icons.fiber_new_rounded; break;
      case MockOrderState.ceka_na_nakup:
        text = "Čeká na nákup"; color = _colorOrange; icon = Icons.shopping_cart_checkout; break;
      case MockOrderState.ceka_na_zakaznika:
        text = "Čeká na zákazníka"; color = _colorRed; icon = Icons.warning_amber_rounded; break;
      case MockOrderState.pripraveno:
        text = "Připraveno"; color = _colorGreen; icon = Icons.inventory_rounded; break;
      case MockOrderState.potvrzeno:
        text = "Potvrzeno"; color = _colorPrimary; icon = Icons.done_all_rounded; break;
      case MockOrderState.zruseno:
        text = "Zrušeno"; color = Colors.white24; icon = Icons.cancel_rounded; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- IKONOVÉ AKCE NA KONCI ŘÁDKU ---
  List<Widget> _buildRowActions(MockOrder order) {
    if (order.stav == MockOrderState.potvrzeno || order.stav == MockOrderState.zruseno) {
      return [
        IconButton(
          onPressed: () => _zmenitStav(order, MockOrderState.nova), 
          icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
          color: Colors.white24, tooltip: "Obnovit (Vrátit do K Řešení)",
        )
      ];
    }

    if (order.stav == MockOrderState.pripraveno) {
      return [
        IconButton(
          onPressed: () => _zmenitStav(order, MockOrderState.nova), 
          icon: const Icon(Icons.history_rounded, size: 18),
          color: Colors.white24, tooltip: "Zpět (Není připraveno)",
        ),
        IconButton(
          onPressed: () => _odeslatPotvrzeniMock(order),
          icon: const Icon(Icons.send_rounded, size: 18),
          color: _colorGreen, tooltip: "Odeslat potvrzení (E-mail)",
        )
      ];
    }

    // Fáze "K řešení"
    return [
      if (order.stav == MockOrderState.nova)
        IconButton(
          onPressed: () => _zmenitStav(order, MockOrderState.ceka_na_nakup),
          icon: const Icon(Icons.shopping_cart_checkout, size: 18),
          color: _colorOrange, tooltip: "Předat na zjištění materiálu",
        ),

      if (order.stav == MockOrderState.ceka_na_nakup || order.stav == MockOrderState.ceka_na_zakaznika) ...[
        IconButton(
          onPressed: () => _zmenitStav(order, MockOrderState.ceka_na_zakaznika),
          icon: const Icon(Icons.warning_amber_rounded, size: 18),
          color: _colorRed, tooltip: "Cena se změnila (Čeká na zákazníka)",
        ),
        IconButton(
          onPressed: () => _zmenitStav(order, MockOrderState.pripraveno),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          color: _colorGreen, tooltip: "Materiál zajištěn",
        ),
      ]
    ];
  }

  // --- POMOCNÉ FUNKCE ---
  Widget _headerText(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            "Žádné zakázky v tomto stavu",
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
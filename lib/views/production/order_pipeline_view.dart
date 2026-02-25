import 'package:flutter/material.dart';

// --- MOCK DATOVÝ MODEL (Pouze pro vizualizaci) ---
enum MockOrderState {
  nova,
  ceka_na_nakup,
  ceka_na_zakaznika,
  pripraveno,
  pozastaveno,
  potvrzeno,
  storno
}

class MockOrder {
  final String cisloObjednavky;
  final String nazevZakaznika;
  final MockOrderState stav;
  final String datum;

  MockOrder({
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
  // --- FALEŠNÁ DATA (Pevný seznam pro ukázku UI) ---
  final List<MockOrder> _orders = [
    MockOrder(cisloObjednavky: "OBJ-2026-001", nazevZakaznika: "Kovovýroba Novák s.r.o.", stav: MockOrderState.nova, datum: "05.03.2026"),
    MockOrder(cisloObjednavky: "OBJ-2026-002", nazevZakaznika: "Auto-Tech a.s.", stav: MockOrderState.ceka_na_nakup, datum: "28.02.2026"),
    MockOrder(cisloObjednavky: "OBJ-2026-003", nazevZakaznika: "Stavby Zlín", stav: MockOrderState.ceka_na_zakaznika, datum: "01.03.2026"),
    MockOrder(cisloObjednavky: "OBJ-2026-004", nazevZakaznika: "Agro CZ", stav: MockOrderState.pripraveno, datum: "26.02.2026"),
    MockOrder(cisloObjednavky: "OBJ-2026-007", nazevZakaznika: "Dřevovýroba s.r.o.", stav: MockOrderState.pozastaveno, datum: "15.03.2026"),
    MockOrder(cisloObjednavky: "OBJ-2026-005", nazevZakaznika: "Zámečnictví Dvořák", stav: MockOrderState.potvrzeno, datum: "20.02.2026"),
    MockOrder(cisloObjednavky: "OBJ-2026-006", nazevZakaznika: "Strojírny Brno", stav: MockOrderState.storno, datum: "18.02.2026"),
  ];

  int _selectedFilterIndex = 0; // Pouze pro obarvení aktivní záložky

  // --- DESIGN KONSTANTY ---
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;
  
  static const Color _colorPrimary = Color(0xFF4077D1);
  static const Color _colorOrange = Color(0xFFFF9F1C);
  static const Color _colorGreen = Color(0xFF2E8B57);
  static const Color _colorRed = Color(0xFFD14040);

  // =========================================================================
  //  BUILD METHODY
  // =========================================================================

  @override
  Widget build(BuildContext context) {
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
            child: ListView.separated(
              itemCount: _orders.length,
              padding: const EdgeInsets.only(bottom: 80),
              separatorBuilder: (context, index) => const Divider(color: _borderColor, height: 1),
              itemBuilder: (context, index) => _buildOrderRow(_orders[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _borderColor),
            ),
            child: const TextField(
              style: TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
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
      onTap: () => setState(() => _selectedFilterIndex = index), // Pouze přepne barvu
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
          const SizedBox(width: 40), // Místo pro tři tečky na začátku
          _headerText("ČÍSLO OBJEDNÁVKY", flex: 2),
          _headerText("ZÁKAZNÍK", flex: 3),
          _headerText("TERMÍN / DATUM", flex: 2),
          _headerText("STAV ZAKÁZKY", flex: 2),
          const SizedBox(width: 120), // Zmenšený prostor pro akce (tečky jsou pryč)
        ],
      ),
    );
  }

  Widget _buildOrderRow(MockOrder order) {
    return InkWell(
      onTap: () {}, 
      hoverColor: Colors.white.withOpacity(0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 0. MENU (TŘI TEČKY) PŘESUNUTO NA ZAČÁTEK
            SizedBox(
              width: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildManualStateMenu(),
              ),
            ),

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
                style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500),
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

            // 5. RYCHLÉ AKCE (PRAVÁ STRANA)
            SizedBox(
              width: 120, // Prostor zmenšen, protože menu je vlevo
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
      case MockOrderState.pozastaveno:
        text = "Pozastaveno"; color = Colors.amber; icon = Icons.pause_circle_outline_rounded; break;
      case MockOrderState.potvrzeno:
        text = "Potvrzeno"; color = _colorPrimary; icon = Icons.done_all_rounded; break;
      case MockOrderState.storno:
        text = "Storno"; color = Colors.redAccent.withOpacity(0.5); icon = Icons.block_rounded; break;
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

  List<Widget> _buildRowActions(MockOrder order) {
    if (order.stav == MockOrderState.potvrzeno || order.stav == MockOrderState.storno) {
      return [];
    }

    if (order.stav == MockOrderState.pripraveno) {
      return [
        IconButton(
          onPressed: () {}, 
          icon: const Icon(Icons.history_rounded, size: 18),
          color: Colors.white24, tooltip: "Zpět k řešení",
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.send_rounded, size: 18),
          color: _colorGreen, tooltip: "Odeslat potvrzení (E-mail)",
        )
      ];
    }

    return [
      if (order.stav == MockOrderState.nova || order.stav == MockOrderState.pozastaveno)
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.shopping_cart_checkout, size: 18),
          color: _colorOrange, tooltip: "Předat na zjištění materiálu",
        ),

      if (order.stav == MockOrderState.ceka_na_nakup || order.stav == MockOrderState.ceka_na_zakaznika) ...[
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.warning_amber_rounded, size: 18),
          color: _colorRed, tooltip: "Cena se změnila (Čeká na zákazníka)",
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.check_circle_outline, size: 18),
          color: _colorGreen, tooltip: "Materiál zajištěn",
        ),
      ]
    ];
  }

  Widget _buildManualStateMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.white30),
      color: _bgCard,
      tooltip: "Změnit stav ručně",
      offset: const Offset(0, 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: _borderColor)),
      onSelected: (_) {}, // Nedělá nic
      itemBuilder: (context) => [
        _buildPopupItem("Nová", Icons.fiber_new_rounded, Colors.white54),
        _buildPopupItem("Čeká na nákup", Icons.shopping_cart_checkout, _colorOrange),
        _buildPopupItem("Čeká na zákazníka", Icons.warning_amber_rounded, _colorRed),
        _buildPopupItem("Připraveno", Icons.inventory_rounded, _colorGreen),
        const PopupMenuDivider(height: 1),
        _buildPopupItem("Pozastavit", Icons.pause_circle_outline_rounded, Colors.amber),
        _buildPopupItem("Stornovat", Icons.block_rounded, Colors.redAccent),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(String label, IconData icon, Color color) {
    return PopupMenuItem(
      value: label,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _headerText(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
      ),
    );
  }
}
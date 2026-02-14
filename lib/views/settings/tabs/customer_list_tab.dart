import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';

// Importy logiky a UI
import 'package:mrb_obchodnik/logic/db_service.dart';
import 'package:mrb_obchodnik/logic/notifications.dart'; 

class CustomerListTab extends StatefulWidget {
  const CustomerListTab({super.key});

  @override
  State<CustomerListTab> createState() => _CustomerListTabState();
}

class _CustomerListTabState extends State<CustomerListTab> {
  // Data
  final List<Map<String, dynamic>> _seznamZakazniku = [];
  final ScrollController _scrollController = ScrollController();
  
  // Stav vyhledávání a filtrů
  Timer? _debounce;
  String _query = '';
  bool _onlyMissing = false;
  
  // Stav načítání
  int _offset = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  // Design Konstanty (Flat & Technical)
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Infinite Scroll: Načti další, když jsme 200px od konce
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadData(loadMore: true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- LOGIKA DAT ---

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _query = val;
        _resetAndReload();
      });
    });
  }

  void _resetAndReload() {
    _seznamZakazniku.clear();
    _offset = 0;
    _hasMore = true;
    _loadData();
  }

  Future<void> _loadData({bool loadMore = false}) async {
    if (_isLoading) return;
    if (mounted) setState(() => _isLoading = true);

    if (loadMore) _offset += 50;
    
    try {
      final rawData = await DbService().getZakaznici(
        query: _query, 
        offset: _offset, 
        jenBezSlozky: _onlyMissing
      );

      // DŮLEŽITÉ: Vytvoříme modifikovatelnou kopii dat (sqflite vrací read-only mapy)
      final List<Map<String, dynamic>> mutableData = rawData
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      
      if (mounted) {
        setState(() {
          if (mutableData.length < 50) _hasMore = false;
          _seznamZakazniku.addAll(mutableData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Notifications.showError(context, "CHYBA NAČÍTÁNÍ DAT: $e");
      }
    }
  }

  Future<void> _priraditSlozku(Map<String, dynamic> item) async {
    // 1. Výběr složky
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Vyberte složku pro klienta: ${item['nazev']}",
      lockParentWindow: true,
    );
    
    if (selectedDirectory != null) {
      // 2. Update DB
      await DbService().updateFolderPath(item['id'], selectedDirectory);
      
      if (mounted) {
        // 3. Notifikace
        Notifications.showSuccess(context, "SLOŽKA PŘIŘAZENA: ${item['nazev']}");
        
        // 4. Lokální refresh (nyní bezpečný díky mutableData)
        setState(() {
           item['folder_path'] = selectedDirectory;
        });
      }
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildControls(),
        const SizedBox(height: 24),
        _buildTableHeader(),
        
        // Seznam nebo Empty State
        Expanded(
          child: _seznamZakazniku.isEmpty && !_isLoading
              ? _buildEmptyState()
              : _buildList(),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      controller: _scrollController,
      itemCount: _seznamZakazniku.length + (_isLoading ? 1 : 0),
      padding: const EdgeInsets.only(bottom: 40),
      separatorBuilder: (context, index) => const Divider(color: _borderColor, height: 1),
      itemBuilder: (context, index) {
        // Loader na konci seznamu
        if (index == _seznamZakazniku.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16), 
              child: SizedBox(
                width: 20, height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor)
              )
            )
          );
        }
        return _buildCustomerRow(_seznamZakazniku[index]);
      },
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        // SEARCH BAR
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
              cursorColor: _accentColor,
              decoration: InputDecoration(
                hintText: "Hledat klienta (Název, IČ, ID)...",
                hintStyle: const TextStyle(color: _textDim, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _textDim),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        
        // FILTER TOGGLE
        InkWell(
          onTap: () {
            setState(() {
              _onlyMissing = !_onlyMissing;
              _resetAndReload();
            });
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            height: 40,
            decoration: BoxDecoration(
              color: _onlyMissing ? _accentColor.withOpacity(0.15) : _bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _onlyMissing ? _accentColor.withOpacity(0.5) : _borderColor
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _onlyMissing ? Icons.folder_off_rounded : Icons.filter_list_rounded,
                  size: 16,
                  color: _onlyMissing ? _accentColor : _textDim,
                ),
                const SizedBox(width: 8),
                Text(
                  "POUZE BEZ SLOŽKY",
                  style: TextStyle(
                    color: _onlyMissing ? _accentColor : _textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
          _headerText("IDENTIFIKACE", flex: 3),
          _headerText("CESTA K DOKUMENTACI", flex: 5),
          _headerText("STAV", flex: 2, align: TextAlign.center),
          const SizedBox(width: 40), // Místo pro Edit tlačítko
        ],
      ),
    );
  }

  Widget _buildCustomerRow(Map<String, dynamic> item) {
    bool hasPath = item['folder_path'] != null && item['folder_path'].toString().isNotEmpty;

    return InkWell(
      onTap: () => _priraditSlozku(item),
      hoverColor: Colors.white.withOpacity(0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 1. IDENTIFIKACE
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['nazev'], maxLines: 1, overflow: TextOverflow.ellipsis, 
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _smallTag(item['externi_id'] ?? 'ID--', Colors.blueGrey),
                      const SizedBox(width: 6),
                      if (item['ic'] != null && item['ic'].toString().isNotEmpty)
                        _smallTag("IČ: ${item['ic']}", Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
            
            // 2. CESTA
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Icon(Icons.folder_open_rounded, size: 16, color: hasPath ? _accentColor : Colors.white10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasPath ? item['folder_path'] : '---',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: hasPath ? Colors.white70 : Colors.white12,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 3. STAV
            Expanded(
              flex: 2,
              child: Center(
                child: _buildStatusChip(hasPath),
              ),
            ),
            
            // 4. AKCE
            IconButton(
              onPressed: () => _priraditSlozku(item),
              icon: const Icon(Icons.edit_rounded, size: 16),
              color: Colors.white24,
              tooltip: "Změnit složku",
              hoverColor: Colors.white10,
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  // --- POMOCNÉ WIDGETY ---

  Widget _headerText(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          color: Colors.white30,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _smallTag(String text, Color color) {
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace'),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    final color = isActive ? const Color(0xFF10B981) : Colors.amber.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        isActive ? "PŘIPOJENO" : "CHYBÍ",
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            "Žádní zákazníci nenalezeni",
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
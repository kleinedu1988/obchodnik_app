import 'package:flutter/material.dart';
import 'dart:async';
import '../../../logic/db_service.dart';
import '../settings_helpers.dart';
import 'package:file_picker/file_picker.dart';
import '../../../logic/actions.dart'; 

class CustomerListTab extends StatefulWidget {
  const CustomerListTab({super.key});

  @override
  State<CustomerListTab> createState() => _CustomerListTabState();
}

class _CustomerListTabState extends State<CustomerListTab> {
  final List<Map<String, dynamic>> _seznamZakazniku = [];
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  bool _onlyMissing = false;
  int _offset = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Pokud jsme 200px od konce, načteme další várku (Infinite Scroll)
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadData(loadMore: true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSearchAndFilters(),
        const SizedBox(height: 32),
        _buildTableHeader(),
        Expanded(
          child: _seznamZakazniku.isEmpty && !_isLoading
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _seznamZakazniku.length + (_isLoading ? 1 : 0),
                  padding: const EdgeInsets.only(bottom: 40),
                  itemBuilder: (context, index) {
                    if (index == _seznamZakazniku.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16), 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4077D1))
                        )
                      );
                    }
                    final item = _seznamZakazniku[index];
                    return _buildCustomerRow(item, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Opacity(
        opacity: 0.3,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search_rounded, size: 48, color: Colors.white),
            const SizedBox(height: 16),
            Text("Žádní zákazníci nenalezeni", style: TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Row(
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 400),
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            onChanged: (val) {
              _query = val;
              _nactiPrvniData();
            },
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: "Hledat klienta (Název, IČ, ID)...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, size: 16, color: Colors.white.withOpacity(0.2)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 24),
        _buildFilterToggle(),
      ],
    );
  }

  Widget _buildFilterToggle() {
    return InkWell(
      onTap: () {
        setState(() => _onlyMissing = !_onlyMissing);
        _nactiPrvniData();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _onlyMissing ? const Color(0xFF4077D1).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _onlyMissing ? const Color(0xFF4077D1).withOpacity(0.3) : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(
              _onlyMissing ? Icons.folder_off_rounded : Icons.folder_shared_rounded,
              size: 14,
              color: _onlyMissing ? const Color(0xFF4077D1) : Colors.white30,
            ),
            const SizedBox(width: 8),
            Text(
              "Pouze bez složky",
              style: TextStyle(
                color: _onlyMissing ? Colors.white : Colors.white30,
                fontSize: 12,
                fontWeight: _onlyMissing ? FontWeight.bold : FontWeight.normal
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: SettingsHelpers.headerText("Klient / ID")),
          Expanded(flex: 4, child: SettingsHelpers.headerText("Cesta k dokumentaci")),
          Expanded(flex: 2, child: Center(child: SettingsHelpers.headerText("Stav"))),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCustomerRow(Map<String, dynamic> item, int index) {
    bool hasPath = item['folder_path'] != null && item['folder_path'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03), width: 0.5)),
      ),
      child: InkWell(
        onTap: () => _zmenitSlozku(index),
        hoverColor: Colors.white.withOpacity(0.02),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['nazev'], maxLines: 1, overflow: TextOverflow.ellipsis, 
                         style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text("ID: ${item['externi_id'] ?? 'N/A'}", 
                         style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white.withOpacity(0.2))),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Icon(Icons.folder_open_rounded, size: 14, color: hasPath ? const Color(0xFF4077D1).withOpacity(0.4) : Colors.white10),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['folder_path'] ?? 'Nenastaveno',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: hasPath ? Colors.white.withOpacity(0.5) : Colors.white12,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: _buildStatusBadge(hasPath ? "PŘIPOJENO" : "CHYBÍ", hasPath),
                ),
              ),
              IconButton(
                onPressed: () => _zmenitSlozku(index),
                icon: Icon(Icons.edit_note_rounded, size: 18, color: Colors.white.withOpacity(0.2)),
                hoverColor: Colors.white10,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, bool success) {
    Color color = success ? const Color(0xFF10B981) : Colors.amberAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }

  void _nactiPrvniData() {
    setState(() {
      _seznamZakazniku.clear();
      _offset = 0;
      _hasMore = true;
    });
    _loadData();
  }

  void _loadData({bool loadMore = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (loadMore) _offset += 50;
    
    final newData = await DbService().getZakaznici(
      query: _query, 
      offset: _offset, 
      jenBezSlozky: _onlyMissing
    );
    
    if (mounted) {
      setState(() {
        if (newData.length < 50) _hasMore = false;
        _seznamZakazniku.addAll(newData);
        _isLoading = false;
      });
    }
  }

  void _zmenitSlozku(int index) async {
    final item = _seznamZakazniku[index];
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    
    if (selectedDirectory != null) {
      // Používáme interní ID pro přesnou aktualizaci řádku
      await DbService().updateFolderPath(item['id'], selectedDirectory);
      
      if (mounted) {
        zpracujKliknuti(context, item['nazev']);
        _nactiPrvniData(); // Refresh seznamu
      }
    }
  }
}
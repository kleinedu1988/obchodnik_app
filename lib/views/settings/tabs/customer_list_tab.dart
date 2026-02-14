import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p; // Pro parsování názvu složky

// Importy logiky a UI
import '../../../logic/db_service.dart';
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
  
  // Stav
  Timer? _debounce;
  String _query = '';
  bool _onlyMissing = false;
  int _offset = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  // Design (Blue Theme)
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _blueColor = Color(0xFF4077D1);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
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

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
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
        Notifications.showError(context, "CHYBA: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildControls(),
        const SizedBox(height: 24),
        _buildTableHeader(),
        
        Expanded(
          child: _seznamZakazniku.isEmpty && !_isLoading
              ? _buildEmptyState()
              : ListView.separated(
                  controller: _scrollController,
                  itemCount: _seznamZakazniku.length + (_isLoading ? 1 : 0),
                  padding: const EdgeInsets.only(bottom: 40),
                  separatorBuilder: (context, index) => const Divider(color: _borderColor, height: 1),
                  itemBuilder: (context, index) {
                    if (index == _seznamZakazniku.length) {
                      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2, color: _blueColor)));
                    }
                    return _CustomerRow(
                      item: _seznamZakazniku[index], 
                      accentColor: _blueColor,
                      borderColor: _borderColor,
                    );
                  },
                ),
        ),
      ],
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
            child: TextField(
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              cursorColor: _blueColor,
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
              color: _onlyMissing ? _blueColor.withOpacity(0.15) : _bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _onlyMissing ? _blueColor.withOpacity(0.5) : _borderColor
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _onlyMissing ? Icons.folder_off_rounded : Icons.filter_list_rounded,
                  size: 16,
                  color: _onlyMissing ? _blueColor : _textDim,
                ),
                const SizedBox(width: 8),
                Text(
                  "JEN BEZ SLOŽKY",
                  style: TextStyle(
                    color: _onlyMissing ? _blueColor : _textDim,
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
          _headerText("IDENTIFIKACE ZÁKAZNÍKA", flex: 3),
          _headerText("KOŘENOVÁ SLOŽKA (ZADEJTE MANUÁLNĚ)", flex: 5),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: Colors.white12),
          const SizedBox(height: 16),
          Text("Žádní zákazníci nenalezeni", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
        ],
      ),
    );
  }
}

// =============================================================================
//  ŘÁDEK ZÁKAZNÍKA - POUZE MANUÁLNÍ ZADÁVÁNÍ
// =============================================================================

class _CustomerRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final Color accentColor;
  final Color borderColor;

  const _CustomerRow({
    required this.item,
    required this.accentColor,
    required this.borderColor,
  });

  @override
  State<_CustomerRow> createState() => _CustomerRowState();
}

class _CustomerRowState extends State<_CustomerRow> {
  late TextEditingController _pathCtrl;
  final FocusNode _focusNode = FocusNode();
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _pathCtrl = TextEditingController(text: widget.item['folder_path'] ?? '');
    
    // Ukládání při ztrátě focusu (kliknutí jinam)
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _updatePath(_pathCtrl.text);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CustomerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['folder_path'] != widget.item['folder_path']) {
       if (!_focusNode.hasFocus && _pathCtrl.text != widget.item['folder_path']) {
         _pathCtrl.text = widget.item['folder_path'] ?? '';
       }
    }
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _updatePath(String path) async {
    final cleanPath = path.trim();
    // Uložíme pouze pokud se hodnota skutečně změnila oproti DB
    if (cleanPath == (widget.item['folder_path'] ?? '')) return;

    await DbService().updateFolderPath(widget.item['id'], cleanPath);
    if (mounted) {
      setState(() {
        widget.item['folder_path'] = cleanPath;
      });
      Notifications.showSuccess(context, "CESTA PRO ${widget.item['nazev']} ULOŽENA");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        color: _isHovering ? Colors.white.withOpacity(0.02) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 1. IDENTIFIKACE
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: widget.accentColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item['nazev'],
                      style: TextStyle(
                        color: widget.accentColor, 
                        fontSize: 12, 
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _infoTag("ID", widget.item['externi_id']),
                        const SizedBox(width: 12),
                        if (widget.item['ic'] != null && widget.item['ic'].toString().isNotEmpty)
                          _infoTag("IČ", widget.item['ic']),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 16),

            // 2. CESTA (Předěláno na čistý ruční input)
            Expanded(
              flex: 5,
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _focusNode.hasFocus ? widget.accentColor.withOpacity(0.5) : widget.borderColor
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded, 
                      size: 16, 
                      color: _pathCtrl.text.isEmpty ? Colors.white10 : widget.accentColor.withOpacity(0.5)
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _pathCtrl,
                        focusNode: _focusNode,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white70),
                        cursorColor: widget.accentColor,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Vložte nebo napište cestu...",
                          hintStyle: TextStyle(color: Colors.white10, fontSize: 11),
                          isDense: true,
                        ),
                        onSubmitted: (val) => _updatePath(val),
                      ),
                    ),
                    if (_pathCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, size: 14, color: Colors.white12),
                        onPressed: () {
                          _pathCtrl.clear();
                          _updatePath('');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 10,
                      )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTag(String label, String? value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("$label: ", style: TextStyle(color: widget.accentColor.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value ?? '-', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontFamily: 'monospace')),
      ],
    );
  }
}
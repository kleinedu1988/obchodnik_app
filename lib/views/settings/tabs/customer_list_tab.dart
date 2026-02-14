import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

// Importy logiky a UI
import '../../../logic/db_service.dart';
import 'package:mrb_obchodnik/logic/notifications.dart';

// NOVÉ: validátor složek (TECH / NABÍDKY)
import 'package:mrb_obchodnik/logic/folder_validator.dart';

class CustomerListTab extends StatefulWidget {
  const CustomerListTab({super.key});

  @override
  State<CustomerListTab> createState() => _CustomerListTabState();
}

class _CustomerListTabState extends State<CustomerListTab> {
  final List<Map<String, dynamic>> _seznamZakazniku = [];
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;
  String _query = '';
  bool _onlyMissing = false;
  int _offset = 0;
  bool _isLoading = false;
  bool _hasMore = true;

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
      if (!_isLoading && _hasMore) _loadData(loadMore: true);
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
        jenBezSlozky: _onlyMissing,
      );
      final List<Map<String, dynamic>> mutableData = rawData.map((e) => Map<String, dynamic>.from(e)).toList();

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
        _buildFilterToggle(),
      ],
    );
  }

  Widget _buildFilterToggle() {
    return InkWell(
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
          border: Border.all(color: _onlyMissing ? _blueColor.withOpacity(0.5) : _borderColor),
        ),
        child: Row(
          children: [
            Icon(_onlyMissing ? Icons.folder_off_rounded : Icons.filter_list_rounded, size: 16, color: _onlyMissing ? _blueColor : _textDim),
            const SizedBox(width: 8),
            Text("JEN BEZ SLOŽKY", style: TextStyle(color: _onlyMissing ? _blueColor : _textDim, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor, width: 2))),
      child: Row(
        children: [
          _headerText("IDENTIFIKACE ZÁKAZNÍKA", flex: 3),
          _headerText("KOŘENOVÁ SLOŽKA", flex: 5),
          _headerText("STATUS", flex: 1, align: TextAlign.center),
        ],
      ),
    );
  }

  Widget _headerText(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(text, textAlign: align, style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
//  ŘÁDEK ZÁKAZNÍKA S PULZUJÍCÍMI BODY NA KONCI
// =============================================================================

class _CustomerRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final Color accentColor;
  final Color borderColor;

  const _CustomerRow({required this.item, required this.accentColor, required this.borderColor});

  @override
  State<_CustomerRow> createState() => _CustomerRowState();
}

class _CustomerRowState extends State<_CustomerRow> {
  late TextEditingController _pathCtrl;
  final FocusNode _focusNode = FocusNode();
  bool _isHovering = false;
  Future<Map<String, bool>>? _folderFuture;

  @override
  void initState() {
    super.initState();
    _pathCtrl = TextEditingController(text: widget.item['folder_path'] ?? '');
    _folderFuture = FolderValidator.checkCustomerFolders(widget.item['folder_path'] ?? '');
    _focusNode.addListener(() { if (!_focusNode.hasFocus) _updatePath(_pathCtrl.text); });
  }

  @override
  void didUpdateWidget(covariant _CustomerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['folder_path'] != widget.item['folder_path']) {
      if (!_focusNode.hasFocus) {
        _pathCtrl.text = widget.item['folder_path'] ?? '';
        _folderFuture = FolderValidator.checkCustomerFolders(widget.item['folder_path'] ?? '');
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
    if (cleanPath == (widget.item['folder_path'] ?? '')) return;
    await DbService().updateFolderPath(widget.item['id'], cleanPath);
    if (mounted) {
      setState(() {
        widget.item['folder_path'] = cleanPath;
        _folderFuture = FolderValidator.checkCustomerFolders(cleanPath);
      });
      Notifications.showSuccess(context, "CESTA ULOŽENA");
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
            // 1) IDENTIFIKACE
            Expanded(
              flex: 3,
              child: _buildIdentityBlock(),
            ),
            const SizedBox(width: 16),
            // 2) CESTA (Input)
            Expanded(
              flex: 5,
              child: _buildPathInput(),
            ),
            const SizedBox(width: 16),
            // 3) STATUS BODY (Až na konci)
            Expanded(
              flex: 1,
              child: FutureBuilder<Map<String, bool>>(
                future: _folderFuture,
                builder: (context, snapshot) {
                  final bool techOk = snapshot.data?['tech'] ?? false;
                  final bool offerOk = snapshot.data?['offer'] ?? false;
                  final bool isLoading = snapshot.connectionState == ConnectionState.waiting;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AnimatedStatusDot(label: "T", exists: techOk, loading: isLoading),
                      const SizedBox(width: 10),
                      _AnimatedStatusDot(label: "N", exists: offerOk, loading: isLoading),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityBlock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: widget.accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.item['nazev'], style: TextStyle(color: widget.accentColor, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(
            children: [
              _infoTag("ID", widget.item['externi_id']),
              const SizedBox(width: 12),
              if (widget.item['ic'] != null && widget.item['ic'].toString().isNotEmpty) _infoTag("IČ", widget.item['ic']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPathInput() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _focusNode.hasFocus ? widget.accentColor.withOpacity(0.5) : widget.borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.edit_note_rounded, size: 16, color: _pathCtrl.text.isEmpty ? Colors.white10 : widget.accentColor.withOpacity(0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _pathCtrl,
              focusNode: _focusNode,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white70),
              cursorColor: widget.accentColor,
              decoration: const InputDecoration(border: InputBorder.none, hintText: "Vložte cestu...", hintStyle: TextStyle(color: Colors.white10, fontSize: 11), isDense: true),
              onSubmitted: (val) => _updatePath(val),
            ),
          ),
        ],
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

// =============================================================================
//  KOMPONENTA PULZUJÍCÍHO BODU (GLOW EFFECT)
// =============================================================================

class _AnimatedStatusDot extends StatefulWidget {
  final String label;
  final bool exists;
  final bool loading;

  const _AnimatedStatusDot({required this.label, required this.exists, required this.loading});

  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white10));

    final Color color = widget.exists ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Tooltip(
      message: widget.exists ? "Složka ${widget.label} existuje" : "Složka ${widget.label} NEEXISTUJE",
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              border: Border.all(color: color.withOpacity(0.5 * _animation.value), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2 * _animation.value),
                  blurRadius: 6 * _animation.value,
                  spreadRadius: 1 * _animation.value,
                )
              ],
            ),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(color: color.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.w900),
              ),
            ),
          );
        },
      ),
    );
  }
}
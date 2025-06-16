// navigation_list_item.dart
import 'package:flutter/material.dart';

class NavigationListItem extends StatefulWidget {
  final String title;
  final IconData? icon;
  final bool isSelected;
  final bool isSubItem;
  final VoidCallback onTap;
  final Color activeColor; // Warna teks & ikon saat aktif
  final Color activeBackgroundColor; // Warna background saat aktif
  final Color defaultTextColor;
  final Color defaultIconColor;

  const NavigationListItem({
    super.key,
    required this.title,
    this.icon,
    required this.isSelected,
    this.isSubItem = false,
    required this.onTap,
    required this.activeColor,
    required this.activeBackgroundColor, // Tambahkan ini
    this.defaultTextColor = const Color(0xFF555555),
    this.defaultIconColor = const Color(0xFF757575),
  });

  @override
  State<NavigationListItem> createState() => _NavigationListItemState();
}

class _NavigationListItemState extends State<NavigationListItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    // Jika item terpilih, teks dan ikon menggunakan activeColor, background menggunakan activeBackgroundColor
    // Jika tidak terpilih tapi di-hover, teks dan ikon bisa sedikit berubah, background juga
    // Jika tidak terpilih dan tidak di-hover, gunakan warna default

    Color textColor;
    Color iconColor;
    Color itemBackgroundColor; // Warna background item keseluruhan
    Color contentBackgroundColor; // Warna background konten (rounded)

    if (widget.isSelected) {
      textColor = Colors.white; // Teks putih saat aktif (sesuai desain)
      iconColor = Colors.white; // Ikon putih saat aktif
      itemBackgroundColor = widget.activeBackgroundColor; // Warna background dari parameter
      contentBackgroundColor = widget.activeBackgroundColor;
    } else if (_isHovering) {
      textColor = widget.defaultTextColor.withOpacity(0.9);
      iconColor = widget.defaultIconColor.withOpacity(0.9);
      itemBackgroundColor = Colors.grey.withOpacity(0.05); // Efek hover background tipis
      contentBackgroundColor = Colors.transparent; // Tidak ada background khusus untuk konten saat hover
    } else {
      textColor = widget.defaultTextColor;
      iconColor = widget.defaultIconColor;
      itemBackgroundColor = Colors.transparent;
      contentBackgroundColor = Colors.transparent;
    }

    // Padding untuk sub-item agar lebih menjorok dan padding untuk item utama
    // Padding horizontal utama diatur oleh parent (SidebarWidget)
    // Di sini kita atur padding internal untuk konten item dan indentasi sub-item
    EdgeInsets contentPadding;
    if (widget.isSubItem) {
      // Padding untuk sub-item. Icon akan align dengan text item utama jika item utama punya icon.
      // Jika item utama tidak punya icon, maka sub-item akan lebih menjorok.
      // Desain Anda menunjukkan sub-item menjorok lebih dalam.
      contentPadding = EdgeInsets.only(
          left: widget.icon != null ? 40.0 : 56.0, // Lebih menjorok jika ada ikon, sangat menjorok jika tidak ada ikon (untuk teks saja)
          top: 12.0, bottom: 12.0, right: 20.0
      );
    } else {
      // Padding untuk item utama
      contentPadding = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0);
    }


    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          // Margin horizontal untuk item diatur oleh Padding di SidebarWidget
          // Margin vertikal antar item
          margin: widget.isSubItem
              ? const EdgeInsets.only(left: 20.0, right: 16.0, top: 2.0, bottom: 2.0) // Sub-item punya margin kiri agar efek background tidak full width parent
              : const EdgeInsets.symmetric(vertical: 4.0),
          decoration: BoxDecoration(
            color: itemBackgroundColor, // Background untuk keseluruhan area item (termasuk margin jika ada)
            borderRadius: BorderRadius.circular(12.0), // Sudut membulat
          ),
          child: Padding( // Padding untuk konten di dalam item (ikon & teks)
            padding: widget.isSubItem && widget.isSelected
                ? EdgeInsets.only(left: widget.icon != null ? 20.0 : 36.0, top:12, bottom:12, right: 20) // Kurangi left padding sub-item jika terpilih
                : (widget.isSubItem
                ? EdgeInsets.only(left: widget.icon != null ? 20.0 : 36.0, top:12, bottom:12, right: 20)  // Padding sub-item default
                : const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0)), // Padding item utama
            child: Row(
              children: <Widget>[
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 22, color: iconColor),
                  const SizedBox(width: 16), // Spasi antara ikon dan teks
                ],
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
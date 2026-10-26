import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/help/domain/bloc/help_bloc.dart';

class HelpSearchBar extends StatefulWidget {
  const HelpSearchBar({super.key});

  @override
  State<HelpSearchBar> createState() => _HelpSearchBarState();
}

class _HelpSearchBarState extends State<HelpSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    setState(() {});
    context.read<HelpBloc>().add(HelpSearchQueryChanged(val.trim()));
  }

  void _clear() {
    _controller.clear();
    setState(() {});
    context.read<HelpBloc>().add(const HelpSearchQueryChanged(''));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: 21,
            color: Color(0xFF6B7280),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'help.search_hint'.tr(),
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: _clear,
              child: const Icon(
                Icons.cancel,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
            ),
        ],
      ),
    );
  }
}

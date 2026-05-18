import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/api/recordings_api.dart';
import '../../core/models/recording.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/archive_recording_card.dart';

class ArchiveView extends StatefulWidget {
  const ArchiveView({super.key});

  @override
  State<ArchiveView> createState() => _ArchiveViewState();
}

class _ArchiveViewState extends State<ArchiveView> {
  List<Recording> _allRecordings = [];
  bool _loading = true;
  String? _error;

  // Calendar State
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final recs = await RecordingsApi.list();
      recs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _allRecordings = recs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  List<Recording> _getFilteredRecordings() {
    if (_selectedDate == null) return _allRecordings;
    return _allRecordings.where((r) {
      final dt = DateTime.tryParse(r.createdAt)?.toLocal();
      if (dt == null) return false;
      return dt.year == _selectedDate!.year &&
          dt.month == _selectedDate!.month &&
          dt.day == _selectedDate!.day;
    }).toList();
  }

  bool _dayHasRecordings(int day) {
    return _allRecordings.any((r) {
      final dt = DateTime.tryParse(r.createdAt)?.toLocal();
      if (dt == null) return false;
      return dt.year == _currentMonth.year &&
          dt.month == _currentMonth.month &&
          dt.day == day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.65)
        : AppColors.surfaceLight.withValues(alpha: 0.80);
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: GoogleFonts.inter(color: AppColors.error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _fetch, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final filtered = _getFilteredRecordings();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomScrollView(
        slivers: [
          // calendar section card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    // Calendar header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _prevMonth,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_currentMonth),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          onPressed: _nextMonth,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Weekday Names
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((wd) {
                        return SizedBox(
                          width: 32,
                          child: Text(
                            wd,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    // Days grid
                    _CalendarGrid(
                      month: _currentMonth,
                      selectedDate: _selectedDate,
                      hasRecordingFn: _dayHasRecordings,
                      onDaySelected: (day) {
                        setState(() {
                          final target = DateTime(_currentMonth.year, _currentMonth.month, day);
                          if (_selectedDate != null &&
                              _selectedDate!.year == target.year &&
                              _selectedDate!.month == target.month &&
                              _selectedDate!.day == target.day) {
                            _selectedDate = null;
                          } else {
                            _selectedDate = target;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Header for recordings feed
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDate != null
                        ? 'Entries on ${DateFormat('MMM d, yyyy').format(_selectedDate!)}'
                        : 'All Past Entries',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_selectedDate != null)
                    TextButton(
                      onPressed: () => setState(() => _selectedDate = null),
                      child: const Text('Show all'),
                    ),
                ],
              ),
            ),
          ),

          // Recordings feed list
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _selectedDate != null
                        ? 'No entries recorded on this day.'
                        : 'Your mindstream is empty. Speak or write to begin!',
                    style: GoogleFonts.inter(
                      color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, index) => ArchiveRecordingCard(recording: filtered[index]),
                childCount: filtered.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime? selectedDate;
  final bool Function(int) hasRecordingFn;
  final ValueChanged<int> onDaySelected;

  const _CalendarGrid({
    required this.month,
    required this.selectedDate,
    required this.hasRecordingFn,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalDays = DateUtils.getDaysInMonth(month.year, month.month);
    final firstDayOffset = DateTime(month.year, month.month, 1).weekday - 1; // 0-based index

    final List<Widget> dayWidgets = [];

    // Weekday offsets padding
    for (int i = 0; i < firstDayOffset; i++) {
      dayWidgets.add(const SizedBox(width: 32, height: 32));
    }

    // Days listing
    for (int day = 1; day <= totalDays; day++) {
      final isSelected = selectedDate != null &&
          selectedDate!.year == month.year &&
          selectedDate!.month == month.month &&
          selectedDate!.day == day;

      final hasRecs = hasRecordingFn(day);
      final activeColor = isDark ? AppColors.teal : AppColors.tealDark;

      dayWidgets.add(
        GestureDetector(
          onTap: () => onDaySelected(day),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? activeColor
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$day',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? activeColor
                        : (isDark ? AppColors.textDark : AppColors.textLight),
                  ),
                ),
                if (hasRecs)
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.teal : AppColors.tealDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: dayWidgets,
    );
  }
}

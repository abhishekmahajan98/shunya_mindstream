import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/api/recordings_api.dart';
import '../../core/models/recording.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/archive_recording_card.dart';
import '../../core/services/sync_service.dart';

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
  String _viewMode = 'calendar';
  int _heatmapYear = DateTime.now().year;

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
      final pendingRaw = await SyncService.getPendingRecordings();
      final pendingSync = pendingRaw.map((d) {
        final localTs = d['local_timestamp'] as String? ?? DateTime.now().toIso8601String();
        return Recording(
          id: 'pending_${d['local_timestamp'] ?? DateTime.now().millisecondsSinceEpoch}_${d['transcript'].hashCode}',
          analystId: '',
          type: d['type'] as String? ?? 'freeform',
          promptId: d['prompt_id'] as String?,
          transcript: d['transcript'] as String? ?? '',
          durationSecs: d['duration_secs'] as int?,
          wordCount: d['word_count'] as int?,
          createdAt: localTs,
          prompts: d['prompt_id'] != null ? {'title': 'Prompt Response'} : null,
        );
      }).toList();

      final recs = await RecordingsApi.list();
      final combined = [...pendingSync, ...recs];
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _allRecordings = combined;
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
          // View Toggle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ToggleBtn(
                          icon: Icons.calendar_month,
                          label: 'Calendar',
                          isSelected: _viewMode == 'calendar',
                          onTap: () => setState(() => _viewMode = 'calendar'),
                        ),
                        _ToggleBtn(
                          icon: Icons.grid_view,
                          label: 'Heatmap',
                          isSelected: _viewMode == 'heatmap',
                          onTap: () => setState(() => _viewMode = 'heatmap'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // View Mode Container (Calendar or Heatmap)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: _viewMode == 'calendar'
                    ? Column(
                        children: [
                    // Calendar header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _prevMonth,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        GestureDetector(
                          onTap: () {
                            DateTime tempDate = _currentMonth;
                            showModalBottomSheet(
                              context: context,
                              builder: (BuildContext builder) {
                                return Container(
                                  height: 250,
                                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                  child: SafeArea(
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            CupertinoButton(
                                              child: const Text('Done'),
                                              onPressed: () {
                                                setState(() => _currentMonth = DateTime(tempDate.year, tempDate.month, 1));
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                          ],
                                        ),
                                        Expanded(
                                          child: CupertinoDatePicker(
                                            mode: CupertinoDatePickerMode.monthYear,
                                            initialDateTime: _currentMonth,
                                            maximumDate: DateTime.now().add(const Duration(days: 365)),
                                            onDateTimeChanged: (DateTime newDate) {
                                              tempDate = newDate;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('MMMM yyyy').format(_currentMonth),
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, size: 20),
                            ],
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
                      )
                    : _HeatmapGrid(
                        recordings: _allRecordings,
                        selectedDate: _selectedDate,
                        targetYear: _heatmapYear,
                        onDaySelected: (day) {
                          setState(() {
                            if (_selectedDate != null &&
                                _selectedDate!.year == day.year &&
                                _selectedDate!.month == day.month &&
                                _selectedDate!.day == day.day) {
                              _selectedDate = null;
                            } else {
                              _selectedDate = day;
                            }
                          });
                        },
                        onYearSelected: (year) {
                          setState(() {
                            _heatmapYear = year;
                          });
                        },
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text(
                    '$day',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? activeColor
                          : (isDark ? AppColors.textDark : AppColors.textLight),
                    ),
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

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.teal : AppColors.tealDark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : (isDark ? AppColors.textDark3 : AppColors.textLight3),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : (isDark ? AppColors.textDark3 : AppColors.textLight3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  final List<Recording> recordings;
  final DateTime? selectedDate;
  final int targetYear;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<int> onYearSelected;

  const _HeatmapGrid({
    required this.recordings,
    required this.selectedDate,
    required this.targetYear,
    required this.onDaySelected,
    required this.onYearSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.teal : AppColors.tealDark;

    // Process counts
    final counts = <String, int>{};
    for (final r in recordings) {
      final dt = DateTime.tryParse(r.createdAt)?.toLocal();
      if (dt != null) {
        final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    // Render target year
    final startDate = DateTime(targetYear, 1, 1);
    final today = DateTime.now();
    final endDate = targetYear == today.year ? today : DateTime(targetYear, 12, 31);
    
    // Find first Sunday before or on startDate to align rows perfectly
    var currentDay = startDate;
    while (currentDay.weekday != DateTime.sunday) {
      currentDay = currentDay.subtract(const Duration(days: 1));
    }

    final List<Widget> columns = [];
    List<Widget> currentWeek = [];

    // Track month labels
    final List<Widget> monthLabels = [];
    int currentMonthTracker = -1;
    double currentXOffset = 0;

    while (currentDay.isBefore(endDate) || currentDay.isAtSameMomentAs(endDate)) {
      final date = currentDay;

      // Add month label if it's the first week of the month
      if (date.month != currentMonthTracker && date.day <= 7) {
        currentMonthTracker = date.month;
        monthLabels.add(
          Positioned(
            left: currentXOffset,
            child: Text(
              DateFormat('MMM').format(date),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: isDark ? AppColors.textDark3 : AppColors.textLight3,
              ),
            ),
          ),
        );
      }

      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final count = counts[key] ?? 0;
      
      final isSelected = selectedDate != null &&
          selectedDate!.year == date.year &&
          selectedDate!.month == date.month &&
          selectedDate!.day == date.day;

      Color squareColor;
      if (count == 0) {
        squareColor = isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight2;
      } else if (count <= 2) {
        squareColor = activeColor.withValues(alpha: 0.3);
      } else if (count <= 4) {
        squareColor = activeColor.withValues(alpha: 0.6);
      } else {
        squareColor = activeColor;
      }

      currentWeek.add(
        GestureDetector(
          onTap: () => onDaySelected(date),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: squareColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
        ),
      );

      if (date.weekday == DateTime.saturday) {
        columns.add(
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(children: List.from(currentWeek)),
          ),
        );
        currentWeek.clear();
        currentXOffset += 18.0; // 14 width + 4 padding
      }

      currentDay = currentDay.add(const Duration(days: 1));
    }

    if (currentWeek.isNotEmpty) {
      columns.add(
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Column(children: currentWeek),
        ),
      );
      currentXOffset += 18.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Contribution Heatmap',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () {
                final currentYear = DateTime.now().year;
                // Generate from current year down to 2024
                final years = List.generate(currentYear - 2024 + 1, (index) => currentYear - index);
                int selectedIndex = years.indexOf(targetYear);
                if (selectedIndex == -1) selectedIndex = 0;

                showModalBottomSheet(
                  context: context,
                  builder: (BuildContext builder) {
                    return Container(
                      height: 250,
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      child: SafeArea(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                CupertinoButton(
                                  child: const Text('Done'),
                                  onPressed: () {
                                    onYearSelected(years[selectedIndex]);
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
                            Expanded(
                              child: CupertinoPicker(
                                itemExtent: 32.0,
                                scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                                onSelectedItemChanged: (int index) {
                                  selectedIndex = index;
                                },
                                children: years.map((y) => Center(child: Text(y.toString()))).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$targetYear',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: activeColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 20, color: activeColor),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // Start scrolled to the rightmost (today)
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 16,
                width: currentXOffset,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: monthLabels,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: columns,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

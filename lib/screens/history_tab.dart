import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/cricket_provider.dart';
import '../models/match.dart';
import '../widgets/glass_container.dart';
import 'match_score_screen.dart';
import 'scorecard_screen.dart';
import 'single_mode_screen.dart';
import 'pair_mode_screen.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _selectedFilter = 'all';

  Widget _buildMatchBadge(MatchModel match) {
    final type = match.matchData != null ? match.matchData['type'] : null;
    String label = 'TEAM';
    List<Color> colors = [const Color(0xFFFFDF7A), const Color(0xFFD4AF37)];
    Color txtColor = Colors.black;

    if (type == 'single_mode') {
      label = 'SINGLE';
      colors = [const Color(0xFF00E5FF), const Color(0xFF0077FF)];
      txtColor = Colors.white;
    } else if (type == 'pair_mode') {
      label = 'PAIR';
      colors = [const Color(0xFFF355DA), const Color(0xFF6E0DF2)];
      txtColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: txtColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {
        'key': 'all',
        'label': 'ALL',
        'gradient': [const Color(0xFF475569), const Color(0xFF1E293B)],
      },
      {
        'key': 'single',
        'label': 'SINGLE',
        'gradient': [const Color(0xFF00E5FF), const Color(0xFF0077FF)],
      },
      {
        'key': 'pair',
        'label': 'PAIR',
        'gradient': [const Color(0xFFF355DA), const Color(0xFF6E0DF2)],
      },
      {
        'key': 'team',
        'label': 'TEAM',
        'gradient': [const Color(0xFFFFDF7A), const Color(0xFFD4AF37)],
      },
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['key'];
          final gradient = filter['gradient'] as List<Color>;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter['key'] as String;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFF2C2C2C),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: gradient.first.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    filter['label'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? (filter['key'] == 'team'
                                ? Colors.black
                                : Colors.white)
                          : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CricketProvider>(context);
    final allMatches = provider.matches.reversed.toList();

    // Filter matches
    final matches = allMatches.where((m) {
      if (_selectedFilter == 'all') return true;
      final type = m.matchData != null ? m.matchData['type'] : null;
      if (_selectedFilter == 'single') return type == 'single_mode';
      if (_selectedFilter == 'pair') return type == 'pair_mode';
      if (_selectedFilter == 'team')
        return type != 'single_mode' && type != 'pair_mode';
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MATCH HISTORY',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.4,
            colors: [
              Color(0xFF141A29), // Deep slate center
              Color(0xFF07090F), // Fade to midnight black edges
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: matches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off_outlined,
                              size: 80,
                              color: Colors.white24,
                            ).animate().fadeIn(),
                            const SizedBox(height: 20),
                            const Text(
                              'No matches found.',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final match = matches[index];
                          final isMatchCompleted = match.isCompleted;

                          return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: GlassContainer(
                                  borderRadius: 22,
                                  blur: 20,
                                  borderOpacity: 0.08,
                                  backgroundOpacity: 0.04,
                                  borderColor: isMatchCompleted
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent,
                                  padding: EdgeInsets.zero,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(22),
                                    onTap: () {
                                      if (match.isCompleted) {
                                        if (match.matchData != null &&
                                            match.matchData['type'] ==
                                                'single_mode') {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  SingleModeScorecardScreen(
                                                    match: match,
                                                  ),
                                            ),
                                          );
                                        } else if (match.matchData != null &&
                                            match.matchData['type'] ==
                                                'pair_mode') {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PairModeScorecardScreen(
                                                    match: match,
                                                  ),
                                            ),
                                          );
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ScorecardScreen(match: match),
                                            ),
                                          );
                                        }
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                MatchScoreScreen(match: match),
                                          ),
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        match.matchData !=
                                                                    null &&
                                                                match.matchData['type'] ==
                                                                    'single_mode'
                                                            ? 'Single Mode Practice'
                                                            : match.matchData !=
                                                                      null &&
                                                                  match.matchData['type'] ==
                                                                      'pair_mode'
                                                            ? 'Pair Mode Match'
                                                            : '${match.team1Name} vs ${match.team2Name}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 18,
                                                          color: Colors.white,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _buildMatchBadge(match),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.calendar_today,
                                                      size: 14,
                                                      color: const Color(
                                                        0xFFA0A0A0,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Expanded(
                                                      child: Text(
                                                        DateFormat(
                                                          'dd MMM yyyy, hh:mm a',
                                                        ).format(match.date),
                                                        style: const TextStyle(
                                                          color: const Color(
                                                            0xFFA0A0A0,
                                                          ),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: match.isCompleted
                                                        ? const Color(
                                                            0xFF2E7D32,
                                                          ).withOpacity(0.15)
                                                        : const Color(
                                                            0xFFFFB300,
                                                          ).withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: match.isCompleted
                                                          ? const Color(
                                                              0xFF4CAF50,
                                                            ).withOpacity(0.5)
                                                          : const Color(
                                                              0xFFFFB300,
                                                            ).withOpacity(0.5),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    match.isCompleted
                                                        ? match.result
                                                        : 'In Progress',
                                                    style: TextStyle(
                                                      color: match.isCompleted
                                                          ? const Color(
                                                              0xFF4CAF50,
                                                            )
                                                          : const Color(
                                                              0xFFFFB300,
                                                            ),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (!match.isCompleted)
                                                ElevatedButton(
                                                  onPressed: () {
                                                    if (match.matchData !=
                                                            null &&
                                                        match.matchData['type'] ==
                                                            'single_mode') {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              SingleModeScreen(
                                                                match: match,
                                                              ),
                                                        ),
                                                      );
                                                    } else if (match
                                                                .matchData !=
                                                            null &&
                                                        match.matchData['type'] ==
                                                            'pair_mode') {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              PairModeScreen(
                                                                match: match,
                                                              ),
                                                        ),
                                                      );
                                                    } else {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              MatchScoreScreen(
                                                                match: match,
                                                              ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFFFB300),
                                                    foregroundColor:
                                                        const Color(0xFF0B0B0B),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    elevation: 4,
                                                  ),
                                                  child: const Text(
                                                    'RESUME',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                )
                                              else
                                                ElevatedButton(
                                                  onPressed: () {
                                                    if (match.matchData !=
                                                            null &&
                                                        match.matchData['type'] ==
                                                            'single_mode') {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              SingleModeScorecardScreen(
                                                                match: match,
                                                              ),
                                                        ),
                                                      );
                                                    } else if (match
                                                                .matchData !=
                                                            null &&
                                                        match.matchData['type'] ==
                                                            'pair_mode') {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              PairModeScorecardScreen(
                                                                match: match,
                                                              ),
                                                        ),
                                                      );
                                                    } else {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              ScorecardScreen(
                                                                match: match,
                                                              ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFD4AF37),
                                                    foregroundColor:
                                                        const Color(0xFF0B0B0B),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    elevation: 4,
                                                  ),
                                                  child: const Text(
                                                    'SCORECARD',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.white54,
                                                ),
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      backgroundColor: Theme.of(
                                                        context,
                                                      ).colorScheme.surface,
                                                      title: const Text(
                                                        'Delete Match',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      content: const Text(
                                                        'Are you sure you want to delete this match permanently?',
                                                        style: TextStyle(
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                              ),
                                                          child: const Text(
                                                            'Cancel',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .white54,
                                                            ),
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .redAccent,
                                                          ),
                                                          onPressed: () {
                                                            provider
                                                                .deleteMatch(
                                                                  match.id,
                                                                );
                                                            Navigator.pop(ctx);
                                                          },
                                                          child: const Text(
                                                            'Delete',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .animate()
                              .slideX(
                                begin: -0.2,
                                end: 0,
                                delay: (index * 50).ms,
                                curve: Curves.easeOutQuad,
                              )
                              .fadeIn();
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';

/// Daily motivation feed: one reflection per page, swipeable, with local
/// favorites. Slogans are community property; stoic lines are public domain.
class DailyMotivationScreen extends StatefulWidget {
  const DailyMotivationScreen({super.key});

  @override
  State<DailyMotivationScreen> createState() => _DailyMotivationScreenState();
}

class _Quote {
  final String text;
  final String source;
  const _Quote(this.text, this.source);
}

class _DailyMotivationScreenState extends State<DailyMotivationScreen> {
  static const String _prefsKey = 'motivation_favorites_v1';

  static const List<_Quote> _quotes = [
    _Quote('One day at a time.', 'Recovery saying'),
    _Quote('Progress, not perfection.', 'Recovery saying'),
    _Quote('Keep coming back. It works if you work it.', 'Recovery saying'),
    _Quote('You are not your worst day.', 'Recovery saying'),
    _Quote('First the person, then the path.', 'Recovery saying'),
    _Quote('Easy does it — but do it.', 'Recovery saying'),
    _Quote('The craving is a wave. You are the surfer.', 'Grounding wisdom'),
    _Quote('Play the tape forward.', 'Recovery saying'),
    _Quote('Rock bottom is a foundation, not an address.', 'Recovery saying'),
    _Quote('Ask for help before you need it.', 'Recovery saying'),
    _Quote('A journey of a thousand miles begins with a single step.', 'Laozi'),
    _Quote('We suffer more often in imagination than in reality.', 'Seneca'),
    _Quote('No man steps in the same river twice.', 'Heraclitus'),
    _Quote('You have power over your mind, not outside events.', 'Marcus Aurelius'),
    _Quote('The best revenge is not to be like your enemy.', 'Marcus Aurelius'),
    _Quote('Waste no more time arguing what a good life should be. Be one.', 'Marcus Aurelius'),
    _Quote('Difficulties strengthen the mind, as labor does the body.', 'Seneca'),
    _Quote('He who is brave is free.', 'Seneca'),
    _Quote('Begin at once to live, and count each separate day as a separate life.', 'Seneca'),
    _Quote('It is not death that a man should fear, but never beginning to live.', 'Marcus Aurelius'),
    _Quote('Fall seven times, stand up eight.', 'Japanese proverb'),
    _Quote('The wound is the place where the light enters you.', 'Rumi'),
    _Quote('What you seek is seeking you.', 'Rumi'),
    _Quote('Every moment is a fresh beginning.', 'T.S. Eliot'),
    _Quote('Courage is not the absence of fear, but moving with it.', 'Nelson Mandela (attr.)'),
    _Quote('Whether you think you can or you cannot, you are right.', 'Henry Ford'),
    _Quote('Do the thing and you will have the power.', 'Emerson'),
    _Quote('Little by little, one travels far.', 'Tolkien (attr.)'),
    _Quote('The only way out is through.', 'Robert Frost (paraphrase)'),
    _Quote('Today, you showed up. That was the whole assignment.', 'For you'),
  ];

  late PageController _pageController;
  int _page = 0;
  Set<int> _favorites = {};
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    // Deterministic daily start point — everyone's "quote of the day" rotates.
    final daySeed = DateTime.now().difference(DateTime(2026)).inDays;
    _page = daySeed % _quotes.length;
    _pageController = PageController(initialPage: _page);
    _loadFavorites();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (!mounted) return;
    setState(() {
      _favorites = raw == null
          ? <int>{}
          : (jsonDecode(raw) as List).map((e) => e as int).toSet();
    });
  }

  Future<void> _toggleFavorite(int index) async {
    setState(() {
      if (!_favorites.add(index)) _favorites.remove(index);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_favorites.toList()));
  }

  List<_Quote> get _visibleQuotes => _showFavoritesOnly
      ? [for (final i in _favorites) _quotes[i]]
      : _quotes;

  @override
  Widget build(BuildContext context) {
    final quotes = _visibleQuotes;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_showFavoritesOnly ? 'Favorites' : 'Daily Motivation',
            style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: _showFavoritesOnly ? 'Show all' : 'Show favorites',
            icon: Icon(
              _showFavoritesOnly ? Icons.format_list_numbered : Icons.star,
              color: Colors.amberAccent,
            ),
            onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
          ),
        ],
      ),
      body: quotes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_border, size: 56, color: AppColors.textDim),
                  const SizedBox(height: 16),
                  const Text('No favorites yet.',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the star on any quote to keep it close.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: quotes.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) {
                      final quote = quotes[i];
                      // Map back to the canonical index for favorite storage.
                      final canonical = _quotes.indexOf(quote);
                      final fav = _favorites.contains(canonical);
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.format_quote,
                                  color: AppColors.accent, size: 40),
                              const SizedBox(height: 24),
                              Text(
                                quote.text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                '— ${quote.source}',
                                style: const TextStyle(
                                    color: AppColors.accent, fontSize: 14),
                              ),
                              const SizedBox(height: 40),
                              IconButton(
                                tooltip: fav ? 'Remove favorite' : 'Add favorite',
                                icon: Icon(
                                  fav ? Icons.star : Icons.star_border,
                                  color: Colors.amberAccent,
                                  size: 34,
                                ),
                                onPressed: () => _toggleFavorite(canonical),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _page > 0
                            ? () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut)
                            : null,
                        icon: const Icon(Icons.chevron_left, color: Colors.white70),
                        label:
                            const Text('Prev', style: TextStyle(color: Colors.white70)),
                      ),
                      Text('${_page + 1} / ${quotes.length}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      TextButton.icon(
                        onPressed: _page < quotes.length - 1
                            ? () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut)
                            : null,
                        label:
                            const Text('Next', style: TextStyle(color: Colors.white70)),
                        icon: const Icon(Icons.chevron_right, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

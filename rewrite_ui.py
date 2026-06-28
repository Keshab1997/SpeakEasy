import os

filepath = "/Users/keshabsarkar/Vs Code Apps/Flutter-Spoken-English-App/lib/features/game/screens/modes/word_match_mode.dart"

with open(filepath, 'r') as f:
    content = f.read()

# Find the start of the build method
build_start_idx = content.find("  @override\n  Widget build(BuildContext context) {")

if build_start_idx == -1:
    print("Could not find build method")
    exit(1)

# Keep the first part
part1 = content[:build_start_idx]

# Define the new UI
new_ui = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF58CC02)),
            )
          : SafeArea(
              child: Column(
                children: [
                  _buildDuolingoHeader(),
                  _buildDuolingoInstruction(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildDuolingoCardColumn(_leftCards, isLeft: true),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDuolingoCardColumn(_rightCards, isLeft: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDuolingoHeader() {
    final progress = _totalPairs == 0 ? 0.0 : _matchedCount / _totalPairs;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.close_rounded,
              color: Color(0xFFAFAFAF),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 16,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        color: const Color(0xFF58CC02),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(top: 3, left: 6, right: 6, bottom: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFFC800), size: 28),
              const SizedBox(width: 4),
              AnimatedBuilder(
                animation: _scoreAnim,
                builder: (context, child) => Transform.scale(
                  scale: _scoreAnim.value,
                  child: Text(
                    '$_score',
                    style: const TextStyle(
                      color: Color(0xFFFFC800),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDuolingoInstruction() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      alignment: Alignment.centerLeft,
      child: const Text(
        'Tap the matching pairs',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4B4B4B),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildDuolingoCardColumn(List<_MatchCard> cards, {required bool isLeft}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: cards.map((card) {
        return Expanded(
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, child) {
              final shakeOffset = card.isWrong ? __import_math_sin(_shakeAnim.value * 3.14159 * 3) * 8 : 0.0;
              return Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: GestureDetector(
                onTap: () => isLeft ? _onLeftTap(card) : _onRightTap(card),
                child: _DuolingoDuoCard(card: card),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DuolingoDuoCard extends StatelessWidget {
  final _MatchCard card;

  const _DuolingoDuoCard({Key? key, required this.card}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (card.isMatched) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5E5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
        ),
      );
    }

    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFE5E5E5);
    Color bottomBorderColor = const Color(0xFFC4C4C4);
    Color textColor = const Color(0xFF4B4B4B);
    double bottomThickness = 4.0;
    double topTranslate = 0.0;

    if (card.isSelected) {
      bgColor = const Color(0xFFDDF4FF);
      borderColor = const Color(0xFF1CB0F6);
      bottomBorderColor = const Color(0xFF1CB0F6);
      textColor = const Color(0xFF1CB0F6);
      bottomThickness = 0.0;
      topTranslate = 4.0;
    } else if (card.isWrong) {
      bgColor = const Color(0xFFFFDFE0);
      borderColor = const Color(0xFFFF4B4B);
      bottomBorderColor = const Color(0xFFFF4B4B);
      textColor = const Color(0xFFFF4B4B);
      bottomThickness = 0.0;
      topTranslate = 4.0;
    }

    return Transform.translate(
      offset: Offset(0, topTranslate),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: bottomThickness > 0
              ? [
                  BoxShadow(
                    color: bottomBorderColor,
                    offset: Offset(0, bottomThickness),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          card.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: card.isBangla ? 16 : 15,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
"""

# Replace __import_math_sin with just sin since math is imported in the file at the top
new_ui = new_ui.replace("__import_math_sin", "sin")

with open(filepath, 'w') as f:
    f.write(part1 + new_ui)

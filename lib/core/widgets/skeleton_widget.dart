import 'package:flutter/material.dart';

class SkeletonWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonWidget({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonWidget> createState() => _SkeletonWidgetState();
}

class _SkeletonWidgetState extends State<SkeletonWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black)
                .withOpacity(_animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  final int lines;

  const SkeletonListTile({super.key, this.lines = 2});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const SkeletonWidget(width: 48, height: 48, borderRadius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonWidget(height: 14, width: 180),
                if (lines > 1) ...[
                  const SizedBox(height: 8),
                  const SkeletonWidget(height: 12, width: 240),
                ],
                if (lines > 2) ...[
                  const SizedBox(height: 6),
                  const SkeletonWidget(height: 12, width: 120),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final int lineCount;

  const SkeletonCard({super.key, this.lineCount = 3});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          lineCount,
          (i) => Padding(
            padding: EdgeInsets.only(top: i > 0 ? 10 : 0),
            child: SkeletonWidget(
              height: 14,
              width: i == lineCount - 1 ? 150 : double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}

class SkeletonParagraph extends StatelessWidget {
  final int lines;

  const SkeletonParagraph({super.key, this.lines = 4});

  @override
  Widget build(BuildContext context) {
    final widths = [1.0, 0.85, 0.6, 0.4];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              lines,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SkeletonWidget(
                  height: 14,
                  width: constraints.maxWidth * widths[i.clamp(0, widths.length - 1)],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SkeletonGrid extends StatelessWidget {
  final int itemCount;

  const SkeletonGrid({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) => _SkeletonGridCard(),
      ),
    );
  }
}

class _SkeletonGridCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonWidget(
            width: double.infinity,
            height: 80,
            borderRadius: 12,
          ),
          const SizedBox(height: 10),
          SkeletonWidget(width: double.infinity, height: 12),
          const SizedBox(height: 8),
          SkeletonWidget(width: 100, height: 12),
        ],
      ),
    );
  }
}

class SkeletonCourseCard extends StatelessWidget {
  const SkeletonCourseCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SkeletonWidget(width: 64, height: 64, borderRadius: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonWidget(width: 180, height: 16),
                const SizedBox(height: 8),
                SkeletonWidget(width: 120, height: 12),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SkeletonWidget(width: 60, height: 12),
                    const SizedBox(width: 16),
                    SkeletonWidget(width: 40, height: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonProgressHeader extends StatelessWidget {
  const SkeletonProgressHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SkeletonWidget(width: 48, height: 48, borderRadius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonWidget(width: 100, height: 14),
                const SizedBox(height: 6),
                SkeletonWidget(width: 60, height: 12),
              ],
            ),
          ),
          SkeletonWidget(width: 80, height: 36, borderRadius: 18),
        ],
      ),
    );
  }
}

enum SkeletonType { list, grid, detail }

class SkeletonPage extends StatelessWidget {
  final SkeletonType type;
  final String? title;

  const SkeletonPage({super.key, required this.type, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title != null
            ? Text(title!, style: const TextStyle(fontWeight: FontWeight.w900))
            : null,
      ),
      body: switch (type) {
        SkeletonType.list => ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            itemBuilder: (_, __) => const SkeletonListTile(),
          ),
        SkeletonType.grid => const SingleChildScrollView(
            child: Column(
              children: [
                SkeletonProgressHeader(),
                SkeletonGrid(),
              ],
            ),
          ),
        SkeletonType.detail => const SingleChildScrollView(
            child: Column(
              children: [
                SkeletonProgressHeader(),
                SkeletonParagraph(lines: 4),
                SizedBox(height: 16),
                SkeletonCourseCard(),
                SkeletonCourseCard(),
              ],
            ),
          ),
      },
    );
  }
}

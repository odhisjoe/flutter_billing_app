import 'dart:math';
import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 900;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  static T of<T>(BuildContext context, {required T mobile, T? tablet, required T desktop}) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context) && tablet != null) return tablet!;
    return mobile;
  }
}

extension ResponsiveGrid on int {
  int gridColumns(double width) {
    if (width >= 1200) return this;
    if (width >= 900) return max(1, this - 1);
    if (width >= 600) return max(1, (this / 2).ceil());
    return max(1, (this / 3).ceil());
  }
}

class ResponsiveTableLayout extends StatelessWidget {
  final List<Widget> headerCells;
  final List<Widget> dataRows;
  final double? minTabletWidth;
  final double? baseWidth;

  const ResponsiveTableLayout({
    super.key,
    required this.headerCells,
    required this.dataRows,
    this.minTabletWidth = 640,
    this.baseWidth,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= (baseWidth ?? minTabletWidth!)) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: headerCells),
            ...dataRows,
          ],
        ),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Swipe horizontally to see all columns',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: headerCells),
              ...dataRows,
            ],
          ),
        ),
      ],
    );
  }
}

class ResponsiveBreakpoints {
  static const double mobile = 0;
  static const double tablet = 768;
  static const double desktop = 1024;
  static const double maxContentWidth = 1200;
}

class Responsive {
  static bool isMobile(double width) => width < ResponsiveBreakpoints.tablet;
  static bool isTablet(double width) =>
      width >= ResponsiveBreakpoints.tablet && width < ResponsiveBreakpoints.desktop;
  static bool isDesktop(double width) => width >= ResponsiveBreakpoints.desktop;
}




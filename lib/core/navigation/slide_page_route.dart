import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Smooth transition from right to left (and left to right on pop).
/// On iOS: natively enables edge swipe-to-back (balayage gauche -> droite pour pop).
/// On Android and other platforms: uses custom slide transition.
class SlideRightToLeftRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T> {
  final Widget page;

  SlideRightToLeftRoute({
    required this.page,
    super.settings,
  });

  @override
  Widget buildContent(BuildContext context) => page;

  @override
  String? get title => null;

  @override
  bool get maintainState => true;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => true;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => true;

  @override
  bool get popGestureEnabled => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 280);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Sur iOS uniquement : active la transition et le geste de balayage gauche -> droite
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    // Sur Android ou autres plateformes : transition coulissante personnalisée
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeOutCubic;

    final tween = Tween(begin: begin, end: end).chain(
      CurveTween(curve: curve),
    );

    return SlideTransition(
      position: animation.drive(tween),
      child: child,
    );
  }
}

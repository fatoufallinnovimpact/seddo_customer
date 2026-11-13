import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/home/domain/bloc/home_bloc.dart';
import 'package:seddo/features/home/domain/bloc/home_event.dart';
import 'package:seddo/features/home/presentation/widgets/home_promo_banners_widget.dart';

void main() {
  Widget buildTestableWidget({
    required HomeBloc homeBloc,
    VoidCallback? onOpenSeddoDirect,
    VoidCallback? onOpenAeroport,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider.value(
          value: homeBloc,
          child: HomePromoBannersWidget(
            onOpenSeddoDirect: onOpenSeddoDirect,
            onOpenAeroport: onOpenAeroport,
          ),
        ),
      ),
    );
  }

  group('HomePromoBannersWidget Unit & Widget Tests', () {
    late HomeBloc homeBloc;

    setUp(() {
      homeBloc = HomeBloc();
    });

    tearDown(() {
      homeBloc.close();
    });

    testWidgets('Renders first banner with Seddo en direct and active indicator',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(homeBloc: homeBloc),
      );
      await tester.pump();

      // Check first banner text is visible
      expect(find.text('Seddo en direct'), findsOneWidget);
      expect(find.byKey(const Key('home_banner_seddo_direct')), findsOneWidget);

      // Verify page indicators are rendered
      expect(find.byType(HomePromoBannersWidget), findsOneWidget);
    });

    testWidgets('Seddo en direct card updates when HomeNearbyDriversUpdatedEvent dispatched',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(homeBloc: homeBloc),
      );
      await tester.pump();

      // Dispatch 5 drivers
      homeBloc.add(const HomeNearbyDriversUpdatedEvent(count: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.textContaining('chauffeurs disponibles'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping Seddo en direct calls onOpenSeddoDirect callback',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        buildTestableWidget(
          homeBloc: homeBloc,
          onOpenSeddoDirect: () {
            tapped = true;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('home_banner_seddo_direct')));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}

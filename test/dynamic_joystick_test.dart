import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/widgets/virtual_joystick.dart';

void main() {
  testWidgets('dynamic joystick reports screen-space drag and releases',
      (tester) async {
    JoystickDrag? reported;
    var releases = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: DynamicJoystick(
              onDrag: (drag) => reported = drag,
              onRelease: () => releases++,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(100, 300));
    await gesture.moveTo(const Offset(140, 280));
    await tester.pump();

    expect(reported, isNotNull);
    expect(reported!.origin, const Offset(100, 300));
    expect(reported!.current, const Offset(140, 280));
    expect(reported!.normalized.dx, greaterThan(0));
    expect(reported!.normalized.dy, lessThan(0));

    await gesture.up();
    await tester.pump();
    expect(releases, 1);
  });
}

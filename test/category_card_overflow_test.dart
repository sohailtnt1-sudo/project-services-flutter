// Regression test for the home category grid "BOTTOM OVERFLOWED BY 12 PIXELS"
// bug (15 Nov 2026, user phone screenshot): cards whose names wrap to two
// lines ("Security & Technology", "Computer Hardware & Software") overflowed
// the fixed card height at childAspectRatio 0.78 with a 2-line description.
//
// The test pumps a grid with the same delegate and the same card structure as
// _CategoryCard in lib/screens/customer_shell.dart, using the real seeded
// category names/descriptions, on a 720x1280 phone surface, and asserts no
// overflow error is reported. Real Roboto is loaded (the default test font
// Ahem has different metrics and would not reproduce the bug), and the
// "reproduces the bug" case runs at textScaleFactor 1.2, matching the
// 12px overflow seen on the user's phone.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Real seeded categories (supabase/migrations/001_initial_schema.sql).
const _categories = <(String, String)>[
  ('Electrical',
      'Electricians for wiring, fans, switches, breakers and home electrical work.'),
  ('Plumbing', 'Plumbers for leaks, taps, pipes, drains and bathroom fittings.'),
  ('Solar Installation',
      'Solar panel and inverter installation for homes and offices.'),
  ('Appliance Repair',
      'Repair for refrigerators, washing machines, microwaves and other home appliances.'),
  ('Security & Technology',
      'CCTV installation, Wi-Fi setup, networking and smart home installation.'),
  ('Home Services',
      'Carpenters, painters, furniture repair and general home maintenance.'),
  ('Computer Hardware & Software',
      'Computer repair, upgrades, software installation and troubleshooting.'),
];

Future<void> _loadRoboto() async {
  final candidates = <String>[
    '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts',
    '../../flutter/bin/cache/artifacts/material_fonts',
  ];
  for (final dir in candidates) {
    final regular = File('$dir/Roboto-Regular.ttf');
    final bold = File('$dir/Roboto-Bold.ttf');
    if (await regular.exists() && await bold.exists()) {
      final loader = FontLoader('Roboto')
        ..addFont(
            Future.value(ByteData.view(regular.readAsBytesSync().buffer)))
        ..addFont(Future.value(ByteData.view(bold.readAsBytesSync().buffer)));
      await loader.load();
      return;
    }
  }
}

Future<void> _pumpGrid(
  WidgetTester tester, {
  required double ratio,
  required int descMaxLines,
  double textScaleFactor = 1.0,
}) async {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  Widget card(String name, String description) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 96, color: Colors.teal.shade100),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.teal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(description,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                      maxLines: descMaxLines,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
            textScaler: TextScaler.linear(textScaleFactor)),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: ratio,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final (name, description) = _categories[i];
                return card(name, description);
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(_loadRoboto);

  testWidgets('category grid does not overflow at 720x1280',
      (WidgetTester tester) async {
    await _pumpGrid(tester, ratio: 0.70, descMaxLines: 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category grid does not overflow with larger system text',
      (WidgetTester tester) async {
    await _pumpGrid(tester,
        ratio: 0.70, descMaxLines: 1, textScaleFactor: 1.2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old sizing (0.78 + 2-line description) overflows at 1.2x text',
      (WidgetTester tester) async {
    await _pumpGrid(tester,
        ratio: 0.78, descMaxLines: 2, textScaleFactor: 1.2);
    expect(tester.takeException(), isNotNull);
  });
}

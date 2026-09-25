import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huepop/main.dart';

void main() {
  testWidgets('HuePop launches', (tester) async {
    await tester.pumpWidget(const HuePopApp());
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
}

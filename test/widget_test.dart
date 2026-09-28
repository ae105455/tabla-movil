import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tablas/main.dart';

void main() {
  testWidgets('muestra y permite ampliar el formulario de baile', (tester) async {
    await tester.pumpWidget(const DanceEvaluationApp());

    expect(find.text('Formulario de evaluación de baile'), findsOneWidget);
    expect(find.text('Agregar participante'), findsOneWidget);

    await tester.tap(find.text('Agregar participante'));
    await tester.pump();

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('muestra el guardado en MySQL y evita enviar filas vacías', (tester) async {
    await tester.pumpWidget(const DanceEvaluationApp());

    expect(find.text('Guardar en MySQL'), findsOneWidget);
    await tester.tap(find.text('Guardar en MySQL'));
    await tester.pump();

    expect(find.text('Escribe el nombre de al menos un participante.'), findsOneWidget);
  });

  testWidgets('calcula el total de los cuatro criterios', (tester) async {
    await tester.pumpWidget(const DanceEvaluationApp());

    final scoreFields = find.byType(TextField);
    await tester.enterText(scoreFields.at(11), '20');
    await tester.enterText(scoreFields.at(12), '22');
    await tester.enterText(scoreFields.at(13), '24');
    await tester.enterText(scoreFields.at(14), '25');
    await tester.pump();

    expect(find.text('91'), findsOneWidget);
  });
}

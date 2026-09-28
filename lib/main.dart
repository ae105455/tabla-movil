import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'evaluation_api.dart';

// Punto de entrada de la aplicación Flutter.
void main() => runApp(const DanceEvaluationApp());

// Configura el tema general y la pantalla inicial de la aplicación.
class DanceEvaluationApp extends StatelessWidget {
  const DanceEvaluationApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp proporciona el tema, el título y la navegación principal.
    return MaterialApp(
      title: 'Formulario de evaluación de baile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff175c58),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff3f6f4),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
      home: const DanceEvaluationPage(),
    );
  }
}

// Pantalla principal donde se capturan y califican los participantes.
class DanceEvaluationPage extends StatefulWidget {
  const DanceEvaluationPage({super.key});

  @override
  State<DanceEvaluationPage> createState() => _DanceEvaluationPageState();
}

class _DanceEvaluationPageState extends State<DanceEvaluationPage> {
  static const _apiEndpoint = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost/tabla-movil/backend/api/evaluaciones.php',
  );

  final _api = EvaluationApi();
  // Controladores para los datos generales del jurado.
  final _juryController = TextEditingController();
  final _dateController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;

  // Lista de filas que aparecen en la tabla de evaluación.
  final List<_DanceRow> _rows = [_DanceRow()];

  @override
  void dispose() {
    // Libera los controladores cuando la pantalla deja de utilizarse.
    _juryController.dispose();
    _dateController.dispose();
    _api.close();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  // Agrega una nueva fila vacía para registrar otro participante.
  void _addRow() => setState(() => _rows.add(_DanceRow()));

  Future<void> _loadRows() async {
    setState(() => _isLoading = true);
    try {
      final records = await _api.getAll(_apiEndpoint);
      final loadedRows = records.map(_DanceRow.fromJson).toList();
      setState(() {
        for (final row in _rows) {
          row.dispose();
        }
        _rows
          ..clear()
          ..addAll(loadedRows.isEmpty ? [_DanceRow()] : loadedRows);
      });
      _showMessage('Se cargaron ${records.length} evaluaciones.');
    } catch (error) {
      _showMessage(
        'No se pudieron cargar las evaluaciones: $error',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRow(_DanceRow row) async {
    final error = _validationError(row);
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (row.id == null) {
        row.id = await _api.create(_apiEndpoint, row.toJson());
        _showMessage('Evaluación guardada en MySQL.');
      } else {
        await _api.update(_apiEndpoint, row.id!, row.toJson());
        _showMessage('Evaluación actualizada en MySQL.');
      }
    } catch (error) {
      _showMessage('No se pudo guardar la evaluación: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAllRows() async {
    final rowsToSave = _rows.where((row) => row.hasContent).toList();
    if (rowsToSave.isEmpty) {
      _showMessage(
        'Escribe el nombre de al menos un participante.',
        isError: true,
      );
      return;
    }

    for (final row in rowsToSave) {
      final error = _validationError(row);
      if (error != null) {
        _showMessage('Fila ${_rows.indexOf(row) + 1}: $error', isError: true);
        return;
      }
    }

    setState(() => _isSaving = true);
    var savedCount = 0;
    try {
      for (final row in rowsToSave) {
        if (row.id == null) {
          row.id = await _api.create(_apiEndpoint, row.toJson());
        } else {
          await _api.update(_apiEndpoint, row.id!, row.toJson());
        }
        savedCount++;
      }
      _showMessage('Se guardaron $savedCount evaluaciones en MySQL.');
    } catch (error) {
      _showMessage(
        savedCount == 0
            ? 'No se pudo guardar en MySQL: $error'
            : 'Se guardaron $savedCount filas; ocurrió un error: $error',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _validationError(_DanceRow row) {
    if (row.participant.text.trim().isEmpty) {
      return 'Escribe el nombre del participante antes de guardar.';
    }
    final scores = [
      row.techniqueScore,
      row.expressionScore,
      row.choreographyScore,
      row.costumeScore,
    ];
    if (scores.any((score) {
      final text = score.text.trim();
      if (text.isEmpty) return false;
      final value = int.tryParse(text);
      return value == null || value < 0 || value > 25;
    })) {
      return 'Las calificaciones deben ser números entre 0 y 25.';
    }
    return null;
  }

  Future<void> _deleteRow(_DanceRow row) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar evaluación'),
        content: const Text('¿Deseas eliminar este participante?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    if (row.id != null) {
      setState(() => _isSaving = true);
      try {
        await _api.delete(_apiEndpoint, row.id!);
      } catch (error) {
        _showMessage(
          'No se pudo eliminar la evaluación: $error',
          isError: true,
        );
        if (mounted) setState(() => _isSaving = false);
        return;
      }
      if (mounted) setState(() => _isSaving = false);
    }

    if (!mounted) return;
    setState(() {
      row.dispose();
      _rows.remove(row);
      if (_rows.isEmpty) _rows.add(_DanceRow());
    });
    _showMessage('Evaluación eliminada.');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  // Construye el PDF y abre la opción de descargarlo o compartirlo.
  Future<void> _generateForm() async {
    final document = pw.Document();

    // Encabezados que se mostrarán en la tabla del documento PDF.
    const headers = [
      'N.º',
      'Participante / grupo',
      'Soc.',
      'Cont.',
      'Exp.',
      'Inter.',
      'Tecn.',
      'Creat.',
      'Disc.',
      'Mat.',
      'Turno',
      'Titulo del baile',
      'Tecnica',
      'Expresion',
      'Coreografia',
      'Vestuario',
      'Total',
    ];

    // El formato horizontal permite mostrar todas las columnas de la tabla.
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Formulario de evaluacion de baile',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            // Convierte las filas de Flutter en una tabla para el PDF.
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: List.generate(_rows.length, (index) {
                final row = _rows[index];
                return [
                  '${index + 1}',
                  row.participant.text,
                  row.social.text,
                  row.control.text,
                  row.expression.text,
                  row.interpretation.text,
                  row.technique.text,
                  row.creativity.text,
                  row.discipline.text,
                  row.matter.text,
                  row.shift.text,
                  row.title.text,
                  row.techniqueScore.text,
                  row.expressionScore.text,
                  row.choreographyScore.text,
                  row.costumeScore.text,
                  '${row.total}',
                ];
              }),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 6,
              ),
              cellStyle: const pw.TextStyle(fontSize: 6),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.teal100,
              ),
              cellAlignment: pw.Alignment.center,
              border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Nombre del jurado: ${_juryController.text}'),
            pw.SizedBox(height: 8),
            pw.Text(
              'Fecha: ${_dateController.text}     Firma: ______________________________',
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'formulario_evaluacion_baile.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold organiza la barra superior y el contenido de la pantalla.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evaluación de baile'),
        backgroundColor: const Color(0xff175c58),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Formulario de evaluación de baile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff174b49),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Registra la presentación y califica cada criterio sobre 25 puntos.',
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _loadRows,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('Cargar desde MySQL'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveAllRows,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving ? 'Guardando...' : 'Guardar en MySQL',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Botón principal visible antes de la tabla de evaluación.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _generateForm,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Generar formulario'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Tabla editable con los participantes y sus calificaciones.
                  _buildTable(),
                  const SizedBox(height: 20),
                  // Campos adicionales para identificar al jurado.
                  _buildJurySection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    // Títulos de las columnas visibles en la tabla de la aplicación.
    const headers = [
      'N.º',
      'Participante / grupo',
      'Soc.',
      'Cont.',
      'Exp.',
      'Inter.',
      'Técn.',
      'Creat.',
      'Disc.',
      'Mat.',
      'Turno',
      'Título del baile',
      'Técnica\n25',
      'Expresión\n25',
      'Coreografía\n25',
      'Vestuario\n25',
      'Total\n100',
      'Acciones',
    ];
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Permite desplazarse horizontalmente cuando la pantalla es pequeña.
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xffdcebe7)),
              dataRowMinHeight: 72,
              dataRowMaxHeight: 86,
              columnSpacing: 10,
              columns: headers
                  .map(
                    (header) => DataColumn(
                      label: Text(header, textAlign: TextAlign.center),
                    ),
                  )
                  .toList(),
              rows: List.generate(_rows.length, (index) => _buildRow(index)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: const Text('Agregar participante'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Construye visualmente una fila y conecta sus campos con _DanceRow.
  DataRow _buildRow(int index) {
    final row = _rows[index];
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(_cell(row.participant, 150)),
        DataCell(_cell(row.social, 62)),
        DataCell(_cell(row.control, 62)),
        DataCell(_cell(row.expression, 62)),
        DataCell(_cell(row.interpretation, 62)),
        DataCell(_cell(row.technique, 62)),
        DataCell(_cell(row.creativity, 62)),
        DataCell(_cell(row.discipline, 62)),
        DataCell(_cell(row.matter, 62)),
        DataCell(_cell(row.shift, 70)),
        DataCell(_cell(row.title, 150)),
        DataCell(_scoreCell(row.techniqueScore, row)),
        DataCell(_scoreCell(row.expressionScore, row)),
        DataCell(_scoreCell(row.choreographyScore, row)),
        DataCell(_scoreCell(row.costumeScore, row)),
        DataCell(
          Text(
            '${row.total}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: row.id == null
                    ? 'Guardar en MySQL'
                    : 'Actualizar en MySQL',
                onPressed: _isSaving ? null : () => _saveRow(row),
                icon: const Icon(Icons.save_outlined),
              ),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: _isSaving ? null : () => _deleteRow(row),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Crea una celda de texto con un ancho fijo para mantener alineada la tabla.
  Widget _cell(TextEditingController controller, double width) => SizedBox(
    width: width,
    child: TextField(controller: controller, textAlign: TextAlign.center),
  );

  // Crea una celda numérica y actualiza el total cada vez que cambia la nota.
  Widget _scoreCell(TextEditingController controller, _DanceRow row) =>
      SizedBox(
        width: 72,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          onChanged: (_) => setState(() {}),
        ),
      );

  // Construye la sección donde se escriben los datos del jurado.
  Widget _buildJurySection() => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 20,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _juryController,
              decoration: const InputDecoration(labelText: 'Nombre del jurado'),
            ),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Fecha'),
            ),
          ),
          const SizedBox(
            width: 240,
            child: TextField(
              decoration: InputDecoration(labelText: 'Firma del jurado'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Representa una fila de datos de la evaluación de baile.
///
/// Guarda la información del participante, los datos de su presentación,
/// las calificaciones de cada criterio y calcula el total sobre 100 puntos.
class _DanceRow {
  int? id;

  _DanceRow();

  _DanceRow.fromJson(Map<String, dynamic> json) {
    id = int.tryParse('${json['id']}');
    participant.text = '${json['participant'] ?? ''}';
    social.text = '${json['social'] ?? ''}';
    control.text = '${json['control'] ?? ''}';
    expression.text = '${json['expression'] ?? ''}';
    interpretation.text = '${json['interpretation'] ?? ''}';
    technique.text = '${json['technique'] ?? ''}';
    creativity.text = '${json['creativity'] ?? ''}';
    discipline.text = '${json['discipline'] ?? ''}';
    matter.text = '${json['matter'] ?? ''}';
    shift.text = '${json['shift'] ?? ''}';
    title.text = '${json['title'] ?? ''}';
    techniqueScore.text = '${json['technique_score'] ?? 0}';
    expressionScore.text = '${json['expression_score'] ?? 0}';
    choreographyScore.text = '${json['choreography_score'] ?? 0}';
    costumeScore.text = '${json['costume_score'] ?? 0}';
  }

  // Controladores para los datos descriptivos del participante.
  final participant = TextEditingController();
  final social = TextEditingController();
  final control = TextEditingController();
  final expression = TextEditingController();
  final interpretation = TextEditingController();
  final technique = TextEditingController();
  final creativity = TextEditingController();
  final discipline = TextEditingController();
  final matter = TextEditingController();
  final shift = TextEditingController();
  final title = TextEditingController();

  // Controladores de las cuatro notas que forman el total sobre 100.
  final techniqueScore = TextEditingController();
  final expressionScore = TextEditingController();
  final choreographyScore = TextEditingController();
  final costumeScore = TextEditingController();

  bool get hasContent => [
    participant,
    social,
    control,
    expression,
    interpretation,
    technique,
    creativity,
    discipline,
    matter,
    shift,
    title,
    techniqueScore,
    expressionScore,
    choreographyScore,
    costumeScore,
  ].any((controller) => controller.text.trim().isNotEmpty);

  // Suma las cuatro calificaciones; los campos vacíos cuentan como cero.
  int get total =>
      [techniqueScore, expressionScore, choreographyScore, costumeScore]
          .map((controller) => int.tryParse(controller.text) ?? 0)
          .fold(0, (sum, score) => sum + score);

  Map<String, dynamic> toJson() => {
    'participant': participant.text.trim(),
    'social': social.text.trim(),
    'control': control.text.trim(),
    'expression': expression.text.trim(),
    'interpretation': interpretation.text.trim(),
    'technique': technique.text.trim(),
    'creativity': creativity.text.trim(),
    'discipline': discipline.text.trim(),
    'matter': matter.text.trim(),
    'shift': shift.text.trim(),
    'title': title.text.trim(),
    'technique_score': int.tryParse(techniqueScore.text) ?? 0,
    'expression_score': int.tryParse(expressionScore.text) ?? 0,
    'choreography_score': int.tryParse(choreographyScore.text) ?? 0,
    'costume_score': int.tryParse(costumeScore.text) ?? 0,
  };

  void dispose() {
    // Libera todos los controladores pertenecientes a esta fila.
    for (final controller in [
      participant,
      social,
      control,
      expression,
      interpretation,
      technique,
      creativity,
      discipline,
      matter,
      shift,
      title,
      techniqueScore,
      expressionScore,
      choreographyScore,
      costumeScore,
    ]) {
      controller.dispose();
    }
  }
}

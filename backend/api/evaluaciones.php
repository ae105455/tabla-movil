<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

function respond(int $status, array $payload): void
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function readRecord(array $input): array
{
    $textFields = [
        'participant' => 160,
        'social' => 120,
        'control' => 120,
        'expression' => 120,
        'interpretation' => 120,
        'technique' => 120,
        'creativity' => 120,
        'discipline' => 120,
        'matter' => 120,
        'shift' => 70,
        'title' => 160,
    ];
    $record = [];

    foreach ($textFields as $field => $maxLength) {
        $value = $input[$field] ?? '';
        if (!is_string($value) && !is_numeric($value)) {
            respond(422, ['error' => "El campo $field debe ser texto."]);
        }
        $value = trim((string) $value);
        if (mb_strlen($value) > $maxLength) {
            respond(422, ['error' => "El campo $field supera $maxLength caracteres."]);
        }
        $record[$field] = $value;
    }

    if ($record['participant'] === '') {
        respond(422, ['error' => 'El nombre del participante es obligatorio.']);
    }

    foreach ([
        'technique_score',
        'expression_score',
        'choreography_score',
        'costume_score',
    ] as $field) {
        $value = filter_var($input[$field] ?? 0, FILTER_VALIDATE_INT);
        if ($value === false || $value < 0 || $value > 25) {
            respond(422, ['error' => "El campo $field debe ser un número entre 0 y 25."]);
        }
        $record[$field] = $value;
    }

    return $record;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if ($method === 'OPTIONS') {
    http_response_code(204);
    exit;
}

try {
    $host = getenv('MYSQL_HOST') ?: '127.0.0.1';
    $database = getenv('MYSQL_DATABASE') ?: 'tabla_movil';
    $username = getenv('MYSQL_USER') ?: 'root';
    $password = getenv('MYSQL_PASSWORD') ?: '';
    $pdo = new PDO(
        "mysql:host=$host;dbname=$database;charset=utf8mb4",
        $username,
        $password,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );

    if ($method === 'GET') {
        $records = $pdo->query('SELECT * FROM evaluaciones ORDER BY id DESC')->fetchAll();
        respond(200, ['data' => $records]);
    }

    if ($method === 'POST' || $method === 'PUT') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            respond(400, ['error' => 'El cuerpo debe contener un objeto JSON.']);
        }
        $record = readRecord($input);

        if ($method === 'POST') {
            $columns = implode(', ', array_keys($record));
            $placeholders = implode(', ', array_map(static fn ($field) => ":$field", array_keys($record)));
            $statement = $pdo->prepare("INSERT INTO evaluaciones ($columns) VALUES ($placeholders)");
            $statement->execute($record);
            respond(201, ['data' => ['id' => (int) $pdo->lastInsertId()]]);
        }

        $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        if ($id === false || $id === null) {
            respond(400, ['error' => 'Se requiere un id válido para actualizar.']);
        }
        $exists = $pdo->prepare('SELECT id FROM evaluaciones WHERE id = :id');
        $exists->execute(['id' => $id]);
        if ($exists->fetchColumn() === false) {
            respond(404, ['error' => 'No se encontró la evaluación.']);
        }

        $assignments = implode(', ', array_map(static fn ($field) => "$field = :$field", array_keys($record)));
        $statement = $pdo->prepare("UPDATE evaluaciones SET $assignments WHERE id = :id");
        $statement->execute(array_merge($record, ['id' => $id]));
        respond(200, ['data' => ['id' => $id]]);
    }

    if ($method === 'DELETE') {
        $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        if ($id === false || $id === null) {
            respond(400, ['error' => 'Se requiere un id válido para eliminar.']);
        }
        $statement = $pdo->prepare('DELETE FROM evaluaciones WHERE id = :id');
        $statement->execute(['id' => $id]);
        if ($statement->rowCount() === 0) {
            respond(404, ['error' => 'No se encontró la evaluación.']);
        }
        respond(200, ['data' => ['id' => $id]]);
    }

    header('Allow: GET, POST, PUT, DELETE, OPTIONS');
    respond(405, ['error' => 'Método HTTP no permitido.']);
} catch (PDOException $error) {
    respond(500, ['error' => 'No se pudo conectar o consultar MySQL.']);
} catch (Throwable $error) {
    respond(500, ['error' => 'Error interno de la API.']);
}
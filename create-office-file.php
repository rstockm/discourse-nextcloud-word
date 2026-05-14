<?php
header('Content-Type: application/json');

// Config laden
require_once 'config.php';

// CORS-Header
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (in_array($origin, ALLOWED_ORIGINS)) {
    header("Access-Control-Allow-Origin: $origin");
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
}

// OPTIONS-Request für CORS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Nur POST erlaubt
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Nur POST-Requests erlaubt']);
    exit;
}

function getRequestInput() {
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';

    if (stripos($contentType, 'application/json') !== false) {
        $jsonInput = json_decode(file_get_contents('php://input'), true);
        if (is_array($jsonInput)) {
            return $jsonInput;
        }
    }

    return $_POST;
}

function sanitizeFileName($fileName) {
    $fileName = trim((string)$fileName);
    $fileName = preg_replace('/[<>:"\/\\\\|?*\x00-\x1f]/', '', $fileName);
    $fileName = preg_replace('/\.{2,}/', '.', $fileName);
    $fileName = trim($fileName, ". \t\n\r\0\x0B");
    $fileName = preg_replace('/\s{2,}/', ' ', $fileName);
    $fileName = substr($fileName, 0, 200);

    return trim($fileName) ?: 'Document';
}

function buildNextcloudPath($targetFolder, $fileName) {
    $path = trim((string)$targetFolder . '/' . (string)$fileName, '/');
    $segments = array_filter(array_map('trim', explode('/', $path)), function ($segment) {
        return $segment !== '';
    });

    return '/' . implode('/', $segments);
}

function encodePathForWebDav($path) {
    $segments = array_filter(explode('/', trim($path, '/')), function ($segment) {
        return $segment !== '';
    });

    return implode('/', array_map('rawurlencode', $segments));
}

// Request-Daten
$input = getRequestInput();
$fileType = $input['fileType'] ?? 'docx'; // docx, xlsx, pptx
$fileName = $input['fileName'] ?? null;
// Passwort-Parameter: null oder leerer String werden zu leerem String normalisiert
$sharePassword = isset($input['sharePassword']) && $input['sharePassword'] !== null 
    ? trim($input['sharePassword']) 
    : ''; // Optional: Passwort für Share-Schutz

// Debug-Logging (kann später entfernt werden)
error_log("Nextcloud API Call - FileType: $fileType, FileName: $fileName, HasPassword: " . (!empty($sharePassword) ? 'yes' : 'no'));

// Validierung des Dateityps
$validTypes = ['docx', 'xlsx', 'pptx'];
if (!in_array($fileType, $validTypes)) {
    http_response_code(400);
    echo json_encode(['error' => 'Ungültiger Dateityp']);
    exit;
}

// Dateiname generieren falls nicht angegeben
if (!$fileName) {
    $fileName = FILE_PREFIX . date('Y-m-d_H-i-s') . '.' . $fileType;
} else {
    $fileName = sanitizeFileName($fileName);

    // Sicherstellen, dass korrekte Extension vorhanden ist
    if (!str_ends_with($fileName, '.' . $fileType)) {
        $fileName .= '.' . $fileType;
    }
}

// Pfad zur Template-Datei
$templatePath = __DIR__ . '/template.' . $fileType;
if (!file_exists($templatePath)) {
    http_response_code(500);
    echo json_encode(['error' => 'Template-Datei nicht gefunden: ' . $fileType]);
    exit;
}

// WebDAV-URL zum Hochladen
$filePath = buildNextcloudPath(NEXTCLOUD_TARGET_FOLDER, $fileName);
$webdavUrl = NEXTCLOUD_URL . '/remote.php/dav/files/' . rawurlencode(NEXTCLOUD_USERNAME) . '/' . encodePathForWebDav($filePath);

// Datei erstellen via WebDAV
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $webdavUrl);
curl_setopt($ch, CURLOPT_USERPWD, NEXTCLOUD_USERNAME . ':' . NEXTCLOUD_PASSWORD);
curl_setopt($ch, CURLOPT_PUT, true);
curl_setopt($ch, CURLOPT_INFILE, fopen($templatePath, 'r'));
curl_setopt($ch, CURLOPT_INFILESIZE, filesize($templatePath));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode !== 201 && $httpCode !== 204) {
    http_response_code(500);
    echo json_encode(['error' => 'Fehler beim Erstellen der Datei', 'httpCode' => $httpCode]);
    exit;
}

// Share-Link erstellen via OCS API
$ocsUrl = NEXTCLOUD_URL . '/ocs/v2.php/apps/files_sharing/api/v1/shares';
$shareData = [
    'path' => $filePath,
    'shareType' => 3,
    'permissions' => 3  // Read + Write (wie bisher)
];

// Passwort hinzufügen, falls gesetzt
if (!empty($sharePassword)) {
    $shareData['password'] = $sharePassword; // Bereits getrimmt oben
    error_log("Nextcloud Share: Adding password protection");
} else {
    error_log("Nextcloud Share: No password (URL-based access)");
}

$shareData = http_build_query($shareData);

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $ocsUrl);
curl_setopt($ch, CURLOPT_USERPWD, NEXTCLOUD_USERNAME . ':' . NEXTCLOUD_PASSWORD);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $shareData);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/x-www-form-urlencoded',
    'OCS-APIRequest: true',
    'Accept: application/json'
]);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

if ($httpCode !== 200) {
    error_log("Nextcloud Share API Error - HTTP Code: $httpCode, Response: $response, cURL Error: $curlError");
    error_log("Share Data sent: " . print_r($shareData, true));
    
    // Versuche Fehlermeldung aus Nextcloud-Response zu extrahieren
    $errorMessage = 'Fehler beim Erstellen des Share-Links';
    $nextcloudError = null;
    
    // JSON-Response parsen
    $errorData = json_decode($response, true);
    if ($errorData && isset($errorData['ocs']['meta']['message'])) {
        $nextcloudError = $errorData['ocs']['meta']['message'];
        $errorMessage = $nextcloudError;
    } elseif (strpos($response, '<?xml') !== false || strpos($response, '<ocs>') !== false) {
        // XML-Response parsen
        $xml = @simplexml_load_string($response);
        if ($xml !== false && isset($xml->meta->message)) {
            $nextcloudError = (string)$xml->meta->message;
            $errorMessage = $nextcloudError;
        }
    }
    
    http_response_code($httpCode >= 400 && $httpCode < 500 ? $httpCode : 500);
    echo json_encode([
        'success' => false,
        'error' => $errorMessage,
        'httpCode' => $httpCode,
        'nextcloudError' => $nextcloudError,
        'response' => $response,
        'curlError' => $curlError ?: null
    ]);
    exit;
}

// Nextcloud OCS API gibt XML zurück, auch wenn JSON angefordert wird
$shareUrl = null;
if (strpos($response, '<?xml') !== false || strpos($response, '<ocs>') !== false) {
    // XML-Response parsen
    $xml = @simplexml_load_string($response);
    if ($xml !== false) {
        $shareUrl = (string)($xml->data->url ?? '');
        error_log("Nextcloud Share URL from XML: $shareUrl");
    } else {
        error_log("Failed to parse XML response: $response");
    }
} else {
    // JSON-Response parsen (falls Nextcloud JSON zurückgibt)
    $responseData = json_decode($response, true);
    $shareUrl = $responseData['ocs']['data']['url'] ?? null;
    error_log("Nextcloud Share URL from JSON: " . ($shareUrl ?? 'null'));
}

if (!$shareUrl) {
    error_log("Nextcloud Share API - No URL in response. Raw response: $response");
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Share-URL nicht erhalten',
        'response' => $response,
        'responseType' => strpos($response, '<?xml') !== false ? 'XML' : 'JSON'
    ]);
    exit;
}

// Erfolgreiche Antwort
echo json_encode([
    'success' => true,
    'url' => $shareUrl,
    'fileName' => $fileName,
    'fileType' => $fileType,
    'hasPassword' => !empty($sharePassword) // Info ob Passwort gesetzt wurde
]);

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

function sendJsonError($statusCode, $payload, $cleanupPath = null) {
    if ($cleanupPath && file_exists($cleanupPath)) {
        @unlink($cleanupPath);
    }

    http_response_code($statusCode);
    echo json_encode($payload);
    exit;
}

function maxDownloadBytes() {
    return defined('MAX_DOWNLOAD_BYTES') ? (int)MAX_DOWNLOAD_BYTES : 25 * 1024 * 1024;
}

function allowedDownloadHosts() {
    return defined('ALLOWED_DOWNLOAD_HOSTS')
        ? array_map('strtolower', ALLOWED_DOWNLOAD_HOSTS)
        : [];
}

function isPrivateOrReservedHost($host) {
    $ips = filter_var($host, FILTER_VALIDATE_IP) ? [$host] : gethostbynamel($host);
    if (!$ips) {
        return true;
    }

    foreach ($ips as $ip) {
        if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)) {
            return true;
        }
    }

    return false;
}

function validateDownloadUrl($url) {
    $parts = parse_url($url);
    if (!is_array($parts)) {
        throw new RuntimeException('Download-URL ist ungültig');
    }

    $host = strtolower($parts['host'] ?? '');
    $allowedHosts = allowedDownloadHosts();

    if (($parts['scheme'] ?? '') !== 'https' || !$host) {
        throw new RuntimeException('Download-URL muss HTTPS verwenden');
    }

    if (!$allowedHosts || !in_array($host, $allowedHosts, true)) {
        throw new RuntimeException('Download-Host ist nicht erlaubt');
    }

    if (isPrivateOrReservedHost($host)) {
        throw new RuntimeException('Download-Host zeigt auf eine private oder reservierte IP');
    }
}

function resolveRedirectUrl($currentUrl, $location) {
    if (parse_url($location, PHP_URL_SCHEME)) {
        return $location;
    }

    $parts = parse_url($currentUrl);
    $scheme = $parts['scheme'];
    $host = $parts['host'];
    $port = isset($parts['port']) ? ':' . $parts['port'] : '';

    if (str_starts_with($location, '/')) {
        return $scheme . '://' . $host . $port . $location;
    }

    $path = $parts['path'] ?? '/';
    $directory = preg_replace('#/[^/]*$#', '/', $path);

    return $scheme . '://' . $host . $port . $directory . $location;
}

function downloadFileFromAllowedUrl($url) {
    validateDownloadUrl($url);

    $currentUrl = $url;
    $maxRedirects = 3;
    $maxBytes = maxDownloadBytes();

    for ($redirect = 0; $redirect <= $maxRedirects; $redirect++) {
        $tempPath = tempnam(sys_get_temp_dir(), 'nextcloud_upload_');
        if (!$tempPath) {
            throw new RuntimeException('Temporäre Datei konnte nicht erstellt werden');
        }

        $handle = fopen($tempPath, 'wb');
        $headers = [];
        $bytes = 0;

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $currentUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, false);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, false);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 10);
        curl_setopt($ch, CURLOPT_TIMEOUT, 60);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 2);
        curl_setopt($ch, CURLOPT_USERAGENT, 'discourse-nextcloud-word/1.0');
        curl_setopt($ch, CURLOPT_HEADERFUNCTION, function ($ch, $header) use (&$headers) {
            $length = strlen($header);
            $header = trim($header);
            if ($header !== '' && strpos($header, ':') !== false) {
                [$name, $value] = explode(':', $header, 2);
                $headers[strtolower(trim($name))] = trim($value);
            }
            return $length;
        });
        curl_setopt($ch, CURLOPT_WRITEFUNCTION, function ($ch, $data) use ($handle, &$bytes, $maxBytes) {
            $length = strlen($data);
            $bytes += $length;
            if ($bytes > $maxBytes) {
                return 0;
            }
            return fwrite($handle, $data);
        });

        curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);
        fclose($handle);

        if ($httpCode >= 300 && $httpCode < 400 && isset($headers['location'])) {
            @unlink($tempPath);
            $currentUrl = resolveRedirectUrl($currentUrl, $headers['location']);
            validateDownloadUrl($currentUrl);
            continue;
        }

        if ($curlError) {
            @unlink($tempPath);
            throw new RuntimeException('Download fehlgeschlagen: ' . $curlError);
        }

        if ($httpCode !== 200) {
            @unlink($tempPath);
            throw new RuntimeException('Download fehlgeschlagen mit HTTP ' . $httpCode);
        }

        if ($bytes > $maxBytes) {
            @unlink($tempPath);
            throw new RuntimeException('Datei überschreitet die maximale Downloadgröße');
        }

        return [
            'path' => $tempPath,
            'contentType' => $headers['content-type'] ?? null,
            'bytes' => $bytes
        ];
    }

    throw new RuntimeException('Zu viele Redirects beim Download');
}

function validateDownloadedFile($path, $fileType, $contentType = null) {
    $fileTypeMimes = [
        'docx' => ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
        'xlsx' => ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
        'pptx' => ['application/vnd.openxmlformats-officedocument.presentationml.presentation'],
        'odt' => ['application/vnd.oasis.opendocument.text'],
        'ods' => ['application/vnd.oasis.opendocument.spreadsheet'],
        'odp' => ['application/vnd.oasis.opendocument.presentation']
    ];
    $genericOfficeMimes = [
        'application/zip',
        'application/octet-stream'
    ];

    $isAllowedMime = function ($mimeType) use ($fileType, $fileTypeMimes, $genericOfficeMimes) {
        return in_array($mimeType, $fileTypeMimes[$fileType] ?? [], true)
            || in_array($mimeType, $genericOfficeMimes, true);
    };

    if (function_exists('finfo_open')) {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $detectedType = $finfo ? finfo_file($finfo, $path) : null;
        if ($finfo) {
            finfo_close($finfo);
        }

        if ($detectedType && !$isAllowedMime($detectedType)) {
            throw new RuntimeException('Ungültiger Dateiinhalt: ' . $detectedType);
        }
    } elseif ($contentType) {
        $contentType = strtolower(trim(explode(';', $contentType)[0]));
        if ($contentType && !$isAllowedMime($contentType)) {
            throw new RuntimeException('Ungültiger Content-Type: ' . $contentType);
        }
    }
}

// Request-Daten
$input = getRequestInput();
$fileType = $input['fileType'] ?? 'docx'; // docx, xlsx, pptx
$fileName = $input['fileName'] ?? null;
$downloadUrl = isset($input['downloadUrl']) ? trim($input['downloadUrl']) : '';
// Passwort-Parameter: null oder leerer String werden zu leerem String normalisiert
$sharePassword = isset($input['sharePassword']) && $input['sharePassword'] !== null 
    ? trim($input['sharePassword']) 
    : ''; // Optional: Passwort für Share-Schutz

// Prüfe ob eine Datei direkt hochgeladen wurde (Hybrid-Upload via Frontend-Fetch)
$uploadedFile = $_FILES['file'] ?? null;

// Debug-Logging (kann später entfernt werden)
error_log("Nextcloud API Call - FileType: $fileType, FileName: $fileName, HasPassword: " . (!empty($sharePassword) ? 'yes' : 'no') . ", HasFile: " . ($uploadedFile ? 'yes' : 'no'));

// Validierung des Dateityps
$validTypes = ($downloadUrl || $uploadedFile)
    ? ['docx', 'xlsx', 'pptx', 'odt', 'ods', 'odp']
    : ['docx', 'xlsx', 'pptx'];
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

$sourcePath = null;
$cleanupPath = null;

if ($uploadedFile && $uploadedFile['error'] === UPLOAD_ERR_OK) {
    // Datei wurde direkt vom Frontend gesendet
    $sourcePath = $uploadedFile['tmp_name'];
    // Wir löschen die temporäre Datei nicht manuell, PHP macht das am Ende des Requests
    try {
        validateDownloadedFile($sourcePath, $fileType, $uploadedFile['type']);
    } catch (RuntimeException $e) {
        sendJsonError(400, [
            'success' => false,
            'error' => $e->getMessage()
        ]);
    }
} elseif ($downloadUrl) {
    try {
        $downloadedFile = downloadFileFromAllowedUrl($downloadUrl);
        $sourcePath = $downloadedFile['path'];
        $cleanupPath = $sourcePath;
        validateDownloadedFile($downloadedFile['path'], $fileType, $downloadedFile['contentType']);
    } catch (RuntimeException $e) {
        sendJsonError(400, [
            'success' => false,
            'error' => $e->getMessage()
        ]);
    }
} else {
    // Pfad zur Template-Datei
    $sourcePath = __DIR__ . '/template.' . $fileType;
    if (!file_exists($sourcePath)) {
        http_response_code(500);
        echo json_encode(['error' => 'Template-Datei nicht gefunden: ' . $fileType]);
        exit;
    }
}

// WebDAV-URL zum Hochladen
$filePath = buildNextcloudPath(NEXTCLOUD_TARGET_FOLDER, $fileName);
$webdavUrl = NEXTCLOUD_URL . '/remote.php/dav/files/' . rawurlencode(NEXTCLOUD_USERNAME) . '/' . encodePathForWebDav($filePath);

// Datei erstellen via WebDAV
$ch = curl_init();
$sourceHandle = fopen($sourcePath, 'r');
if (!$sourceHandle) {
    sendJsonError(500, ['error' => 'Quelldatei konnte nicht geöffnet werden'], $cleanupPath);
}
curl_setopt($ch, CURLOPT_URL, $webdavUrl);
curl_setopt($ch, CURLOPT_USERPWD, NEXTCLOUD_USERNAME . ':' . NEXTCLOUD_PASSWORD);
curl_setopt($ch, CURLOPT_PUT, true);
curl_setopt($ch, CURLOPT_INFILE, $sourceHandle);
curl_setopt($ch, CURLOPT_INFILESIZE, filesize($sourcePath));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);
fclose($sourceHandle);

if ($httpCode !== 201 && $httpCode !== 204) {
    sendJsonError(500, ['error' => 'Fehler beim Erstellen der Datei', 'httpCode' => $httpCode], $cleanupPath);
}

if ($cleanupPath && file_exists($cleanupPath)) {
    @unlink($cleanupPath);
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

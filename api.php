<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=utf-8");

$ordersFile  = __DIR__ . "/vpnsopr_orders.json";
$storeFile   = __DIR__ . "/vpnsopr_store.json";
$ticketsFile = __DIR__ . "/vpnsopr_tickets.json";

function readJsonFile($file, $default) {
    if (!file_exists($file)) return $default;
    $data = json_decode(file_get_contents($file), true);
    return is_array($data) ? $data : $default;
}

function writeJsonFile($file, $data) {
    file_put_contents($file, json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
}

$action = $_GET['action'] ?? '';
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($action === 'get_store') {
    echo json_encode(readJsonFile($storeFile, new stdClass()), JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'save_store' && $method === 'POST') {
    $input = json_decode(file_get_contents("php://input"), true);
    if (is_array($input)) {
        writeJsonFile($storeFile, $input);
        echo json_encode(["ok" => true]);
        exit;
    }
}

$orders = readJsonFile($ordersFile, []);

if ($action === 'get_orders') {
    echo json_encode($orders, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'get_user_orders') {
    $user = $_GET['username'] ?? '';
    $filtered = array_values(array_filter($orders, fn($o) => ($o['username'] ?? '') === $user));
    echo json_encode($filtered, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'create_order' && $method === 'POST') {
    $input = json_decode(file_get_contents("php://input"), true);
    if (is_array($input)) {
        array_unshift($orders, $input);
        writeJsonFile($ordersFile, $orders);
        http_response_code(201);
        echo json_encode(["ok" => true, "id" => $input['id'] ?? '']);
        exit;
    }
}

if ($action === 'approve_order' && $method === 'POST') {
    $input = json_decode(file_get_contents("php://input"), true) ?? [];
    $id = $input['id'] ?? ($_GET['id'] ?? '');
    foreach ($orders as &$o) {
        if (($o['id'] ?? '') === $id) {
            $o['status'] = 'approved';
            $o['activatedConfigJson'] = $input['activatedConfigJson'] ?? '';
            break;
        }
    }
    writeJsonFile($ordersFile, $orders);
    echo json_encode(["ok" => true]);
    exit;
}

if ($action === 'reject_order' && $method === 'POST') {
    $input = json_decode(file_get_contents("php://input"), true) ?? [];
    $id = $input['id'] ?? ($_GET['id'] ?? '');
    foreach ($orders as &$o) {
        if (($o['id'] ?? '') === $id) {
            $o['status'] = 'rejected';
            break;
        }
    }
    writeJsonFile($ordersFile, $orders);
    echo json_encode(["ok" => true]);
    exit;
}

$tickets = readJsonFile($ticketsFile, []);

if ($action === 'get_tickets') {
    echo json_encode($tickets, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'get_user_tickets') {
    $user = $_GET['username'] ?? '';
    $filtered = array_values(array_filter($tickets, fn($t) => ($t['username'] ?? '') === $user));
    echo json_encode($filtered, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'create_ticket' && $method === 'POST') {
    $input = json_decode(file_get_contents("php://input"), true);
    if (is_array($input)) {
        array_unshift($tickets, $input);
        writeJsonFile($ticketsFile, $tickets);
        http_response_code(201);
        echo json_encode(["ok" => true, "id" => $input['id'] ?? '']);
        exit;
    }
}

if ($action === 'reply_ticket' && $method === 'POST') {
    $input = json_decode(file_get_contents("php://input"), true) ?? [];
    $id = $input['id'] ?? '';
    $reply = $input['adminReply'] ?? '';
    foreach ($tickets as &$t) {
        if (($t['id'] ?? '') === $id) {
            $t['adminReply'] = $reply;
            $t['status'] = 'answered';
            break;
        }
    }
    writeJsonFile($ticketsFile, $tickets);
    echo json_encode(["ok" => true]);
    exit;
}

echo json_encode(["status" => "VPNSOPR API Ready"]);

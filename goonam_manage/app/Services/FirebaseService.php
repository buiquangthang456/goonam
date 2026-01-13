<?php

namespace App\Services;

use Google\Client;
use Illuminate\Support\Facades\Log;
use Exception;
use Throwable;

class FirebaseService
{
    protected $client;
    protected $projectId;
    protected $url;
    protected $accessToken;
    protected $lastTokenTime;

    public function __construct()
    {
        $jsonPath = storage_path('app/firebase/goonam-service-account.json');

        if (!file_exists($jsonPath)) {
            Log::error("❌ Firebase credential file not found at {$jsonPath}");
            throw new Exception("Firebase JSON not found");
        }

        $config = json_decode(file_get_contents($jsonPath), true);
        $this->projectId = $config['project_id'] ?? null;

        if (!$this->projectId) {
            throw new Exception("❌ Missing project_id in Firebase JSON");
        }

        $this->client = new Client();
        $this->client->setAuthConfig($jsonPath);
        $this->client->addScope('https://www.googleapis.com/auth/firebase.messaging');

        $this->url = "https://fcm.googleapis.com/v1/projects/{$this->projectId}/messages:send";
    }

    /**
     * Lấy access token có cache để tránh tạo lại mỗi lần
     */
    protected function getAccessToken(): string
    {
        // Token Firebase có hạn 3600 giây (1h)
        if ($this->accessToken && $this->lastTokenTime && (time() - $this->lastTokenTime < 3000)) {
            return $this->accessToken;
        }

        $token = $this->client->fetchAccessTokenWithAssertion();
        $this->accessToken = $token['access_token'] ?? '';
        $this->lastTokenTime = time();

        if (!$this->accessToken) {
            throw new Exception("❌ Failed to fetch Firebase access token");
        }

        return $this->accessToken;
    }

    /**
     * Gửi thông báo FCM tới nhiều token
     */
    public function sendNotification(array $tokens, string $title, string $body, array $data = []): void
    {
        if (empty($tokens)) {
            Log::warning("⚠️ Không có token nào để gửi FCM.");
            return;
        }

        $accessToken = $this->getAccessToken();
        $success = 0;
        $fail = 0;

        foreach ($tokens as $token) {
            $payload = [
                "message" => [
                    "token" => $token,
                    "notification" => [
                        "title" => $title,
                        "body"  => $body,
                    ],
                    "data" => array_map('strval', $data),
                ]
            ];

            $result = $this->postToFcm($payload, $accessToken);

            if ($result['success']) {
                $success++;
            } else {
                $fail++;
                Log::error("❌ FCM send failed", [
                    'token' => $token,
                    'error' => $result['error'] ?? 'unknown'
                ]);
            }
        }

        Log::info("✅ FCM sent summary", [
            'title' => $title,
            'body' => $body,
            'success' => $success,
            'fail' => $fail,
        ]);
    }

    /**
     * Gửi HTTP POST đến FCM server
     */
    protected function postToFcm(array $payload, string $accessToken): array
    {
        try {
            $ch = curl_init($this->url);
            curl_setopt_array($ch, [
                CURLOPT_POST => true,
                CURLOPT_HTTPHEADER => [
                    "Authorization: Bearer {$accessToken}",
                    "Content-Type: application/json",
                ],
                CURLOPT_POSTFIELDS => json_encode($payload),
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT => 15,
            ]);

            $response = curl_exec($ch);
            $error = curl_error($ch);
            $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if ($error) {
                return ['success' => false, 'error' => $error];
            }

            if ($status >= 200 && $status < 300) {
                return ['success' => true];
            }

            return [
                'success' => false,
                'error' => "HTTP {$status}: " . $response
            ];
        } catch (Throwable $e) {
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }
}

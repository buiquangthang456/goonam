<?php

namespace App\Listeners;

use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use App\Services\FirebaseService;

class SendFcmNotification implements ShouldQueue
{
    use InteractsWithQueue;

    /**
     * Xử lý event PushFcmNotification (từ /test-fcm hoặc các event khác)
     */
    public function handle($event)
    {
        // Ghi log bắt đầu
        Log::info("🔥 SendFcmNotification handle() started", [
            'title' => $event->title ?? '(no title)',
            'body' => $event->body ?? '(no body)',
            'sender_id' => $event->sender_id ?? null,
            'data' => $event->data ?? []
        ]);

        try {
            // ✅ Lấy danh sách token FCM từ bảng device_tokens
            $tokensQuery = DB::table('device_tokens')
                ->join('users', 'device_tokens.user_id', '=', 'users.id')
                ->whereNotNull('device_tokens.token')
                ->where('users.is_active', 1);

            // Nếu có người gửi thì loại trừ họ ra
            if (!empty($event->sender_id)) {
                $tokensQuery->where('users.id', '!=', $event->sender_id);
            }

            $tokens = $tokensQuery->pluck('device_tokens.token')->toArray();

            if (empty($tokens)) {
                Log::warning("⚠️ Không có thiết bị nào để gửi thông báo FCM.");
                return;
            }

            // ✅ Gửi thông báo qua FirebaseService (API v1)
            app(FirebaseService::class)->sendNotification(
                $tokens,
                $event->title,
                $event->body,
                $event->data ?? []
            );

            // ✅ Log kết quả thành công
            Log::info("✅ FCM notification sent successfully", [
                'title' => $event->title,
                'body' => $event->body,
                'tokens_count' => count($tokens),
                'excluded_sender' => $event->sender_id,
            ]);

        } catch (\Throwable $e) {
            // ❌ Log lỗi chi tiết
            Log::error("❌ Gửi FCM thất bại: " . $e->getMessage(), [
                'exception' => get_class($e),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
            ]);
        }
    }
}

<?php

namespace App\Listeners;

use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use App\Services\FirebaseService;

class PushFcmNotification implements ShouldQueue
{
    use InteractsWithQueue;

    public function handle($event)
    {
        $title = '';
        $body = '';
        $orderId = null;
        $senderId = null; // ✅ Đặt tên thống nhất hơn (trước đây là $commentUserId)
        $type = 'general';

        // 🧩 Xác định loại event và nội dung thông báo
        if ($event instanceof \App\Events\CommentAdded) {
            $comment = \App\Models\Comment::find($event->comment->id);
            if (!$comment) {
                \Log::warning("⚠️ CommentAdded event: comment ID {$event->comment->id} không tồn tại, bỏ qua.");
                return;
            }

            $title = "💬 Bình luận mới";
            $body  = "Đơn #{$comment->order_id}: {$comment->body}";
            $orderId = $comment->order_id;
            $senderId = $comment->user_id;
            $type = 'comment';
        } elseif ($event instanceof \App\Events\StageCompleted) {
            $title = "✅ Công đoạn hoàn thành";
            $body  = "Công đoạn '{$event->stage->name}' đã hoàn thành.";
            $orderId = $event->stage->order_id;
            $type = 'stage_completed';

        } elseif ($event instanceof \App\Events\StageOverdue) {
            $title = "⚠️ Công đoạn trễ hạn";
            $body  = "Công đoạn '{$event->stage->name}' đã bị trễ hạn.";
            $orderId = $event->stage->order_id;
            $type = 'stage_overdue';

        } elseif ($event instanceof \App\Events\OrderCreated) {
            $title = "🆕 Đơn hàng mới";
            $body  = "Đơn '{$event->order->project_name}' (#{$event->order->order_no}) đã được tạo.";
            $orderId = $event->order->id;
            $senderId = $event->order->created_by ?? null; // 👈 nếu có cột created_by
            $type = 'order_created';

        } else {
            Log::warning("⚠️ PushFcmNotification: event không được hỗ trợ", [
                'event_type' => get_class($event)
            ]);
            return;
        }

        // 🧾 Ghi log nội bộ
        Log::info("🔥 PushFcmNotification started", [
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'order_id' => $orderId,
            'sender_id' => $senderId
        ]);

        // 🧩 Lấy tất cả token, trừ người gửi
        $tokensQuery = DB::table('device_tokens')
            ->join('users', 'device_tokens.user_id', '=', 'users.id')
            ->whereNotNull('device_tokens.token')
            ->where('users.is_active', 1);

        if ($senderId) {
            $tokensQuery->where('users.id', '!=', $senderId);
        }

        $tokens = $tokensQuery->pluck('device_tokens.token')->toArray();

        if (empty($tokens)) {
            Log::warning("⚠️ Không tìm thấy token nào để gửi FCM.");
            return;
        }

        // 🧩 Gửi qua FirebaseService
        app(FirebaseService::class)->sendNotification(
            $tokens,
            $title,
            $body,
            [
                'order_id' => (string) $orderId,
                'type' => $type,
            ]
        );

        Log::info("✅ FCM broadcast sent successfully", [
            'title' => $title,
            'body' => $body,
            'tokens_count' => count($tokens),
            'excluded_sender' => $senderId,
        ]);
    }
}

<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\Comment;
use Illuminate\Http\Request;
use App\Models\CommentRead;

class CommentController extends Controller
{
    public function index(Order $order)
    {
        return $order->comments()
            ->with('user:id,name,role')
            ->orderByDesc('id')
            ->get()
            ->map(function ($c) {
                return [
                    'id' => $c->id,
                    'order_no' => $c->order->order_no ?? null,
                    'order_id' => $c->order_id,
                    'user_id' => $c->user_id,
                    'body' => $c->body,
                    'created_at' => $c->created_at, // ✅ để mặc định
                    'user' => $c->user,
                ];
            });
    }

   // 🟩 Thêm bình luận
    public function store(Request $req, Order $order)
{
    $user = $req->user();

    if (!$user) {
        return response()->json(['message' => 'Unauthorized'], 401);
    }

    $allowedRoles = ['admin', 'director', 'manager', 'staff'];
    if (!in_array($user->role, $allowedRoles)) {
        return response()->json(['message' => 'Không có quyền bình luận'], 403);
    }

    $req->validate([
        'body' => 'required|string|max:1000',
    ]);

    $comment = $order->comments()->create([
        'user_id' => $user->id,
        'body'    => $req->input('body'),
    ]);

    // ✅ TỰ ĐỘNG ĐÁNH DẤU ĐÃ ĐỌC CHO CHÍNH MÌNH
    \App\Models\CommentRead::create([
        'user_id' => $user->id,
        'comment_id' => $comment->id,
        'read_at' => now(),
    ]);

    // Gửi event FCM nếu cần
    event(new \App\Events\CommentAdded($comment));

    $recipients = \App\Models\User::where('id', '<>', $user->id)->get();
    foreach ($recipients as $recipient) {
        $unreadCount = \App\Models\Comment::whereNotIn('id', function ($q) use ($recipient) {
            $q->select('comment_id')->from('comment_reads')->where('user_id', $recipient->id);
        })->where('user_id', '<>', $recipient->id)->count();

        event(new \App\Events\UnreadUpdated($recipient->id, $unreadCount));
    }

    return response()->json(
        $comment->load('user:id,name,role'),
        201
    );
}

   // 🟩 Sửa bình luận
    public function update(Request $req, Order $order, Comment $comment)
    {
        // 🔒 Chỉ chính chủ comment mới được chỉnh sửa
        if ($req->user()->id !== $comment->user_id) {
            return response()->json(['message' => 'Bạn chỉ được sửa bình luận của chính mình'], 403);
        }

        // ✅ Kiểm tra comment thuộc đúng order
        if ($comment->order_id !== $order->id) {
            return response()->json(['message' => 'Bình luận không thuộc đơn hàng này'], 400);
        }

        $req->validate(['body' => 'required|string|max:1000']);
        $comment->update(['body' => $req->input('body')]);

        return response()->json($comment->load('user:id,name,role'));
    }

     // 🟩 Xóa bình luận
    public function destroy(Request $req, Order $order, Comment $comment)
    {
        // ✅ Kiểm tra comment thuộc đúng order
        if ($comment->order_id !== $order->id) {
            return response()->json(['message' => 'Bình luận không thuộc đơn hàng này'], 400);
        }

        // 🔒 Chỉ chính chủ comment mới được xóa
        if ($req->user()->id !== $comment->user_id) {
            return response()->json(['message' => 'Bạn chỉ được xóa bình luận của chính mình'], 403);
        }

        $comment->delete();
        return response()->json(['message' => 'Đã xóa bình luận']);
        }

        // Đánh dấu tất cả comment của order là đã đọc
        public function markAsRead(Request $request)
        {
            $userId = $request->user()->id;
            $orderId = $request->input('order_id');

            CommentRead::where('user_id', $userId)
                ->whereIn('comment_id', function ($q) use ($orderId) {
                    $q->select('id')->from('comments')->where('order_id', $orderId);
                })
                ->delete();

            Comment::where('order_id', $orderId)
                ->get()
                ->each(fn($c) => CommentRead::create([
                    'user_id' => $userId,
                    'comment_id' => $c->id,
                ]));

            // 🧹 Xóa cache để client thấy kết quả mới ngay
            cache()->forget("unread_comments_user_{$userId}_0");

            return response()->json(['success' => true]);
        }

    // Lấy số comment chưa đọc
   /**
 * Lấy số comment chưa đọc
 *
 * @param \Illuminate\Http\Request $request
 * @return \Illuminate\Http\JsonResponse
 */
public function unreadCount(Request $request)
{
    $userId  = $request->user()->id;
    $sinceId = (int) $request->query('since_id', 0);

    // tạo key cache
    $cacheKey = "unread_comments_user_{$userId}_{$sinceId}";

    // chỉ cache dữ liệu thô
    $data = cache()->remember($cacheKey, 10, function () use ($userId, $sinceId) {
        $comments = Comment::whereNotIn('id', function ($q) use ($userId) {
                $q->select('comment_id')
                  ->from('comment_reads')
                  ->where('user_id', $userId);
            })
            ->when($sinceId > 0, fn ($q) => $q->where('id', '>', $sinceId))
            ->where('user_id', '<>', $userId)
            ->with('order:id,order_no,project_name')
            ->orderBy('id', 'desc')
            ->limit(20)
            ->get();

        $orders = $comments->map(function ($c) {
            return [
                'order_id'     => (int) $c->order_id,
                'order_no'     => $c->order->order_no ?? '(Không có mã)',
                'project_name' => $c->order->project_name ?? '(Không xác định)',
                'comment_id'   => $c->id,
                'body'         => $c->body ?? '(Không có nội dung)',
                'created_at'   => $c->created_at->format('Y-m-d H:i:s'),
                'user_name'    => $c->user->name ?? 'Unknown',
            ];
        })->values()->all();

        return [
            'unread_total' => $comments->count(),
            'latest_id'    => $comments->max('id') ?? 0,
            'orders'       => $orders,
        ];
    });

    // trả JSON ở ngoài
    return response()->json($data);
}
/**
 * @param \Illuminate\Http\Request $request
 */
public function markAllAsRead(Request $request)
{
    $userId = $request->user()->id;
    $orderId = $request->input('order_id');

    $query = Comment::query();
    if ($orderId) {
        $query->where('order_id', $orderId);
    }

    $comments = $query->pluck('id');

    foreach ($comments as $commentId) {
        CommentRead::updateOrCreate(
            ['comment_id' => $commentId, 'user_id' => $userId],
            ['read_at' => now()]
        );
    }
    // 🧹 Xóa cache sau khi đánh dấu tất cả là đã đọc
    cache()->forget("unread_comments_user_{$userId}_0");
    return response()->json(['message' => '✅ marked_as_read']);
}

}

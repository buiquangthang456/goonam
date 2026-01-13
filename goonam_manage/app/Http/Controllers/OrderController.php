<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\OrderStage;
use App\Models\StageTemplate;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Http\Requests\StoreOrderRequest;
use App\Http\Requests\UpdateOrderRequest;

class OrderController extends Controller
{


    public function index(Request $req)
{
    $q = Order::query()
       ->with(['stages' => function($qq) {
        $qq->orderBy('sequence')
           ->select('id', 'order_id', 'name', 'planned_start', 'planned_end', 'actual_start', 'actual_end', 'status', 'is_overdue', 'sequence', 'material_request_date', 'delay_reason');

            },

        ])
        ->where('status', '!=', 'completed') // ✅ THÊM DÒNG NÀY - LOẠI BỎ ĐƠN HOÀN THÀNH
        ->when($req->filled('type'), fn($qq)=>$qq->where('order_type',$req->type))
        ->when($req->boolean('late_only'), fn($qq)=>$qq->whereHas('stages', fn($s)=>$s->where('is_overdue',true)))
        ->when($req->filled('search'), function($qq) use ($req) {
            $s = $req->search;
            $qq->where(function($w) use ($s){
                $w->where('order_no','like',"%$s%")
                  ->orWhere('project_name','like',"%$s%")
                  ->orWhere('company_name','like',"%$s%");
            });
        })
        ->orderByDesc('highlight_flag')
        ->orderByDesc('id');
    // ✅ Đếm tổng số đơn hàng
    $total = $q->count();

    // ✅ Logic tự động: < 50 → get(), >= 50 → paginate(100)
    if ($total < 50) {
        // Lấy tất cả đơn hàng
        $orders = $q->get();

        // ✅ Kiểm tra và tự động cập nhật status cho từng đơn
        foreach ($orders as $order) {
            $overallStatus = $order->overall_status; // Tính dynamic từ accessor

            // ✅ Cập nhật lại status nếu overallStatus = 'late' nhưng status != 'late'
            if ($overallStatus === 'late' && $order->status !== 'late') {
                $order->status = 'late';
                $order->saveQuietly(); // Lưu mà không trigger events
            } elseif ($overallStatus !== 'late' && $order->status === 'late') {
                // ✅ Nếu không còn trễ nữa, đổi lại thành in_progress
                $order->status = 'in_progress';
                $order->saveQuietly();
            }

            // Kiểm tra công đoạn trễ
            foreach ($order->stages as $stage) {
                if (method_exists($stage, 'checkOverdue')) {
                    $stage->checkOverdue();
                }
            }
        }
         // ✅ Format comment cho TỪNG đơn hàng
    // ✅ Query thủ công comment cho TỪNG đơn hàng
    $formattedOrders = $orders->map(function($order) use ($req) {
    $data = $order->toArray();

    $currentUserId = $req->user()->id;

    // ✅ ĐẾM TỔNG SỐ COMMENT CHƯA ĐỌC CỦA ĐƠN HÀNG NÀY
    $unreadCount = \App\Models\Comment::where('order_id', $order->id)
        ->where('user_id', '!=', $currentUserId) // Bỏ qua comment của chính mình
        ->whereNotIn('id', function($q) use ($currentUserId) {
            $q->select('comment_id')
              ->from('comment_reads')
              ->where('user_id', $currentUserId);
        })
        ->count();

        // ✅ Lấy comment mới nhất
        $latestComment = \App\Models\Comment::where('order_id', $order->id)
            ->with('user:id,name')
            ->orderBy('created_at', 'desc')
            ->first();

        if ($latestComment) {
            $isUnread = false;
            if ($latestComment->user_id !== $currentUserId) {
                $isUnread = !\App\Models\CommentRead::where('comment_id', $latestComment->id)
                    ->where('user_id', $currentUserId)
                    ->exists();
            }

            $data['latest_comment'] = [
                'id' => $latestComment->id,
                'body' => $latestComment->body,
                'created_at' => $latestComment->created_at->toIso8601String(),
                'user_name' => $latestComment->user->name ?? 'Unknown',
                'is_unread' => $isUnread,
            ];
        } else {
            $data['latest_comment'] = null;
        }

        // ✅ THÊM SỐ LƯỢNG COMMENT CHƯA ĐỌC
        $data['unread_comments_count'] = $unreadCount;

        return $data;
    });

    return response()->json([
        'type' => 'all',
        'total' => $total,
        'data' => $formattedOrders,
    ]);
    } else {
        // Phân trang với 100 đơn/trang
        $orders = $q->paginate($req->get('per_page', 100));

        // ✅ Kiểm tra và tự động cập nhật status cho từng đơn
        foreach ($orders as $order) {
            $overallStatus = $order->overall_status;

            if ($overallStatus === 'late' && $order->status !== 'late') {
                $order->status = 'late';
                $order->saveQuietly();
            } elseif ($overallStatus !== 'late' && $order->status === 'late') {
                $order->status = 'in_progress';
                $order->saveQuietly();
            }

            foreach ($order->stages as $stage) {
                if (method_exists($stage, 'checkOverdue')) {
                    $stage->checkOverdue();
                }
            }
        }
        // ✅ THÊM LOGIC FORMAT COMMENT (pagination)
        $orders->getCollection()->transform(function($order) use ($req) {
        $data = $order->toArray();

        $currentUserId = $req->user()->id;

        // ✅ ĐẾM TỔNG SỐ COMMENT CHƯA ĐỌC
        $unreadCount = \App\Models\Comment::where('order_id', $order->id)
            ->where('user_id', '!=', $currentUserId)
            ->whereNotIn('id', function($q) use ($currentUserId) {
                $q->select('comment_id')
                ->from('comment_reads')
                ->where('user_id', $currentUserId);
            })
            ->count();

        $latestComment = \App\Models\Comment::where('order_id', $order->id)
            ->with('user:id,name')
            ->orderBy('created_at', 'desc')
            ->first();

        if ($latestComment) {
            $isUnread = false;
            if ($latestComment->user_id !== $currentUserId) {
                $isUnread = !\App\Models\CommentRead::where('comment_id', $latestComment->id)
                    ->where('user_id', $currentUserId)
                    ->exists();
            }

            $data['latest_comment'] = [
                'id' => $latestComment->id,
                'body' => $latestComment->body,
                'created_at' => $latestComment->created_at->toIso8601String(),
                'user_name' => $latestComment->user->name ?? 'Unknown',
                'is_unread' => $isUnread,
            ];
        } else {
            $data['latest_comment'] = null;
        }

        // ✅ THÊM SỐ LƯỢNG COMMENT CHƯA ĐỌC
        $data['unread_comments_count'] = $unreadCount;

        return $data;
    });
        // ✅ Trả về định dạng pagination Laravel chuẩn
        return $orders;
    }
}

    public function show(Order $order)
    {
         $order->load([
            'stages' => fn($q) => $q->orderBy('sequence')
                ->select('*'),
            'comments.user:id,name,role'
        ]);

        // 🟢 Nếu đơn hàng chưa có công đoạn, vẫn trả về bình thường
        if ($order->stages->isEmpty()) {
            return response()->json($order);
        }

        return $order;
    }

   public function store(StoreOrderRequest $req)
{
    $this->authorizeByRole($req->user(), ['admin','director','manager']);

    // ✅ Kiểm tra mã đơn hàng trùng (bao gồm cả thùng rác)
    $existingOrder = Order::withTrashed() // ← THÊM withTrashed()
        ->where('order_no', $req->order_no)
        ->where('order_type', $req->order_type)
        ->first();

    if ($existingOrder) {
        // ✅ Nếu đơn hàng đang ở thùng rác
        if ($existingOrder->trashed()) {
            return response()->json([
                'message' => "❌ Mã đơn hàng '{$req->order_no}' (loại {$req->order_type}) đã tồn tại trong thùng rác. Vui lòng khôi phục hoặc xóa vĩnh viễn đơn hàng cũ trước khi tạo mới.",
            ], 422);
        }

        // ✅ Nếu đơn hàng đang hoạt động
        return response()->json([
            'message' => "❌ Mã đơn hàng '{$req->order_no}' (loại {$req->order_type}) đã tồn tại trong hệ thống. Vui lòng sử dụng mã khác.",
        ], 422);
    }

    $validated = $req->validate([
        'order_no' => 'required|string|max:255',
        'company_name' => 'nullable|string|max:255',
        'project_name' => 'required|string|max:255',
        'description' => 'nullable|string',
        'quantity' => 'required|integer|min:1',
        'order_date' => 'required|date',
        'delivery_date' => 'required|date',
        'order_type' => 'required|in:door,metal',
        'template_id' => 'nullable|exists:stage_templates,id',
    ]);

    $data = $req->validated();
    foreach (['order_date', 'delivery_date', 'actual_end'] as $dateField) {
        if (!empty($data[$dateField])) {
            try {
                $data[$dateField] = \Carbon\Carbon::parse($data[$dateField])->format('Y-m-d');
            } catch (\Exception $e) {}
        }
    }

    $order = DB::transaction(function() use ($data, $req) {
        if (!isset($data['original_delivery_date'])) {
            $data['original_delivery_date'] = $data['delivery_date'] ?? null;
        }
        $order = Order::create($data);

        if ($req->has('stages') && is_array($req->stages)) {
            foreach ($req->stages as $index => $s) {
                OrderStage::create([
                    'order_id'      => $order->id,
                    'template_id'   => $s['template_id'] ?? null,
                    'code'          => $s['code'] ?? 'STG-' . ($index + 1),
                    'name'          => $s['name'] ?? ('Stage ' . ($index + 1)),
                    'sequence'      => $s['sequence'] ?? ($index + 1),
                    'planned_start' => $s['planned_start'] ?? null,
                    'planned_end'   => $s['planned_end'] ?? null,
                    'material_request_date' => $s['material_request_date'] ?? null,
                    'status'        => 'pending',
                ]);
            }
        } else {
            // fallback: chia tự động như cũ
            $templates = StageTemplate::where('order_type', $order->order_type)
                ->where('is_active', 1)
                ->orderBy('sequence')
                ->get();

            $cursor = $order->order_date ? $order->order_date->clone() : now();

            foreach ($templates as $tpl) {
                $durMin = (int) round($tpl->default_duration_days * 1440);
                $start = $tpl->sequence === 1 ? $cursor : null;
                $end = ($start ?? $cursor)->clone()->addMinutes($durMin);

                OrderStage::create([
                    'order_id'      => $order->id,
                    'template_id'   => $tpl->id,
                    'code'          => $tpl->code ?? 'TPL-' . $tpl->sequence,
                    'name'          => $tpl->name,
                    'sequence'      => $tpl->sequence,
                    'planned_start' => $start,
                    'planned_end'   => $end,
                    'material_request_date' => null,
                    'status'        => 'pending',
                ]);

                $cursor = $end->clone();
            }
        }

        return $order;
    });

    event(new \App\Events\OrderCreated($order));
    return response()->json($order->load('stages'), 201);
}

 public function update(UpdateOrderRequest $req, Order $order)
{
    $this->authorizeByRole($req->user(), ['admin', 'director', 'manager']);

    // ✅ Kiểm tra mã đơn hàng trùng (bao gồm cả thùng rác, trừ đơn hiện tại)
    $existingOrder = Order::withTrashed() // ← THÊM withTrashed()
                          ->where('order_no', $req->order_no)
                          ->where('order_type', $req->order_type)
                          ->where('id', '!=', $order->id)
                          ->first();

    if ($existingOrder) {
        // ✅ Nếu đơn hàng đang ở thùng rác
        if ($existingOrder->trashed()) {
            return response()->json([
                'message' => "❌ Mã đơn hàng '{$req->order_no}' (loại {$req->order_type}) đã tồn tại trong thùng rác. Vui lòng khôi phục hoặc xóa vĩnh viễn đơn hàng cũ trước khi cập nhật.",
            ], 422);
        }

        // ✅ Nếu đơn hàng đang hoạt động
        return response()->json([
            'message' => "❌ Mã đơn hàng '{$req->order_no}' (loại {$req->order_type}) đã tồn tại trong hệ thống. Vui lòng sử dụng mã khác.",
        ], 422);
    }

    $validated = $req->validate([
        'order_no' => 'required|string|max:255',
        'company_name' => 'nullable|string|max:255',
        'project_name' => 'required|string|max:255',
        'description' => 'nullable|string',
        'quantity' => 'required|integer|min:1',
        'order_date' => 'required|date',
        'delivery_date' => 'required|date',
        'order_type' => 'required|in:door,metal',
    ]);

    $data = $req->validated();

    foreach (['order_date', 'delivery_date', 'actual_end'] as $dateField) {
        if (!empty($data[$dateField])) {
            try {
                $data[$dateField] = \Carbon\Carbon::parse($data[$dateField])->format('Y-m-d');
            } catch (\Exception $e) {}
        }
    }

    // 🟢 Giữ nguyên ngày giao gốc nếu đã có
    if ($order->original_delivery_date && isset($data['delivery_date'])) {
        unset($data['original_delivery_date']);
    }

    // 🟢 Nếu chưa có, gán giá trị gốc ban đầu = ngày giao hiện tại
    if (!$order->original_delivery_date && isset($data['delivery_date'])) {
        $data['original_delivery_date'] = $order->delivery_date ?? $data['delivery_date'];
    }

    DB::transaction(function () use ($req, $order, $data) {
        $editor = $req->user()->name ?? 'Không rõ';
        $now = now()->format('Y-m-d H:i:s');

        // 🔹 1. Cập nhật thông tin cơ bản
        $order->update($data);

        // 🔹 2. Nếu có cập nhật stages
        if ($req->has('stages') && is_array($req->stages)) {
            foreach ($req->stages as $s) {
                // ✅ CHỈ cập nhật stage đã tồn tại
                if (!empty($s['id'])) {
                    $stage = OrderStage::find($s['id']);
                    if ($stage) {
                        $oldStart = $stage->planned_start;
                        $oldEnd   = $stage->planned_end;
                        $oldMaterial = $stage->material_request_date;

                        $newStart = !empty($s['planned_start']) && $s['planned_start'] !== '0'
                            ? \Carbon\Carbon::parse($s['planned_start'])
                            : null;
                        $newEnd = !empty($s['planned_end']) && $s['planned_end'] !== '0'
                            ? \Carbon\Carbon::parse($s['planned_end'])
                            : null;
                        $newMaterial = !empty($s['material_request_date']) && $s['material_request_date'] !== '0'
                            ? \Carbon\Carbon::parse($s['material_request_date'])
                            : null;

                        $changed = false;
                        if (($oldStart != $newStart) || ($oldEnd != $newEnd) || ($oldMaterial != $newMaterial)) {
                            $changed = true;
                            $stage->planned_start = $newStart;
                            $stage->planned_end   = $newEnd;
                            $stage->material_request_date = $newMaterial;
                            $stage->save();

                            if (method_exists($stage, 'checkOverdue')) {
                                $stage->checkOverdue();
                            }
                        }

                        if ($changed) {
                            $history = $order->history ?? [];
                            if (is_string($history)) {
                                $history = json_decode($history, true) ?? [];
                            }

                            $history[] = [
                                'editor'       => $req->user()->name ?? 'Không rõ',
                                'change'       => "🛠 Admin chỉnh công đoạn '{$stage->name}': "
                                    . "Bắt đầu " . ($oldStart ? $oldStart->format('d/m/Y') : '—')
                                    . " → " . ($newStart ? $newStart->format('d/m/Y') : '—')
                                    . ", kết thúc " . ($oldEnd ? $oldEnd->format('d/m/Y') : '—')
                                    . " → " . ($newEnd ? $newEnd->format('d/m/Y') : '—')
                                    . ", yêu cầu vật tư " . ($oldMaterial ? $oldMaterial->format('d/m/Y') : '—')
                                    . " → " . ($newMaterial ? $newMaterial->format('d/m/Y') : '—'),
                                'change_mode'  => 'admin_edit',
                                'note'         => $s['note'] ?? '',
                                'date'         => now()->format('Y-m-d H:i:s'),
                            ];

                            $order->history = $history;
                            $order->save();
                        }
                    }
                }
                // ✅ XÓA HOÀN TOÀN PHẦN else {} → KHÔNG TẠO STAGE MỚI
            }
        }


        // 🔹 3. Nếu có lịch sử chỉnh sửa
        if ($req->has('history') && is_array($req->history)) {
            $history = $order->history ?? [];
            if (is_string($history)) {
                $history = json_decode($history, true) ?? [];
            }

            // 🔹 Gộp và lọc trùng theo editor + change + date
            $merged = collect(array_merge($history, $req->history))
                ->unique(function ($h) {
                    return ($h['editor'] ?? '') . '|' . ($h['change'] ?? '') . '|' . ($h['date'] ?? '');
                })
                ->values()
                ->toArray();

            $order->history = $merged;
            $order->save();
        }

        // 🔹 4. Luôn luôn ghi log chỉnh sửa admin (dù có history hay không)
        if (in_array($req->user()->role, ['admin', 'manager', 'director'])) {
            $newLog = [
                'editor' => $req->user()->name ?? 'Admin',
                'date'   => now()->format('Y-m-d H:i:s'),
                'note'   => $req->input('admin_note', '(Không có ghi chú)'),
            ];

            // Lấy log cũ (nếu có)
            $oldLogs = $order->admin_edit_logs ?? [];

            if (is_string($oldLogs)) {
                $oldLogs = json_decode($oldLogs, true) ?? [];
            }

            // Thêm log mới lên đầu
            array_unshift($oldLogs, $newLog);

            // Giới hạn số log tối đa (tuỳ chọn)
            $oldLogs = array_slice($oldLogs, 0, 30);

            // Lưu lại
            $order->admin_edit_logs = $oldLogs;
            $order->save();
        }
    });

    return $order->fresh(['stages', 'comments']);
}









    public function destroy(Request $req, Order $order)
    {
        $this->authorizeByRole($req->user(), ['admin','director','manager']);
        $order->delete();
        return response()->json(['message'=>'Đơn hàng đã được chuyển vào thùng rác']);
    }

    private function authorizeByRole($user, array $roles)
    {
        if (!in_array($user->role, $roles)) {
            abort(403, 'Bạn không có quyền thực hiện hành động này');
        }
    }
    /**
 * 🗑️ Lấy danh sách đơn hàng trong thùng rác
 */
public function trash(Request $request)
{
    // ✅ Chỉ cho phép admin, director, manager xem thùng rác
    $this->authorizeByRole($request->user(), ['admin', 'director', 'manager']);

    $orders = Order::onlyTrashed()
        ->with(['stages', 'comments.user'])
        ->orderBy('deleted_at', 'desc')
        ->get();

    return response()->json($orders);
}

/**
 * ♻️ Khôi phục đơn hàng từ thùng rác
 */
public function restore(Request $request, $id)
{
    // ✅ Chỉ cho phép admin, director, manager
    $this->authorizeByRole($request->user(), ['admin', 'director', 'manager']);

    $order = Order::onlyTrashed()->findOrFail($id);
    $order->restore();

    // Ghi log
    $history = $order->history ?? [];
    if (is_string($history)) {
        $history = json_decode($history, true) ?? [];
    }

    $history[] = [
        'editor' => $request->user()->name ?? 'Không rõ',
        'change' => "Khôi phục đơn hàng từ thùng rác",
        'date'   => now()->format('Y-m-d H:i:s'),
    ];

    $order->history = $history;
    $order->save();

    return response()->json([
        'message' => '✅ Đã khôi phục đơn hàng',
        'order'   => $order->fresh(['stages', 'comments.user']),
    ]);
}

/**
 * 🔥 Xóa vĩnh viễn đơn hàng
 */
public function forceDelete(Request $request, $id)
{
    // ✅ Chỉ cho phép admin, director, manager
    $this->authorizeByRole($request->user(), ['admin', 'director', 'manager']);

    $order = Order::onlyTrashed()->findOrFail($id);
    $order->forceDelete();

    return response()->json(['message' => '🔥 Đã xóa vĩnh viễn đơn hàng']);
}
/**
 * 🗑️ Xóa tất cả đơn hàng trong thùng rác
 */
public function emptyTrash(Request $request)
{
    $this->authorizeByRole($request->user(), ['admin', 'director', 'manager']);

    $orders = Order::onlyTrashed()->get();
    $count = $orders->count();

    foreach ($orders as $order) {
        $order->forceDelete(); // Xóa vĩnh viễn
    }

    return response()->json([
        'message' => "🗑️ Đã xóa vĩnh viễn {$count} đơn hàng khỏi thùng rác",
        'count' => $count,
    ]);
}
/**
 * 🕒 Tự động xóa các đơn hàng trong thùng rác quá 1 năm
 */
public function autoDeleteOldTrash()
{
    $oneYearAgo = now()->subYear();

    $orders = Order::onlyTrashed()
        ->where('deleted_at', '<', $oneYearAgo)
        ->get();

    $count = $orders->count();

    foreach ($orders as $order) {
        $order->forceDelete();
    }

    \Log::info("Auto-deleted {$count} orders from trash (older than 1 year)");

    return response()->json([
        'message' => "🕒 Đã tự động xóa {$count} đơn hàng cũ hơn 1 năm",
        'count' => $count,
    ]);
}
public function pause(Request $request, Order $order)
{
    $this->authorizeByRole($request->user(), ['admin', 'director', 'manager']);

    $request->validate([
        'reason' => 'required|string|max:500',
    ]);

    $order->is_paused = true;
    $order->pause_reason = $request->reason;
    $order->paused_at = now();
    $order->save();

    // Ghi lịch sử
    $history = $order->history ?? [];
    if (is_string($history)) {
        $history = json_decode($history, true) ?? [];
    }

    $history[] = [
        'editor' => $request->user()->name ?? 'Không rõ',
        'change' => "🛑 Hoãn đơn hàng: {$request->reason}",
        'date'   => now()->format('Y-m-d H:i:s'),
    ];

    $order->history = $history;
    $order->save();

    return response()->json([
        'message' => '✅ Đã hoãn đơn hàng',
        'order'   => $order->fresh(['stages', 'comments']),
    ]);
}

/**
 * ▶️ Tiếp tục đơn hàng
 */
public function resume(Request $request, Order $order)
{
    $this->authorizeByRole($request->user(), ['admin', 'director', 'manager']);

    $order->is_paused = false;
    $order->pause_reason = null;
    $order->paused_at = null;
    $order->save();

    // Ghi lịch sử
    $history = $order->history ?? [];
    if (is_string($history)) {
        $history = json_decode($history, true) ?? [];
    }

    $history[] = [
        'editor' => $request->user()->name ?? 'Không rõ',
        'change' => "▶️ Tiếp tục đơn hàng",
        'date'   => now()->format('Y-m-d H:i:s'),
    ];

    $order->history = $history;
    $order->save();

    return response()->json([
        'message' => '✅ Đã tiếp tục đơn hàng',
        'order'   => $order->fresh(['stages', 'comments']),
    ]);
}
public function completed(Request $request)
{
    $orders = Order::query()
        ->with(['stages' => function($q) {
            $q->orderBy('sequence')
              ->select('id', 'order_id', 'name', 'planned_start', 'planned_end', 'actual_start', 'actual_end', 'status', 'sequence');
        }])
        ->where('status', 'completed')
        ->when($request->filled('search'), function($q) use ($request) {
            $s = $request->search;
            $q->where(function($w) use ($s){
                $w->where('order_no','like',"%$s%")
                  ->orWhere('project_name','like',"%$s%")
                  ->orWhere('company_name','like',"%$s%");
            });
        })
        ->orderByDesc('completed_at')
        ->get();

    // ✅ Format lại completed_at với timezone
    return response()->json($orders->map(function($order) {
        $data = $order->toArray();

        // ✅ Thêm timezone +07:00 vào completed_at
        if ($order->completed_at) {
            $data['completed_at'] = $order->completed_at->format('Y-m-d\TH:i:sP'); // ISO 8601 with timezone
        }

        if ($order->actual_end) {
            $data['actual_end'] = $order->actual_end->format('Y-m-d\TH:i:sP');
        }

        return $data;
    }));
}

/**
 * 🗑️ Tự động xóa đơn hàng hoàn thành quá 2 năm
 */
public function autoDeleteOldCompleted()
{
    $twoYearsAgo = now()->subYears(2);

    $orders = Order::where('status', 'completed')
        ->where('completed_at', '<', $twoYearsAgo)
        ->get();

    $count = $orders->count();

    foreach ($orders as $order) {
        $order->forceDelete(); // ✅ XÓA VĨNH VIỄN (KHÔNG VÀO THÙNG RÁC)
    }

    \Log::info("Auto-deleted {$count} completed orders older than 2 years (force deleted)");

    return response()->json([
        'message' => "🔥 Đã tự động xóa vĩnh viễn {$count} đơn hàng hoàn thành cũ hơn 2 năm",
        'count' => $count,
    ]);
}
public function deleteCompleted(Request $request, Order $order)
{
    $this->authorizeByRole($request->user(), ['admin']);

    if ($order->status !== 'completed') {
        return response()->json([
            'message' => '❌ Chỉ có thể xóa đơn hàng đã hoàn thành',
        ], 422);
    }

    $order->delete();

    return response()->json([
        'message' => '✅ Đã xóa đơn hàng hoàn thành',
    ]);
}

/**
 * 🗑️ Xóa tất cả đơn hàng hoàn thành
 */
public function deleteAllCompleted(Request $request)
{
    $this->authorizeByRole($request->user(), ['admin']);

    $orders = Order::where('status', 'completed')->get();
    $count = $orders->count();

    foreach ($orders as $order) {
        $order->delete();
    }

    \Log::info("Admin '{$request->user()->name}' deleted {$count} completed orders");

    return response()->json([
        'message' => "🗑️ Đã xóa {$count} đơn hàng hoàn thành",
        'count' => $count,
    ]);
}
}

<?php

namespace App\Http\Controllers;

use App\Models\StageTemplate;
use Illuminate\Http\Request;

class StageTemplateController extends Controller
{
    public function index(Request $request)
    {
        $query = StageTemplate::query()
            ->where('is_active', 1)
            ->orderBy('sequence', 'asc');

        // 🔹 Lọc theo loại đơn hàng (door / metal)
        if ($request->filled('order_type')) {
            $query->where('order_type', $request->order_type);
        }

        $templates = $query->get();

        // 🔹 Nếu không có kết quả, trả thông báo để Flutter debug dễ hơn
        if ($templates->isEmpty()) {
            return response()->json([
                'message' => 'Không có công đoạn phù hợp với loại đơn hàng này.',
                'order_type' => $request->order_type
            ], 404);
        }

        // 🔹 Map dữ liệu về frontend, thêm (Bước X) vào tên
        return $templates->map(function ($tpl) {
            return [
                'id' => $tpl->id,
                'order_type' => $tpl->order_type,
                'code' => $tpl->code,
                'name' => "{$tpl->name} (Bước {$tpl->sequence})",
                'sequence' => $tpl->sequence,
                'default_duration_days' => $tpl->default_duration_days,
            ];
        });
    }
}

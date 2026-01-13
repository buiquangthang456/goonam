<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use Illuminate\Http\Request;

class NotifyController extends Controller
{
    // số lượng thông báo chưa đọc
    public function badge(Request $req)
    {
        $count = Notification::where('user_id', $req->user()->id)
            ->where('is_read', false)
            ->count();

        return response()->json(['badge' => $count]);
    }

    // danh sách thông báo
    public function index(Request $req)
    {
        return Notification::where('user_id', $req->user()->id)
            ->orderByDesc('created_at')
            ->limit(50)
            ->get();
    }

    // đánh dấu 1 notify đã đọc
    public function read(Request $req, $id)
    {
        $notify = Notification::where('user_id', $req->user()->id)->findOrFail($id);
        $notify->update(['is_read' => true]);

        return response()->json(['success' => true]);
    }
}

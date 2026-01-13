<?php

namespace App\Http\Controllers;

use App\Models\DeviceToken;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
   public function store(Request $req)
    {
        $req->validate([
            'token' => 'required|string',
            'device_type' => 'nullable|string'
        ]);

        $user = $req->user();

        // Update hoặc tạo mới
        $deviceToken = DeviceToken::updateOrCreate(
            ['token' => $req->token],
            ['user_id' => $user?->id, 'device_type' => $req->device_type]
        );

        return response()->json(['success' => true, 'token' => $deviceToken]);
    }

    public function destroy(Request $req)
    {
        $req->validate(['token'=>'required|string']);
        DeviceToken::where('token', $req->token)->delete();
        return response()->json(['success'=>true]);
    }
}

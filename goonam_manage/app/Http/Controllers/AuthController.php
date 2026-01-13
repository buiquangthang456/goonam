<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
class AuthController extends Controller
{
    public function login(Request $req)
    {
        $req->validate([
            'name' => 'required|string',
            'password' => 'required'
        ]);

        if (!Auth::attempt($req->only('name','password'))) {
            return response()->json(['message'=>'Invalid credentials'], 401);
        }

        $user = $req->user();
        if (!$user->is_active) {
            return response()->json(['message'=>'Account disabled'], 403);
        }

        $token = $user->createToken('api')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user'  => [
                'id'=>$user->id,
                'name'=>$user->name,
                'email'=>$user->email,
                'role'=>$user->role
            ]
        ]);
    }

    public function me(Request $req)
    {
         $user = $req->user();
            return response()->json([
                'id'    => $user->id,
                'name'  => $user->name,
                'email' => $user->email,
                'role'  => $user->role,   // ✅ đảm bảo luôn có role
            ]);
    }


    public function logout(Request $req)
    {
        $req->user()->currentAccessToken()->delete();
        return response()->json(['message'=>'Logged out']);
    }
    public function store(Request $request)
        {
    $request->validate([
        'name' => 'required|string|max:255',
        'email' => 'required|email|unique:users',
        'password' => 'required|string|min:6',
        'role' => 'required|in:director,manager,staff',
    ]);

    // Lấy người dùng hiện tại (đang đăng nhập)
    $creator = $request->user();

    // 🔒 Chỉ cho phép admin hoặc director tạo tài khoản
    if (!in_array($creator->role, ['admin', 'director'])) {
        return response()->json(['message' => 'Bạn không có quyền tạo tài khoản mới'], 403);
    }

    $user = User::create([
        'name' => $request->name,
        'email' => $request->email,
        'password' => Hash::make($request->password),
        'role' => $request->role,
    ]);

    return response()->json([
        'message' => 'Tạo tài khoản thành công',
        'user' => $user,
    ], 201);
}

}

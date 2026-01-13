<?php

use Illuminate\Support\Facades\Broadcast;

/*
|--------------------------------------------------------------------------
| Broadcast Channels
|--------------------------------------------------------------------------
|
| Here you may register all of the event broadcasting channels that your
| application supports. The given channel authorization callbacks are
| used to check if an authenticated user can listen to the channel.
|
*/

Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});
Broadcast::channel('order.{orderId}', function ($user, $orderId) {
    // ✅ Cho phép nếu user có quyền xem đơn hàng này
    return true; // hoặc kiểm tra quyền cụ thể
});

Broadcast::channel('user.{userId}', function ($user, $userId) {
    // ✅ Cho phép user nhận thông báo của chính mình
    return (int) $user->id === (int) $userId;
});

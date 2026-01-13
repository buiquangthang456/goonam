<?php

use Illuminate\Support\Facades\Route;
use App\Events\PushFcmNotification;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Http\Request;
use App\Events\CommentAdded;
use App\Models\Comment;
/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/

Route::get('/', function () {
    return view('welcome');
});
Route::get('/test-fcm', function () {
    event(new PushFcmNotification(
        '🔔 Thông báo thử nghiệm',
        'FCM đã hoạt động từ Laravel Queue!',
        ['test' => 'ok']
    ));
    return 'Đã gửi event PushFcmNotification, kiểm tra queue nhé!';
});

// 🔹 Flush toàn bộ job cũ
Route::get('/admin-run-artisan/queue:flush/goonam2025', function () {
    Artisan::call('queue:flush');
    return '✅ Queue flushed';
});

// 🔹 Restart queue workers
Route::get('/admin-run-artisan/queue:restart/goonam2025', function () {
    Artisan::call('queue:restart');
    return '✅ Queue restarted';
});

// 🔹 Chạy queue xử lý một lần rồi dừng
Route::get('/admin-run-artisan/queue:work--stop-when-empty/goonam2025', function () {
    Artisan::call('queue:work --stop-when-empty');
    return '✅ Queue executed and stopped when empty';
});
Route::get('/test-pusher', function () {
    // Lấy một comment thật trong DB để test
    $comment = Comment::first();

    if (!$comment) {
        return '⚠️ Không có comment nào trong database để test.';
    }

    event(new CommentAdded($comment));

    return '✅ Đã gửi event CommentAdded lên Pusher';
});
Route::get('/run-migrate', function () {
    try {
        \Artisan::call('migrate', ['--force' => true]);
        return 'Migration chạy thành công';
    } catch (\Exception $e) {
        return $e->getMessage();
    }
});

<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\OrderController;
use App\Http\Controllers\StageController;
use App\Http\Controllers\ExportController;
use App\Http\Controllers\DeviceTokenController;
use App\Http\Controllers\NotifyController;
use App\Http\Controllers\CommentController;
use App\Http\Controllers\StageTemplateController;
use Illuminate\Support\Facades\Broadcast;
/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| is assigned the "api" middleware group. Enjoy building your API!
|
*/
Broadcast::routes(['middleware' => ['auth:sanctum']]);
Route::post('/auth/login', [AuthController::class,'login']);
Route::get('/stage-templates', [StageTemplateController::class, 'index']);
Route::middleware('auth:sanctum')->group(function(){
  Route::get('/me', [AuthController::class,'me']);
  Route::post('/auth/logout', [AuthController::class,'logout']);
  Route::post('/users', [AuthController::class, 'store']);

  // ==========================================
  // ✅ ORDERS - COMPLETED (ĐẶT TRƯỚC TẤT CẢ)
  // ==========================================
  Route::get('orders/completed', [OrderController::class, 'completed']);
  Route::delete('orders/completed/delete-all', [OrderController::class, 'deleteAllCompleted']); // ✅ TRƯỚC
  Route::delete('orders/completed/{order}', [OrderController::class, 'deleteCompleted']); // ✅ SAU
  Route::post('orders/auto-delete-old-completed', [OrderController::class, 'autoDeleteOldCompleted']);

  // ==========================================
  // ✅ ORDERS - TRASH
  // ==========================================
  Route::get('/orders/trash', [OrderController::class, 'trash']);
  Route::delete('/orders/trash/empty', [OrderController::class, 'emptyTrash']);
  Route::post('/orders/trash/auto-clean', [OrderController::class, 'autoDeleteOldTrash']);

  // ==========================================
  // ✅ ORDERS - RESTORE & FORCE DELETE (WILDCARD)
  // ==========================================
  Route::post('/orders/{order}/restore', [OrderController::class, 'restore']);
  Route::delete('/orders/{order}/force-delete', [OrderController::class, 'forceDelete']);
  Route::post('/orders/{order}/pause', [OrderController::class, 'pause']);
  Route::post('/orders/{order}/resume', [OrderController::class, 'resume']);

  // ==========================================
  // ✅ ORDERS - GENERAL
  // ==========================================
  Route::get('/orders', [OrderController::class,'index']);
  Route::post('/orders', [OrderController::class,'store']);
  Route::get('/orders/export-statistics', [ExportController::class, 'exportStatistics']);
  Route::get('/orders/{order}/export', [ExportController::class,'exportExcel']);
  Route::get('/orders/{order}', [OrderController::class,'show']);
  Route::put('/orders/{order}', [OrderController::class,'update']);
  Route::delete('/orders/{order}', [OrderController::class,'destroy']);


  // ✅ THÊM 2 ROUTE MỚI
  Route::post('/orders/{order}/pause', [OrderController::class, 'pause']);
  Route::post('/orders/{order}/resume', [OrderController::class, 'resume']);

  Route::put('/orders/{order}/stages/{stage}/start', [StageController::class,'start']); // admin/dir/manager
  Route::put('/orders/{order}/stages/{stage}/material-request', [StageController::class, 'updateMaterialRequestDate']);
  Route::put('/orders/{order}/stages/{stage}/delay-reason', [StageController::class, 'updateDelayReason']);
  Route::put('/orders/{order}/stages/{stage}/time', [StageController::class, 'updateTime']);
  Route::put('/orders/{order}/stages/{stage}/done', [StageController::class,'done']);   // push notify
  Route::put('/orders/{order}/stages/{stage}', [StageController::class, 'updateTime']);
  Route::get('/stages/daily-plan/{date}', [StageController::class, 'exportDailyPlan']);

  Route::get('/comments/unread-count', [CommentController::class, 'unreadCount']);
  Route::post('/orders/{order}/comments/mark-as-read', [CommentController::class, 'markAsRead']);
  Route::post('/comments/mark-all-as-read', [CommentController::class, 'markAllAsRead']);
  Route::get('/orders/{order}/comments', [CommentController::class,'index']);
  Route::post('/orders/{order}/comments', [CommentController::class,'store']); // admin/dir/manager
  Route::put('/orders/{order}/comments/{comment}', [CommentController::class, 'update']);
  Route::delete('/orders/{order}/comments/{comment}', [CommentController::class, 'destroy']);


  Route::get('/notifications/badge', [NotifyController::class,'badge']);
  Route::get('/notifications', [NotifyController::class,'index']);
  Route::post('/notifications/{id}/read', [NotifyController::class,'read']);

  Route::post('/device-tokens', [DeviceTokenController::class,'store']);
Route::delete('/device-tokens', [DeviceTokenController::class,'destroy']);


  Route::get('/orders/{order}/export', [ExportController::class,'exportExcel']); // Excel


});
Route::get('/app/version', function () {
    return response()->json([
        'version' => '1.0.16', // ⚙️ Phiên bản mới nhất trên server
        'download_url' => 'https://api.goonamvina.com/public/downloads/GoonamVinaSetup.exe',
        'changelog' => '🔧 Sửa lỗi giao diện và tối ưu hiệu suất.',
    ]);
});

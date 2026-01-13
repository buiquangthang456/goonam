<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Order;

class AutoCleanTrash extends Command
{
    protected $signature = 'trash:auto-clean';
    protected $description = 'Tự động xóa các đơn hàng trong thùng rác quá 1 năm';

    public function handle()
    {
        $oneYearAgo = now()->subYear();

        $orders = Order::onlyTrashed()
            ->where('deleted_at', '<', $oneYearAgo)
            ->get();

        $count = $orders->count();

        foreach ($orders as $order) {
            $order->forceDelete();
        }

        $this->info("✅ Đã xóa {$count} đơn hàng cũ hơn 1 năm khỏi thùng rác");

        \Log::info("Auto-cleaned trash: {$count} orders deleted");

        return 0;
    }
}

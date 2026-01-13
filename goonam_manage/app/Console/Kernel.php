<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * Define the application's command schedule.
     *
     * @param  \Illuminate\Console\Scheduling\Schedule  $schedule
     * @return void
     */
    protected function schedule(Schedule $schedule)
    {
        $schedule->command('stages:check-overdue')->everyTenMinutes();

        // ✅ Command mới - tự động xóa thùng rác mỗi ngày lúc 2h sáng
        $schedule->command('trash:auto-clean')
                 ->daily()
                 ->at('02:00');


        // ✅ Xóa vĩnh viễn đơn hoàn thành > 2 năm - 2:30 AM (TRÁNH TRÙNG)
        $schedule->call(function () {
            app(\App\Http\Controllers\OrderController::class)->autoDeleteOldCompleted();
        })->dailyAt('02:30');
    }

    /**
     * Register the commands for the application.
     *
     * @return void
     */
    protected function commands()
    {
        $this->load(__DIR__.'/Commands');

        require base_path('routes/console.php');
    }
}

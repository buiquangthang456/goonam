<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\OrderStage;          // thêm dòng này
use App\Events\StageOverdue;        // thêm dòng này

class CheckOverdueStages extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
     protected $signature = 'stages:check-overdue';

    /**
     * The console command description.
     *
     * @var string
     */
     protected $description = 'Check all order stages that are overdue and update their status.';

    /**
     * Execute the console command.
     *
     * @return int
     */
     public function handle()
    {
        $stages = OrderStage::where('status', '!=', 'done')
            ->where('planned_end', '<', now())
            ->get();

        foreach ($stages as $st) {
            if (!$st->is_overdue) {
                $st->update([
                    'is_overdue' => true,
                    'status'     => 'late'
                ]);

                $st->order->update(['highlight_flag' => true]);

                event(new StageOverdue($st));
            }
        }

        $this->info('Overdue stages checked successfully.');

        return Command::SUCCESS;
    }

}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class OrderStage extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id',
        'template_id',
        'code',
        'name',
        'sequence',
        'planned_start',
        'planned_end',
        'original_planned_end',
        'actual_start',
        'actual_end',
        'status',
        'is_overdue',
        'is_skipped',
        'delay_reason',
        'delay_reason_history',
        'material_request_date',

    ];

    protected $casts = [
        'id' => 'integer',
        'order_id' => 'integer',
        'sequence' => 'integer',
        'planned_start' => 'date:Y-m-d',
        'planned_end'   => 'date:Y-m-d',
        'original_planned_end' => 'date:Y-m-d',
        'actual_start'  => 'datetime',
        'actual_end'    => 'datetime',
        'material_request_date' => 'datetime',
        'is_overdue'    => 'boolean',
        'is_skipped'    => 'boolean',
        'delay_reason_history' => 'array',

    ];

    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function getRemainingDaysAttribute()
    {
        return $this->planned_end
            ? Order::toHalfDays(now(), $this->planned_end, true)
            : null;
    }

    /**
     * Đánh dấu công đoạn hoàn thành
     */
   public function markDone() {
        $this->actual_end = now();
        $this->status = 'done';
        $this->is_overdue = false;
        $this->save();
        // ❌ TẮT HOÀN TOÀN AUTO JUMP — không động gì tới stage kế tiếp // Không set planned_start // Không set planned_end // Không trigger next stage logic event(new \App\Events\StageCompleted($this));

    }
    public function checkOverdue()
{
    if (!$this->planned_end) return;

    $now = now();

    // 🔸 Nếu công đoạn chưa xong và đã quá hạn -> đánh dấu trễ
    if ($this->status !== 'done' && $now->gt($this->planned_end)) {
        if (!$this->is_overdue || $this->status !== 'late') {
            $this->is_overdue = true;
            $this->status = 'late';

            // 🔹 Nếu chưa có lý do, đặt tạm là “Chưa nhập lý do”
            if (empty($this->delay_reason)) {
                $this->delay_reason = 'Chưa nhập lý do';
            }

            $this->save();
        }
    } else {
        // 🔹 Nếu đã hoàn thành thì bỏ trạng thái trễ
        if ($this->is_overdue && $this->status === 'done') {
            $this->is_overdue = false;
            $this->save();
        }
    }
}
public function isLocked()
{
    return $this->is_skipped === true;
}
}

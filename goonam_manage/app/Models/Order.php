<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Order extends Model
{
    use HasFactory;
    use SoftDeletes;
    protected $fillable = [
        'order_type',
        'project_name',
        'company_name',
        'order_no',
        'description',
        'quantity',
        'order_date',
        'delivery_date',
        'original_delivery_date',
        'actual_end',
        'status',
        'history',
        'is_paused',
        'pause_reason',
        'paused_at',
        'completed_at',
    ];

    protected $casts = [
        'id' => 'integer',
        'quantity' => 'integer',
        'highlight_flag' => 'integer',
        'order_date'    => 'date',
        'delivery_date' => 'date',
        'original_delivery_date' => 'date',
        'actual_end'    => 'date',
        'history'       => 'array',
        'admin_edit_logs' => 'array',
        'is_paused' => 'boolean',
        'paused_at' => 'datetime',
        'completed_at' => 'datetime',
    ];

    protected $appends = [
        'overall_status',
        'remaining_days',
        'time_budget_days', // ✅ bỏ phần 'history' => 'array'
    ];
    protected $dates = ['deleted_at'];
    // ======= ACCESSORS =======
 public function getOverallStatusAttribute()
{
    $original = $this->original_delivery_date ?? $this->delivery_date;
    $actual   = $this->actual_end;
    $now      = now()->startOfDay();

    // ✅ Lấy các công đoạn có thời gian
    $realStages = $this->stages->filter(function ($s) {
        return !$s->is_skipped
            && (!is_null($s->planned_start) || !is_null($s->planned_end));
    });

    // ✅ TH1: Nếu KHÔNG có công đoạn nào có thời gian
    if ($realStages->isEmpty()) {
        if ($this->status === 'completed') {
            return 'done';
        }

        // ✅ Chỉ tính trễ khi ĐÃ QUA ngày giao (> endOfDay)
        if ($original) {
            $deliveryDay = \Carbon\Carbon::parse($original)->endOfDay(); // 23:59:59
            if ($now->gt($deliveryDay)) { // Chỉ > (không bao gồm =)
                return 'late';
            }
        }

        return 'in_progress';
    }

    // ✅ TH2: Nếu tất cả công đoạn đã hoàn thành
    if ($realStages->every(fn($s) => $s->status === 'done')) {
        if (!$actual) {
            return 'completed_early';
        }

        if ($original) {
            $originalDay = $original->copy()->startOfDay();
            $actualDay = $actual->copy()->startOfDay();

            if ($actualDay->gt($originalDay)) {
                return 'completed_late';
            } elseif ($actualDay->lt($originalDay)) {
                return 'completed_early';
            }
        }

        return 'done';
    }

    // ✅ TH3: Kiểm tra công đoạn trễ (> endOfDay)
    foreach ($realStages as $stage) {
        if ($stage->status === 'done') continue;

        if ($stage->planned_end) {
            $deadline = \Carbon\Carbon::parse($stage->planned_end)->endOfDay();

            if ($now->gt($deadline)) { // Chỉ > (không bao gồm =)
                return 'late';
            }
        }
    }

    // ✅ TH4: Nếu đã qua ngày giao hàng (> endOfDay)
    if ($original) {
        $originalDay = $original->copy()->endOfDay();
        if ($now->gt($originalDay)) { // Chỉ > (không bao gồm =)
            return 'late';
        }
    }

    return 'in_progress';
}

    public function getTimeBudgetDaysAttribute()
    {
        if (!$this->order_date || !$this->delivery_date) return null;

        $minutes = $this->order_date->diffInMinutes($this->delivery_date, false);
        if ($minutes <= 0) return "0 giờ";

        $days = intdiv($minutes, 1440);
        $hours = intdiv($minutes % 1440, 60);

        $result = '';
        if ($days > 0) $result .= $days . ' ngày';
        if ($hours > 0) $result .= ($result ? ' ' : '') . $hours . ' giờ';

        return $result ?: 'Dưới 1 giờ';
    }

    public function getRemainingDaysAttribute()
{
    if (!$this->delivery_date) return null;

    $now = now();
    $deadline = $this->delivery_date->copy()->endOfDay(); // ✅ Lấy cuối ngày

    $minutes = $now->diffInMinutes($deadline, false);
    $isLate = $minutes < 0;

    // ✅ Nếu còn trong ngày deadline → không hiển thị số âm
    if ($isLate && $now->isSameDay($this->delivery_date)) {
        return "0 giờ"; // Hoặc "Hết hạn hôm nay"
    }

    $absMinutes = abs($minutes);
    $days = intdiv($absMinutes, 1440);
    $hours = intdiv($absMinutes % 1440, 60);

    $result = '';
    if ($days > 0) $result .= $days . ' ngày';
    if ($hours > 0) $result .= ($result ? ' ' : '') . $hours . ' giờ';
    if ($result === '') $result = 'Dưới 1 giờ';

    return $isLate ? "-$result" : $result;
}

    // ======= RELATIONS =======
    public function stages()
    {
        return $this->hasMany(OrderStage::class)->orderBy('sequence');
    }

    public function comments()
    {
        return $this->hasMany(Comment::class);
    }

}

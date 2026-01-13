<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\OrderStage;
use Illuminate\Http\Request;
use Carbon\Carbon; // ✅ thêm dòng này
use Barryvdh\DomPDF\Facade\Pdf; // nếu bạn dùng dompdf
use Illuminate\Support\Facades\DB;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Fill;

class StageController extends Controller
{
    public function start(Request $req, Order $order, OrderStage $stage)
    {
        $this->authorizeByRole($req->user(), ['admin', 'director', 'manager']);

        if ($stage->order_id !== $order->id) abort(404);

        if (!$stage->actual_start) {
            $stage->actual_start = now();
            $stage->status = 'in_progress';
            $stage->save();
        }

        return $stage->fresh();
    }

  public function done(Request $req, Order $order, OrderStage $stage)
{
    $this->authorizeByRole($req->user(), ['admin', 'director', 'manager', 'staff']);

    if ($stage->order_id !== $order->id) abort(404);

    if ($stage->status === 'done') {
        // ✅ Nếu đã done thì revert lại in_progress
        $stage->actual_end = null;
        $stage->status = 'in_progress';
        $stage->save();
    } else {
        // ✅ Nếu chưa done thì mark done
        if (method_exists($stage, 'markDone')) {
            $stage->markDone();
        } else {
            $stage->actual_end = now();
            $stage->status = 'done';
            $stage->is_overdue = false;
            $stage->save();
            event(new \App\Events\StageCompleted($stage));
        }
    }

    // ✅ LOGIC MỚI: Kiểm tra xem TẤT CẢ công đoạn đã done chưa
    $allStages = $order->stages()->where('is_skipped', false)->get();

    // ✅ Nếu KHÔNG có công đoạn nào → không thể hoàn thành đơn
    if ($allStages->isEmpty()) {
        $order->status = 'in_progress';
        $order->actual_end = null;
        $order->completed_at = null;
        $order->save();
        return $stage->fresh();
    }

    // ✅ Kiểm tra xem TẤT CẢ công đoạn (kể cả không có thời gian) đã done chưa
    $allDone = $allStages->every(fn($s) => $s->status === 'done');

    if ($allDone) {
        // ✅ TẤT CẢ công đoạn đã xong → Đơn hàng hoàn thành
        $order->status = 'completed';
        $order->highlight_flag = false;
        $order->actual_end = now();
        $order->completed_at = now();
        $order->save();

        // ✅ Ghi log lịch sử
        $history = $order->history ?? [];
        if (is_string($history)) {
            $history = json_decode($history, true) ?? [];
        }

        $history[] = [
            'editor' => $req->user()->name ?? 'Hệ thống',
            'change' => '✅ Đơn hàng đã hoàn thành (tất cả công đoạn đã xong)',
            'date'   => now()->format('Y-m-d H:i:s'),
        ];

        $order->history = $history;
        $order->save();
    } else {
        // ✅ Nếu còn stage chưa xong thì giữ đơn hàng ở in_progress
        if ($order->status === 'completed') {
            $order->status = 'in_progress';
            $order->actual_end = null;
            $order->completed_at = null;
            $order->save();
        }
    }

    return $stage->fresh();
}

    private function authorizeByRole($user, array $roles)
    {
        if (!in_array($user->role, $roles)) {
            abort(403, 'Forbidden');
        }
    }

   public function updateTime(Request $req, Order $order, OrderStage $stage)
{
    $this->authorizeByRole($req->user(), ['admin', 'director', 'manager']);
    if ($stage->order_id !== $order->id) abort(404);

    $req->validate([
        'planned_start' => 'nullable|string',
        'planned_end'   => 'nullable|string',
        'delay_reason'  => 'nullable|string|max:1000',
    ]);

    $start = $req->input('planned_start');
    $end   = $req->input('planned_end');

    // ✅ Chuẩn hóa null
    $start = in_array($start, [0, '0', '', null], true) ? null : $start;
    $end   = in_array($end, [0, '0', '', null], true) ? null : $end;

    $oldStart = $stage->planned_start;
    $oldEnd   = $stage->planned_end;

    // ✅ Xác định có bị bỏ qua không
    $skip = is_null($start) && is_null($end);

    if ($skip) {
        $stage->planned_start = null;
        $stage->planned_end   = null;
        $stage->is_skipped    = true;
        $stage->status = 'pending';
    } else {
        $parseDate = function ($val) {
            if (in_array($val, [0, "0", null, ""], true)) return null;
            try {
                return Carbon::parse($val);
            } catch (\Exception $e) {
                return null;
            }
        };

        $newStart = $parseDate($start);
        $newEnd   = $parseDate($end);

        // ✅ LƯU THỜI GIAN GỐC NẾU LẦN ĐẦU TIÊN THIẾT LẬP
        if (is_null($stage->original_planned_end) && $newEnd) {
            $stage->original_planned_end = $newEnd;
        }

        $stage->planned_start = $newStart;
        $stage->planned_end   = $newEnd;
        $stage->is_skipped    = false;
         // ✅ THÊM ĐOẠN NÀY - XÓA actual_end NẾU CÔNG ĐOẠN ĐÃ HOÀN THÀNH
        if ($stage->actual_end !== null) {
            \Log::info("Stage #{$stage->id} was completed, resetting to pending");
            $stage->actual_end = null;
            $stage->status = 'pending';
        }
    }

    // ✅ Nếu ngày kết thúc < ngày bắt đầu
    if ($stage->planned_start && $stage->planned_end && $stage->planned_end->lt($stage->planned_start)) {
        return response()->json(['message' => '❌ Ngày kết thúc không thể trước ngày bắt đầu!'], 422);
    }

    // ✅ Nếu gia hạn mà không có lý do
    if (!$skip && $oldEnd && $stage->planned_end && $stage->planned_end->gt($oldEnd) && empty($req->delay_reason)) {
        return response()->json([
            'message' => 'Vui lòng nhập lý do gia hạn công đoạn trước khi lưu!'
        ], 422);
    }

    // ✅ Lưu lý do trễ nếu có
    if (!empty($req->delay_reason)) {
        $stage->delay_reason = $req->delay_reason;
        $historyList = is_string($stage->delay_reason_history)
            ? json_decode($stage->delay_reason_history, true) ?? []
            : ($stage->delay_reason_history ?? []);

        $entry = [
            'reason' => $req->delay_reason,
            'date'   => now()->format('Y-m-d H:i:s'),
            'editor' => $req->user()->name ?? 'Không rõ',
        ];
        $historyList[] = $entry;
        $stage->delay_reason_history = $historyList;

        $stage->delay_reason = collect($historyList)
            ->map(fn($h) => "- {$h['reason']} (" . Carbon::parse($h['date'])->format('d/m/Y H:i') . ")")
            ->join("\n");
    }

    $stage->save();
      // ✅ CẬP NHẬT STATUS ĐƠN HÀNG
    $this->updateOrderStatus($order);

    // ✅ Ghi log vào lịch sử đơn hàng
    $editor = $req->user()->name ?? 'Không rõ';
    $now = now()->format('Y-m-d H:i:s');

    $history = is_string($order->history)
        ? json_decode($order->history, true) ?? []
        : ($order->history ?? []);

    $log = [
        'editor' => $editor,
        'change' => $skip
            ? "Bỏ qua công đoạn '{$stage->name}'"
            : "Cập nhật thời gian công đoạn '{$stage->name}': "
                . "Bắt đầu " . ($oldStart ? $oldStart->format('d/m/Y') : '—')
                . " → " . ($stage->planned_start ? $stage->planned_start->format('d/m/Y') : '—')
                . ", kết thúc " . ($oldEnd ? $oldEnd->format('d/m/Y') : '—')
                . " → " . ($stage->planned_end ? $stage->planned_end->format('d/m/Y') : '—'),
        'date' => $now,
    ];

    $history[] = $log;
    $order->history = $history;
    $order->save();

    return response()->json([
        'message' => $skip ? '✅ Đã bỏ qua công đoạn' : '✅ Đã cập nhật thời gian công đoạn',
        'stage'   => $stage->fresh(),
    ]);
}
private function updateOrderStatus(Order $order)
{
    $stages = $order->stages()
        ->where('is_skipped', false)
        ->get();

    if ($stages->isEmpty()) {
        return; // Không có công đoạn → không làm gì
    }

    // Đếm số công đoạn đã hoàn thành (status = 'done')
    $completedStages = $stages->where('status', 'done')->count();
    $totalStages = $stages->count();

    if ($completedStages === $totalStages) {
        // ✅ Tất cả công đoạn đã xong → Đơn hoàn thành
        if ($order->status !== 'completed') {
            $order->status = 'completed';
            $order->completed_at = now();
            $order->save();
            \Log::info("Order #{$order->id} marked as completed");
        }
    } else {
        // ✅ Còn công đoạn chưa xong → Đơn đang làm
        if ($order->status === 'completed') {
            $order->status = 'in_progress';
            $order->completed_at = null;
            $order->save();
        }
    }
}


public function updateDelayReason(Request $req, Order $order, OrderStage $stage)
{
    $this->authorizeByRole($req->user(), ['admin', 'director', 'manager']);

    if ($stage->order_id !== $order->id) {
        abort(404, 'Stage không thuộc đơn hàng này');
    }

    $req->validate([
        'delay_reason' => 'required|string|max:1000',
    ]);

    // ✅ Đảm bảo cột này luôn là array
    $historyList = $stage->delay_reason_history;
    if (empty($historyList) || !is_array($historyList)) {
        $historyList = [];
    }

    // ✅ Thêm lý do mới
    $entry = [
        'reason' => $req->delay_reason,
        'date'   => now()->format('Y-m-d H:i:s'),
        'editor' => $req->user()->name ?? 'Không rõ',
    ];
    $historyList[] = $entry;

    // ✅ Ghi đè lại JSON
    $stage->delay_reason_history = $historyList;

    // ✅ Gộp chuỗi hiển thị đẹp cho Excel
    $stage->delay_reason = collect($historyList)
        ->map(function ($h) {
            $formatted = \Carbon\Carbon::parse($h['date'])->format('d/m/Y H:i');
            return "- {$h['reason']} ({$formatted})";
        })
        ->join("\n");

    $stage->save();

    // 🧾 Ghi thêm vào lịch sử đơn hàng
    $history = $order->history ?? [];
    if (is_string($history)) {
        $history = json_decode($history, true) ?? [];
    }

    $history[] = [
        'editor' => $req->user()->name ?? 'Không rõ',
        'change' => "Cập nhật lý do trễ công đoạn '{$stage->name}': {$req->delay_reason}",
        'date'   => now()->format('Y-m-d H:i:s'),
    ];

    $order->history = $history;
    $order->save();

    return response()->json([
        'message' => 'Đã cập nhật lý do trễ',
        'stage'   => $stage->fresh(),
    ]);
}
public function updateMaterialRequestDate(Request $req, Order $order, OrderStage $stage)
{
    $this->authorizeByRole($req->user(), ['admin', 'director', 'manager']);

    if ($stage->order_id !== $order->id) {
        abort(404, 'Stage không thuộc đơn hàng này');
    }

    $req->validate([
        'material_request_date' => 'required|date',
    ]);

    $oldDate = $stage->material_request_date;
    $newDate = Carbon::parse($req->material_request_date);

    $stage->material_request_date = $newDate;
    $stage->save();

    // Ghi vào lịch sử đơn hàng
    $history = $order->history ?? [];
    if (is_string($history)) $history = json_decode($history, true) ?: [];

    $history[] = [
        'editor' => $req->user()->name ?? 'Không rõ',
        'change' => "Gửi yêu cầu vật tư cho công đoạn '{$stage->name}': "
                    . ($oldDate ? $oldDate->format('d/m/Y H:i') : 'Chưa có')
                    . " → " . $newDate->format('d/m/Y H:i'),
        'date'   => now()->format('Y-m-d H:i:s'),
    ];

    $order->history = $history;
    $order->save();

    return response()->json([
        'message' => '✅ Đã cập nhật ngày yêu cầu vật tư',
        'stage'   => $stage->fresh(),
    ]);
}

public function exportDailyPlan($date)
{
    try {
        $day = Carbon::parse($date)->startOfDay();

        // ✅ Lấy đơn hàng CỬA và KIM LOẠI riêng biệt
        $doorOrders = Order::with(['stages' => function($q) {
                $q->where('is_skipped', false)->orderBy('sequence');
            }])
            ->where('order_type', 'door') // ✅ CHỈ LẤY CỬA
            ->whereIn('status', ['pending', 'in_progress', 'late'])
            ->orderBy('delivery_date', 'asc')
            ->get();

        $metalOrders = Order::with(['stages' => function($q) {
                $q->where('is_skipped', false)->orderBy('sequence');
            }])
            ->where('order_type', 'metal') // ✅ CHỈ LẤY KIM LOẠI
            ->whereIn('status', ['pending', 'in_progress', 'late'])
            ->orderBy('delivery_date', 'asc')
            ->get();

        if ($doorOrders->isEmpty() && $metalOrders->isEmpty()) {
            return response()->json(['message' => 'Không có đơn hàng nào'], 404);
        }

        $spreadsheet = new Spreadsheet();

        // ✅ SHEET 1: ĐƠN HÀNG CỬA
        $doorSheet = $spreadsheet->getActiveSheet();
        $doorSheet->setTitle('Đơn hàng CỬA');
        $this->fillDailyPlanSheet($doorSheet, $doorOrders, $day, 'CỬA');

        // ✅ SHEET 2: ĐƠN HÀNG KIM LOẠI
        if ($metalOrders->isNotEmpty()) {
            $metalSheet = $spreadsheet->createSheet();
            $metalSheet->setTitle('Đơn hàng Kim loại');
            $this->fillDailyPlanSheet($metalSheet, $metalOrders, $day, 'KIM LOẠI');
        }

        // Xuất file
        $timestamp = now()->format('YmdHis');
        $fileName = 'KeHoachNgay-' . $day->format('Ymd') . '-' . $timestamp . '.xlsx';
        $writer = new Xlsx($spreadsheet);

        header('Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        header('Content-Disposition: attachment;filename="' . $fileName . '"');
        header('Cache-Control: max-age=0');

        $writer->save('php://output');
        exit;

    } catch (\Throwable $e) {
        \Log::error('Excel Export Error:', [
            'message' => $e->getMessage(),
            'line' => $e->getLine(),
        ]);

        return response()->json([
            'error' => 'Lỗi xuất Excel',
            'message' => $e->getMessage(),
        ], 500);
    }
}

/**
 * ✅ HÀM PHỤ: Điền dữ liệu vào sheet
 */
private function fillDailyPlanSheet($sheet, $orders, $day, $type)
{
    // Tiêu đề
    $sheet->setCellValue('A1', 'BẢNG KẾ HOẠCH SẢN XUẤT NGÀY ' . $day->format('d/m/Y'));
    $sheet->mergeCells('A1:S1');
    $sheet->getStyle('A1')->getFont()->setBold(true)->setSize(16);
    $sheet->getStyle('A1')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);

    $sheet->setCellValue('A2', "Loại đơn hàng: $type");
    $sheet->mergeCells('A2:S2');
    $sheet->getStyle('A2')->getFont()->setBold(true)->setSize(12);
    $sheet->getStyle('A2')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);

    $totalOrders = $orders->count();
    $totalStages = $orders->sum(fn($o) => $o->stages->where('status', '!=', 'done')->count());

    $sheet->setCellValue('A3', "Tổng công đoạn cần làm: {$totalStages} | Tổng đơn hàng: {$totalOrders}");
    $sheet->mergeCells('A3:S3');
    $sheet->getStyle('A3')->getFont()->setBold(true);
    $sheet->getStyle('A3')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);

    // Header
    $row = 4;
    $headers = [
        'STT', 'Đơn hàng', 'Khách hàng', 'Dự án', 'Mô tả',
        'Ngày order', 'Ngày giao', 'Phân loại',
        'B1: Bốc VT', 'B2: Nhập VT', 'B3: Cắt - Đột', 'B4: Bào - Chấn',
        'B5: Ghép - Hàn', 'B6: Mài - H.T', 'B7: Nghiệm thu', 'B8: Sơn - Mạ',
        'B9: Nghiệm thu', 'B10: Đóng gói', 'B11: Giao hàng'
    ];

    $col = 'A';
    foreach ($headers as $header) {
        $sheet->setCellValue($col . $row, $header);
        $sheet->getStyle($col . $row)->getFont()->setBold(true);
        $sheet->getStyle($col . $row)->getAlignment()
            ->setHorizontal(Alignment::HORIZONTAL_CENTER)
            ->setVertical(Alignment::VERTICAL_CENTER);
        $sheet->getStyle($col . $row)->getFill()
            ->setFillType(Fill::FILL_SOLID)
            ->getStartColor()->setARGB('FFD3D3D3');
        $sheet->getStyle($col . $row)->getBorders()->getAllBorders()
            ->setBorderStyle(Border::BORDER_THIN);
        $col++;
    }

    $stageMapping = [
        'Bốc khối lượng - Đặt vật tư' => 'I', // ✅ QUAY LẠI I
        'Nhập vật tư: Thép, Inox, Kính, Phụ kiện,...' => 'J', // ✅ QUAY LẠI J
        'Thép/Inox/Kính' => 'J',
        'Cắt - Đột' => 'K',
        'Bào - Chấn' => 'L',
        'Ghép - Hàn' => 'M',
        'Mài - Hoàn thiện' => 'N',
        'Nghiệm thu trước sơn' => 'O',
        'Sơn/ Mạ' => 'P',
        'Nghiệm thu sau sơn' => 'Q',
        'Đóng gói' => 'R',
        'Giao hàng' => 'S', // ✅ QUAY LẠI S
    ];

    $row = 5;
    $stt = 1;
    $now = Carbon::now();
    $orderIndex = 0;
    foreach ($orders as $order) {
        $startRow = $row;

        // ✅ MÀU NỀN XEN KẼ
        $bgColor = ($orderIndex % 2 == 0) ? 'FFFFFFFF' : 'FFF9F9F9';

        // ✅ DÒNG 1: Thông tin cơ bản
        $sheet->setCellValue('A' . $row, $stt++);
        $sheet->setCellValue('B' . $row, $order->order_no);
        $sheet->setCellValue('C' . $row, $order->company_name ?? '');
        $sheet->setCellValue('D' . $row, $order->project_name);
        $sheet->setCellValue('E' . $row, $order->description ?? '');
        $sheet->setCellValue('F' . $row, $order->order_date ? $order->order_date->format('d/m/Y') : '');
        $sheet->setCellValue('G' . $row, $order->delivery_date ? $order->delivery_date->format('d/m/Y') : '');

       // ✅ CỘT H - DÒNG 1: LUÔ LUÔ HIỂN THỊ "Trạng thái"
        $sheet->setCellValue('H' . $row, 'Trạng thái');
        $sheet->getStyle('H' . $row)->getFont()->getColor()->setARGB('FF0000FF');



        // ✅ ĐIỀN CÔNG ĐOẠN - DÒNG 1: TRẠNG THÁI
        foreach ($order->stages as $stage) {
            $stageName = trim(preg_replace('/\(Bước[^)]*\)/iu', '', $stage->name));

            if (!isset($stageMapping[$stageName])) continue;

            $column = $stageMapping[$stageName];

            // Dịch trạng thái sang tiếng Việt
            $statusText = '';
            switch ($stage->status) {
                case 'pending':
                    $statusText = 'Chưa bắt đầu';
                    break;
                case 'in_progress':
                    $statusText = 'Đang làm';
                    break;
                case 'late':
                    $statusText = 'Trễ hạn';
                    break;
                case 'done':
                    $statusText = 'Hoàn thành';
                    break;
                default:
                    $statusText = $stage->status;
            }

            $sheet->setCellValue($column . $row, $statusText);
        }

        // ✅ TÔ MÀU NỀN DÒNG 1
        $sheet->getStyle('A' . $row . ':S' . $row)->getFill()
            ->setFillType(Fill::FILL_SOLID)
            ->getStartColor()->setARGB($bgColor);

        $row++; // XUỐNG DÒNG 2

        // Lấy thời gian còn lại từ backend
        $remainingText = '';
        if (!empty($order->remaining_days)) {
            $raw = $order->remaining_days;

            if (strpos($raw, '-') === 0) {
                $remainingText = "Trễ " . ltrim($raw, '-');
            } else {
                $remainingText = "Còn lại: " . $raw;
            }
        }

       // === DÒNG 2 ===
        // ✅ CỘT H - DÒNG 2
        $sheet->setCellValue('H' . $row, 'Kế hoạch');
        $sheet->getStyle('H' . $row)->getFont()->getColor()->setARGB('FFFF0000');

        // ✅ ĐIỀN CÔNG ĐOẠN - DÒNG 2: NGÀY KẾT THÚC
        foreach ($order->stages as $stage) {
            $stageName = trim(preg_replace('/\(Bước[^)]*\)/iu', '', $stage->name));

            if (!isset($stageMapping[$stageName])) continue;

            $column = $stageMapping[$stageName];

            $plannedEndText = '';
            if (!empty($stage->planned_end)) {
                $plannedEndText = Carbon::parse($stage->planned_end)->format('d/m/Y');
            }

            $sheet->setCellValue($column . $row, $plannedEndText);
        }

        // ✅ TÔ MÀU NỀN DÒNG 2
        $sheet->getStyle('A' . $row . ':S' . $row)->getFill()
            ->setFillType(Fill::FILL_SOLID)
            ->getStartColor()->setARGB($bgColor);

        $row++; // XUỐNG DÒNG 3

        // Phân loại - Dòng 3: "Còn lại"
        $sheet->setCellValue('H' . $row, 'Còn lại');
        $sheet->getStyle('H' . $row)->getFont()->getColor()->setARGB('FF800080');
        // ✅ ĐIỀN CÔNG ĐOẠN - DÒNG 3: THỜI GIAN CÒN LẠI/TRỄ
        foreach ($order->stages as $stage) {
            $stageName = trim(preg_replace('/\(Bước[^)]*\)/iu', '', $stage->name));

            if (!isset($stageMapping[$stageName])) continue;

            $column = $stageMapping[$stageName];

            $remainingStageText = '';
            $color = null;

            if ($stage->status === 'done') {
                $remainingStageText = '✓';
                $color = 'FF90EE90';
            } elseif (!empty($stage->planned_end)) {
                $plannedEnd = Carbon::parse($stage->planned_end);

                $diffInDays = $now->diffInDays($plannedEnd, false);
                $diffInHours = abs($now->diffInHours($plannedEnd) % 24);

                if ($diffInDays < 0) {
                    $remainingStageText = "Trễ " . abs($diffInDays) . " ngày {$diffInHours} giờ";
                    $color = 'FFFF6B6B';
                } else {
                    $remainingStageText = "Còn {$diffInDays} ngày {$diffInHours} giờ";
                    $color = 'FFEAF4FF';
                }
            } else {
                $remainingStageText = '-';
            }

            $sheet->setCellValue($column . $row, $remainingStageText);

            if ($color) {
                $sheet->getStyle($column . $row)->getFill()
                    ->setFillType(Fill::FILL_SOLID)
                    ->getStartColor()->setARGB($color);
            }
        }
         // ✅ TÔ MÀU NỀN CHO PHẦN CHƯA CÓ MÀU (A-G, chỉ khi không hoãn)
        if (!$order->is_paused) {
            for ($col = 'A'; $col <= 'G'; $col++) {
                $sheet->getStyle($col . $row)->getFill()
                    ->setFillType(Fill::FILL_SOLID)
                    ->getStartColor()->setARGB($bgColor);
            }
        }
        // MERGE F & G cho dòng 2-3
        if ($order->is_paused) {
        // ✅ HIỂN THỊ "🛑 HOÃN" Ở DÒNG 2
        $pauseText = "🛑 HOÃN";
        if ($order->pause_reason) {
            $pauseText .= "\n" . $order->pause_reason;
        }

        $sheet->setCellValue('F' . ($row - 1), $pauseText);
        $sheet->getStyle('F' . ($row - 1))->getFont()
            ->setBold(true)
            ->getColor()->setARGB('FFFF6600'); // Màu cam đậm
        $sheet->getStyle('F' . ($row - 1))->getFill()
            ->setFillType(Fill::FILL_SOLID)
            ->getStartColor()->setARGB('FFFFD9B3'); // Nền cam nhạt
        $sheet->getStyle('F' . ($row - 1))->getAlignment()
            ->setWrapText(true)
            ->setHorizontal(Alignment::HORIZONTAL_CENTER)
            ->setVertical(Alignment::VERTICAL_CENTER);
        } else {
            // ✅ HIỂN THỊ THỜI GIAN CÒN LẠI
            $remainingText = '';
            if (!empty($order->remaining_days)) {
                $raw = $order->remaining_days;
                if (strpos($raw, '-') === 0) {
                    $remainingText = "Trễ " . ltrim($raw, '-');
                } else {
                    $remainingText = "Còn lại: " . $raw;
                }
            }

            $sheet->setCellValue('F' . ($row - 1), $remainingText);
            $sheet->getStyle('F' . ($row - 1))->getAlignment()
                ->setHorizontal(Alignment::HORIZONTAL_CENTER)
                ->setVertical(Alignment::VERTICAL_CENTER);
        }
        $sheet->mergeCells('F' . ($row - 1) . ':G' . $row);

        $sheet->getStyle('F' . ($row - 1))->getAlignment()
            ->setHorizontal(Alignment::HORIZONTAL_CENTER)
            ->setVertical(Alignment::VERTICAL_CENTER);


        // Merge cells cho cột A-E (3 dòng)
        foreach (['A', 'B', 'C', 'D', 'E'] as $col) {
            $sheet->mergeCells($col . $startRow . ':' . $col . $row);

            if (in_array($col, ['A', 'B', 'C', 'D'])) {
                $sheet->getStyle($col . $startRow)->getAlignment()
                    ->setHorizontal(Alignment::HORIZONTAL_CENTER)
                    ->setVertical(Alignment::VERTICAL_CENTER);
            } else {
                $sheet->getStyle($col . $startRow)->getAlignment()
                    ->setVertical(Alignment::VERTICAL_TOP);
            }
        }

        // Border
        $sheet->getStyle('A' . $startRow . ':S' . $row)->getBorders()->getAllBorders()
            ->setBorderStyle(Border::BORDER_THIN);

        // ✅ VIỀN ĐẬM XUNG QUANH ĐƠN HÀNG
        $sheet->getStyle('A' . $startRow . ':S' . $row)->getBorders()->getAllBorders()
            ->setBorderStyle(Border::BORDER_THIN);

        $sheet->getStyle('A' . $startRow . ':S' . $row)->getBorders()->getOutline()
            ->setBorderStyle(Border::BORDER_MEDIUM)
            ->getColor()->setARGB('FF000000');

        $row++;

        // ✅ DÒNG PHÂN CÁCH (MÀU XÁM ĐẬM, CAO 5px)
        $sheet->getStyle('A' . $row . ':S' . $row)->getFill()
            ->setFillType(Fill::FILL_SOLID)
            ->getStartColor()->setARGB('FFDCDCDC');

        $sheet->getRowDimension($row)->setRowHeight(10);

        $row++;
        $orderIndex++;
    }

    // ✅ AUTO-SIZE CHO CỘT A-H (Thông tin đơn hàng)
    foreach (range('A', 'H') as $col) {
        $sheet->getColumnDimension($col)->setAutoSize(true);
    }

    // ✅ SET WIDTH CỐ ĐỊNH CHO CỘT I (Trạng thái hoãn)
    $sheet->getColumnDimension('I')->setWidth(20); // Rộng hơn để chứa lý do

    // ✅ SET WIDTH CỐ ĐỊNH CHO CỘT I-S (11 bước công đoạn)
    // Độ rộng tính theo ký tự Excel (1 unit ≈ 1 ký tự)
    $stageColumns =['I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S'];
    foreach ($stageColumns as $col) {
        $sheet->getColumnDimension($col)->setWidth(17); // ✅ ĐỔI SỐ NÀY ĐỂ ĐIỀU CHỈNH
    }

    // ✅ ĐỔI FONT CHỮ CHO TOÀN BỘ VÙNG DỮ LIỆU
    $highestRow = $sheet->getHighestRow();
    $sheet->getStyle('A1:S' . $highestRow)->getFont()->setName('Times New Roman')->setSize(11);
}

}

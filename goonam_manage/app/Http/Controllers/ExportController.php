<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Order;
use App\Exports\OrderExport;
use Maatwebsite\Excel\Facades\Excel;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use PhpOffice\PhpSpreadsheet\Style\Protection;

class ExportController extends Controller
{
    public function exportExcel(Request $request, Order $order)
    {
        if (!in_array($request->user()->role, ['admin', 'director', 'manager'])) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        return Excel::download(new OrderExport($order), "order_{$order->order_no}.xlsx");
    }

    // 🧮 Hàm xuất thống kê theo tháng
    public function exportStatistics(Request $request)
    {
        if (!in_array($request->user()->role, ['admin', 'director', 'manager'])) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        $monthList = [];

        // 🧩 Trường hợp 1: start_month + months (số tháng liên tiếp)
        if ($request->filled('start_month') && is_numeric($request->query('months'))) {
            $startMonth = $request->query('start_month');
            $monthCount = (int) $request->query('months');
            try {
                $start = \Carbon\Carbon::createFromFormat('Y-m', $startMonth)->startOfMonth();
                for ($i = 0; $i < $monthCount; $i++) {
                    $monthList[] = $start->copy()->addMonths($i)->format('Y-m');
                }
            } catch (\Exception $e) {
                return response()->json(['error' => 'Sai định dạng tháng bắt đầu'], 422);
            }
        } else {
            // 🧩 Trường hợp 2: chọn nhiều tháng bất kỳ
            $monthsParam = $request->query('months');
            if (is_array($monthsParam)) {
                $monthList = $monthsParam;
            } elseif (is_string($monthsParam)) {
                $monthList = explode(',', $monthsParam);
            }
        }

        // 🔍 Loại bỏ trùng và khoảng trắng
        $monthList = array_values(array_filter(array_unique(array_map('trim', $monthList))));

        if (empty($monthList)) {
            return response()->json(['error' => 'Vui lòng chọn ít nhất 1 tháng'], 422);
        }

        // ================== Xử lý tạo file Excel =====================
        $spreadsheet = new Spreadsheet();
        $sheetIndex = 0;

        foreach ($monthList as $month) {
            try {
                $monthDate = \Carbon\Carbon::createFromFormat('Y-m', $month);
            } catch (\Exception $e) {
                continue;
            }

            $monthName = $monthDate->format('m-Y');
            $sheet = $sheetIndex === 0 ? $spreadsheet->getActiveSheet() : $spreadsheet->createSheet();
            $sheet->setTitle("Tháng $monthName");
            $sheetIndex++;

            // ====================== Bảo vệ worksheet ngay khi tạo =====================
            $sheet->getProtection()->setPassword('2003@Goonam');  // Đặt mật khẩu bảo vệ
            $sheet->getProtection()->setSheet(true);  // Bảo vệ sheet, không cho chỉnh sửa
            $sheet->getProtection()->setSort(false); // Không cho phép sắp xếp lại dữ liệu
            $sheet->getProtection()->setInsertRows(false); // Không cho phép thêm hàng mới
            $sheet->getProtection()->setDeleteRows(false); // Không cho phép xóa hàng

            // Khóa tất cả các ô trong phạm vi
            $sheet->getStyle('A1:Z1000')->getProtection()->setLocked(\PhpOffice\PhpSpreadsheet\Style\Protection::PROTECTION_PROTECTED);


            $orders = Order::with('stages') // 🟢 load công đoạn để có delay_reason & delay_reason_history
                ->whereIn('status', ['done', 'completed', 'completed_late', 'completed_early'])
                ->whereMonth('actual_end', $monthDate->month)
                ->whereYear('actual_end', $monthDate->year)

                // xử lý mỗi 100 đơn 1 lần

                ->get();

            if ($orders->isEmpty()) {
                $sheet->setCellValue('A1', "❌ Không có đơn hàng hoàn thành trong tháng $monthName");
                continue;
            }

            // === Tổng hợp 3 loại: Trước hẹn / Đúng hạn / Trễ ===
            $total = $orders->count();

            $early = $orders->filter(function ($o) {
                if (!$o->actual_end) return false;
                $compareDate = $o->original_delivery_date ?: $o->delivery_date;
                if (!$compareDate) return false;
                return $o->actual_end->lt($compareDate->copy()->subDay()->endOfDay());
            })->count();

            $onTime = $orders->filter(function ($o) {
                if (!$o->actual_end) return false;
                $compareDate = $o->original_delivery_date ?: $o->delivery_date;
                if (!$compareDate) return false;
                return !$o->actual_end->lt($compareDate->copy()->subDay()->endOfDay())
                    && $o->actual_end->lessThanOrEqualTo($compareDate->copy()->endOfDay());
            })->count();

            $late = $orders->count() - $onTime - $early;

            // === 🌈 Header tổng hợp ===
            $sheet->mergeCells('A1:G1');
            $sheet->setCellValue('A1', "📊 Thống kê đơn hàng tháng $monthName");
            $sheet->getStyle('A1')->getFont()->setBold(true)->setSize(14);
            $sheet->getStyle('A1')->getAlignment()->setHorizontal('center');

            // ====================== Bảo vệ worksheet =====================



            // === Bảng tổng hợp ===
            $sheet->fromArray(
                [['Tháng', 'Tổng đơn', 'Trước hẹn (SL & %)', 'Đúng hạn (SL & %)', 'Trễ hạn (SL & %)']],
                null,
                'A3'
            );

            $sheet->fromArray(
                [[$monthName, $total,
                    "$early (" . ($total ? round($early / $total * 100, 1) : 0) . "%)",
                    "$onTime (" . ($total ? round($onTime / $total * 100, 1) : 0) . "%)",
                    "$late (" . ($total ? round($late / $total * 100, 1) : 0) . "%)"
                ]],
                null,
                'A4'
            );

            $sheet->getStyle('A3:E3')->getFont()->setBold(true);
            $sheet->getStyle('A3:E4')->getAlignment()->setHorizontal('center');
            $sheet->getStyle('A3:E4')->getBorders()->getAllBorders()
                ->setBorderStyle(\PhpOffice\PhpSpreadsheet\Style\Border::BORDER_THIN);

            // === Header chi tiết ===
            $sheet->setCellValue('A6', '');
            $sheet->fromArray(
                [['Mã đơn', 'Công ty', 'Dự án', 'Ngày giao', 'Ngày hoàn thành', 'Phân loại', 'Trễ hạn (ngày)', 'Công đoạn trễ & lý do', 'Lịch sử chỉnh sửa', '🧩 Admin chỉnh sửa']],
                null,
                'A7'
            );


            $sheet->getStyle('A7:I7')->getFont()->setBold(true);
            $sheet->getStyle('A7:I7')->getFill()
                ->setFillType(\PhpOffice\PhpSpreadsheet\Style\Fill::FILL_SOLID)
                ->getStartColor()->setARGB('FFDDDDDD');
            $sheet->getStyle('A7:I7')->getAlignment()->setHorizontal('center');




            // === Dòng dữ liệu ===
$row = 8;
foreach ($orders as $o) {
    $sheet->setCellValue("A$row", $o->order_no);
    $sheet->setCellValue("B$row", $o->company_name);
    $sheet->setCellValue("C$row", $o->project_name);
    $sheet->setCellValue("D$row", optional($o->delivery_date)?->format('d/m/Y'));
    $sheet->setCellValue("E$row", optional($o->actual_end)?->format('d/m/Y'));
    // 🟣 Lấy ngày yêu cầu vật tư (nếu có ít nhất 1 công đoạn có)
    $materialDate = collect($o->stages)
        ->filter(fn($s) => !empty($s->material_request_date))
        ->min(fn($s) => $s->material_request_date); // Lấy công đoạn có ngày nhỏ nhất

    // $sheet->setCellValue("F$row", $materialDate ? \Carbon\Carbon::parse($materialDate)->format('d/m/Y') : '-');
    $compareDate = $o->original_delivery_date ?: $o->delivery_date;

    // ✅ Xác định trạng thái
    if ($o->actual_end && $compareDate) {
        if ($o->actual_end->lt($compareDate->copy()->subDay()->endOfDay())) {
            $status = 'Trước hẹn (so với kế hoạch gốc)';
        } elseif ($o->actual_end->lessThanOrEqualTo($compareDate->copy()->endOfDay())) {
            $status = 'Đúng hạn (so với kế hoạch gốc)';
        } else {
            $status = 'Trễ (so với kế hoạch gốc)';
        }
    } else {
        $status = 'Không xác định';
    }

    // ✅ Tính số ngày trễ
    $daysLate = '';
    if ($o->actual_end && $compareDate && $o->actual_end->gt($compareDate)) {
        $daysLate = $o->actual_end->diffInDays($compareDate);
    }


    // ✅ Gom thông tin công đoạn trễ (SO SÁNH VỚI THỜI GIAN GỐC - CHỈ THEO NGÀY)
    $delayDetails = '';
    $delays = collect($o->stages)->filter(function ($s) {
        // ✅ So sánh actual_end với original_planned_end (thời gian gốc)
        if ($s->status === 'done' && $s->actual_end) {
            $deadline = $s->original_planned_end ?? $s->planned_end;

            if ($deadline) {
                $deadlineCarbon = \Carbon\Carbon::parse($deadline)->startOfDay();
                $actualEndCarbon = \Carbon\Carbon::parse($s->actual_end)->startOfDay();

                // ✅ Chỉ tính trễ nếu hoàn thành SAU ngày deadline (không tính giờ)
                // VÍ DỤ:
                // - deadline: 03/12/2025, actual_end: 03/12/2025 → KHÔNG TRỄ ✅
                // - deadline: 03/12/2025, actual_end: 04/12/2025 → TRỄ ❌
                if ($actualEndCarbon->gt($deadlineCarbon)) {
                    return true;
                }
            }
        }

        // ✅ Hoặc nếu có ghi nhận lý do trễ (và không phải "Chưa nhập lý do")
        if ((!empty($s->delay_reason) && $s->delay_reason !== 'Chưa nhập lý do')
            || !empty($s->delay_reason_history)) {
            return true;
        }

        return false;
    });

    if ($delays->isNotEmpty()) {
    $delayDetails = $delays->map(function ($s) {
        // ✅ Tính số ngày trễ so với kế hoạch gốc (CHỈ THEO NGÀY)
        $lateDays = '';
        if ($s->status === 'done' && $s->actual_end) {
            $deadline = $s->original_planned_end ?? $s->planned_end;
            if ($deadline) {
                $deadlineCarbon = \Carbon\Carbon::parse($deadline)->startOfDay();
                $actualEndCarbon = \Carbon\Carbon::parse($s->actual_end)->startOfDay();

                // ✅ Chỉ tính trễ nếu thực sự qua ngày deadline
                if ($actualEndCarbon->gt($deadlineCarbon)) {
                    $days = $actualEndCarbon->diffInDays($deadlineCarbon);
                    $lateDays = " (Trễ $days ngày so với kế hoạch gốc)";
                }
            }
        }

        // ✅ Hiển thị lý do trễ
        if (!empty($s->delay_reason_history)) {
            $reasons = collect($s->delay_reason_history)
                ->map(fn($r) => "  + {$r['reason']} ({$r['date']})")
                ->join("\n");
            return "- {$s->name}{$lateDays}:\n{$reasons}";
        }

        $reason = $s->delay_reason ?: 'Chưa nhập lý do';
        return "- {$s->name}{$lateDays}: {$reason}";
    })->join("\n");
} else {
    $delayDetails = 'Không có công đoạn trễ';
}

    // 🕓 Lịch sử chỉnh sửa
$historySummary = '';
$hasAdminEdit = false; // 🔹 Cờ kiểm tra có chỉnh sửa admin hay không

if (!empty($o->history)) {
    $filteredHistory = collect($o->history)->filter(function ($h) {
        $text = $h['change'] ?? '';
        return str_contains($text, 'Cập nhật thời gian công đoạn')
            || str_contains($text, 'Gia hạn công đoạn')
            || str_contains($text, 'Cập nhật lý do trễ')
            || str_contains($text, 'ngày giao hàng')
            || str_contains($text, 'Admin chỉnh'); // thêm điều kiện này
    });

    $historySummary = $filteredHistory->map(function ($h) use (&$hasAdminEdit) {
        $editor = $h['editor'] ?? 'Không rõ';
        $date = isset($h['date']) ? \Carbon\Carbon::parse($h['date'])->format('d/m/Y H:i') : '';
        $change = $h['change'] ?? '';
        $mode = $h['change_mode'] ?? '';
        $note = !empty($h['note']) ? "🗒 Ghi chú: {$h['note']}" : '';

        if ($mode === 'admin_edit') {
            $hasAdminEdit = true; // 🔹 Ghi nhận có chỉnh sửa admin
            return "🧩 {$editor} ({$date}) [Admin chỉnh sửa]: {$change}" . ($note ? "\n{$note}" : '');
        } else {
            return "{$editor} ({$date}): {$change}" . ($note ? "\n{$note}" : '');
        }
    })->join("\n");
} else {
    $historySummary = 'Không có lịch sử';
}
$adminEditLogs = [];
if (!empty($o->history)) {
    // 🧩 Lọc log admin_edit, bỏ log công đoạn, chỉ giữ log có nội dung thực sự
    $logs = collect($o->history)
        ->filter(function ($h) {
            if (($h['change_mode'] ?? '') !== 'admin_edit') return false;

            $note = trim($h['note'] ?? '');
            $change = $h['change'] ?? '';

            // ❌ Bỏ log dạng “Admin chỉnh thời gian công đoạn…” và tương tự
            $isStageChange = str_contains($change, 'Admin chỉnh thời gian công đoạn')
                || str_contains($change, 'Cập nhật thời gian công đoạn')
                || str_contains($note, 'Admin chỉnh thời gian công đoạn')
                || str_contains($note, 'Cập nhật công đoạn')
                || str_contains($note, 'Gia hạn công đoạn');

            // ✅ Giữ lại nếu KHÔNG phải mấy log tự động kia
            return !$isStageChange;
        })
        ->sortByDesc('date')
        ->values();

    if ($logs->isNotEmpty()) {
        $hasAdminEdit = true;
        $latest = $logs->first(); // Lấy log admin mới nhất

        $editor = $latest['editor'] ?? 'Không rõ';
        $date = isset($latest['date']) ? \Carbon\Carbon::parse($latest['date'])->format('d/m/Y H:i') : '';

        // Lấy nội dung thực tế
        $note = trim($latest['note'] ?? '');
        if (empty($note) && !empty($latest['change'])) $note = $latest['change'];
        if (empty($note) && !empty($latest['details']['note'] ?? '')) $note = $latest['details']['note'];

        $adminEditLogs[] = "✅ {$editor} ({$date})" . ($note ? " 🗒 {$note}" : '');
    }
}



    // 🎨 Màu nền
    switch (true) {
        case str_contains($status, 'Trước hẹn'):
            $color = 'FFCCE5FF';
            break;
        case str_contains($status, 'Đúng hạn'):
            $color = 'FFB7E1CD';
            break;
        case str_contains($status, 'Trễ'):
            $color = 'FFF4CCCC';
            break;
        default:
            $color = 'FFFFFFFF';
    }if ($hasAdminEdit) {
    $color = 'FFFFE599'; // Màu vàng nhạt dễ nhìn
}

    $sheet->getStyle("A$row:I$row")->getFill()
        ->setFillType(\PhpOffice\PhpSpreadsheet\Style\Fill::FILL_SOLID)
        ->getStartColor()->setARGB($color);

    // ✅ Ghi dữ liệu
   $sheet->setCellValue("F$row", $status);
    $sheet->setCellValue("G$row", $daysLate ?: '-');
    $sheet->setCellValue("H$row", $delayDetails);
    $sheet->setCellValue("I$row", $historySummary);
    // 🧩 Gộp dữ liệu cũ nếu ô này đã có log
    // 🧩 Gộp dữ liệu cũ nếu ô này đã có log
    $existingCellValue = $sheet->getCell("J$row")->getValue();

    // ✅ Lấy log từ cột admin_edit_logs trong DB (ưu tiên dữ liệu mới)
    $adminEditLogs = [];
    if (!empty($o->admin_edit_logs) && is_array($o->admin_edit_logs)) {
        foreach ($o->admin_edit_logs as $log) {
            $editor = $log['editor'] ?? 'Không rõ';
            $date = isset($log['date']) ? \Carbon\Carbon::parse($log['date'])->format('d/m/Y H:i') : '';
            $note = $log['note'] ?? '(Không có ghi chú)';
            $adminEditLogs[] = "✅ {$editor} ({$date}) 🗒 {$note}";
        }
    }

    if (!empty($adminEditLogs)) {
        // 🔹 Ghép log mới + log cũ trong Excel (nếu có)
        $newLogs = implode("\n", $adminEditLogs);
        if (!empty($existingCellValue) && $existingCellValue !== "-") {
            $sheet->setCellValue("J$row", trim($existingCellValue . "\n" . $newLogs));
        } else {
            $sheet->setCellValue("J$row", $newLogs);
        }
    } else {
        // 🔹 Nếu không có log admin thì hiển thị dấu gạch ngang
        $sheet->setCellValue("J$row", !empty($existingCellValue) ? $existingCellValue : "-");
    }




    // ✅ Căn chỉnh hiển thị đẹp
    $sheet->getStyle("J$row")->getAlignment()->setWrapText(true);
    $sheet->getStyle("H$row:I$row")->getAlignment()->setWrapText(true);

    $sheet->getStyle("J$row")->getAlignment()->setWrapText(true);
    $sheet->getStyle("H$row:I$row")->getAlignment()->setWrapText(true);

    $row++;
}

            // === Kẻ viền toàn bảng ===
$sheet->getStyle("A7:K" . ($row - 1))
    ->getBorders()->getAllBorders()
    ->setBorderStyle(\PhpOffice\PhpSpreadsheet\Style\Border::BORDER_THIN);

// === Tự động giãn cột ===
foreach (range('A', 'J') as $col) {
    $sheet->getColumnDimension($col)->setAutoSize(true);
}

// === Căn chỉnh ===
$sheet->getStyle("D8:G" . ($row - 1))->getAlignment()->setHorizontal('center');
$sheet->getStyle("H8:I" . ($row - 1))->getAlignment()->setVertical('top');
        }

        // === Xuất file ===
        $fileName = "Thong_ke_don_hang_" . now()->format('Y_m_d_His') . ".xlsx";
        $writer = new Xlsx($spreadsheet);
        $tempPath = storage_path("app/temp/$fileName");

        if (!file_exists(storage_path('app/temp'))) {
            mkdir(storage_path('app/temp'), 0777, true);
        }

        $writer->save($tempPath);
        return response()->download($tempPath, $fileName)->deleteFileAfterSend(true);
    }
}

<?php

namespace App\Exports;

use App\Models\Order;
use Illuminate\Contracts\View\View;
use Maatwebsite\Excel\Concerns\FromView;
use Maatwebsite\Excel\Concerns\WithStyles;
use Maatwebsite\Excel\Concerns\WithColumnWidths;
use Maatwebsite\Excel\Concerns\ShouldAutoSize;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;
use PhpOffice\PhpSpreadsheet\Style\Protection;
class OrderExport implements FromView, WithStyles, WithColumnWidths, ShouldAutoSize
{
    protected $order;

    public function __construct(Order $order)
    {
        $this->order = $order->load(['stages']);
    }

    public function view(): View
    {
        return view('exports.order', [
            'order' => $this->order,
        ]);
    }

    private function colToIndex(string $col): int
    {
        $col = strtoupper($col);
        $len = strlen($col);
        $num = 0;
        for ($i = 0; $i < $len; $i++) {
            $num = $num * 26 + (ord($col[$i]) - 64);
        }
        return $num;
    }

    private function indexToCol(int $idx): string
    {
        $str = '';
        while ($idx > 0) {
            $rem = ($idx - 1) % 26;
            $str = chr(65 + $rem) . $str;
            $idx = intdiv($idx - 1, 26);
        }
        return $str;
    }

    private function findStartCol(Worksheet $sheet, int $headerRow, array $candidates = ['STT']): int
    {
        for ($c = 1; $c <= 52; $c++) {
            $letter = $this->indexToCol($c);
            $val = trim((string)$sheet->getCell("{$letter}{$headerRow}")->getValue());
            if ($val !== '') {
                foreach ($candidates as $cand) {
                    if (mb_strtoupper($val) === mb_strtoupper($cand)) {
                        return $c;
                    }
                }
            }
        }
        return 1;
    }

   public function styles(Worksheet $sheet)
{
    /* ====== BẢNG CÔNG ĐOẠN ====== */
    $stageTitleRow  = 1;
    $stageHeaderRow = 2;
    $stageDataStart = 3;
    $stageCount     = count($this->order->stages);
    $stageDataEnd   = $stageDataStart + max($stageCount, 1) - 1;

    $startColIndex = $this->findStartCol($sheet, $stageHeaderRow, ['STT']);
    $A = $this->indexToCol($startColIndex + 0);
    $B = $this->indexToCol($startColIndex + 1);
    $C = $this->indexToCol($startColIndex + 2);
    $D = $this->indexToCol($startColIndex + 3);
    $E = $this->indexToCol($startColIndex + 4);
    $F = $this->indexToCol($startColIndex + 5);

    // Tiêu đề
    $sheet->mergeCells("{$A}{$stageTitleRow}:{$F}{$stageTitleRow}");
    $sheet->getStyle("{$A}{$stageTitleRow}:{$F}{$stageTitleRow}")->applyFromArray([
        'font' => ['bold' => true, 'size' => 14],
        'alignment' => [
            'horizontal' => Alignment::HORIZONTAL_CENTER,
            'vertical'   => Alignment::VERTICAL_CENTER,
        ],
    ]);

    // Header công đoạn
    $sheet->getStyle("{$A}{$stageHeaderRow}:{$F}{$stageHeaderRow}")->applyFromArray([
        'font' => ['bold' => true],
        'alignment' => [
            'horizontal' => Alignment::HORIZONTAL_CENTER,
            'vertical'   => Alignment::VERTICAL_CENTER,
        ],
        'borders' => ['allBorders' => ['borderStyle' => Border::BORDER_THIN]],
    ]);

    // Viền + format data công đoạn
    $sheet->getStyle("{$A}{$stageHeaderRow}:{$F}{$stageDataEnd}")->applyFromArray([
        'borders' => ['allBorders' => ['borderStyle' => Border::BORDER_THIN]],
    ]);
    $sheet->getStyle("{$A}{$stageDataStart}:{$A}{$stageDataEnd}")
          ->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);
    $sheet->getStyle("{$F}{$stageDataStart}:{$F}{$stageDataEnd}")
          ->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);
    $sheet->getStyle("{$C}{$stageDataStart}:{$E}{$stageDataEnd}")
          ->getNumberFormat()->setFormatCode('dd/mm/yyyy');

    /* ====== BẢNG LỊCH SỬ ====== */
    // 👉 KHÔNG cộng +3 nữa, chỉ cần +2 (một hàng trống ngăn cách là đủ)
    $historyTitleRow  = $stageDataEnd + 4;
    $historyHeaderRow = $historyTitleRow + 1;
    $historyDataStart = $historyHeaderRow + 1;

    $history = $this->order->history ?? [];
    if (is_string($history)) {
        $history = json_decode($history, true) ?: [];
    }

    // 🧹 Lọc chỉ giữ các log có từ khóa liên quan ngày & lý do
    $history = collect($history)->filter(function ($h) {
        $text = $h['change'] ?? '';
        return str_contains($text, 'Cập nhật thời gian công đoạn')
            || str_contains($text, 'Gia hạn công đoạn')
            || str_contains($text, 'Cập nhật lý do trễ')
            || str_contains($text, 'ngày giao hàng');
    })->values()->all();

    $historyCount   = count($history);
    $historyDataEnd = $historyDataStart + max($historyCount, 1) - 1;

    // Merge + tiêu đề
    $sheet->mergeCells("{$A}{$historyTitleRow}:{$C}{$historyTitleRow}");
    $sheet->setCellValue("{$A}{$historyTitleRow}", "LỊCH SỬ CHỈNH SỬA ĐƠN HÀNG");
    $sheet->getStyle("{$A}{$historyTitleRow}:{$C}{$historyTitleRow}")->applyFromArray([
        'font' => ['bold' => true, 'size' => 13],
        'alignment' => [
            'horizontal' => Alignment::HORIZONTAL_CENTER,
            'vertical'   => Alignment::VERTICAL_CENTER,
        ],
    ]);

    // Header lịch sử
    $sheet->getStyle("{$A}{$historyHeaderRow}:{$C}{$historyHeaderRow}")->applyFromArray([
        'font' => ['bold' => true],
        'alignment' => [
            'horizontal' => Alignment::HORIZONTAL_CENTER,
            'vertical'   => Alignment::VERTICAL_CENTER,
        ],
        'borders' => ['allBorders' => ['borderStyle' => Border::BORDER_THIN]],
    ]);

    // Dữ liệu lịch sử
    $sheet->getStyle("{$A}{$historyDataStart}:{$C}{$historyDataEnd}")->applyFromArray([
        'borders' => ['allBorders' => ['borderStyle' => Border::BORDER_THIN]],
    ]);
    $sheet->getStyle("{$A}{$historyDataStart}:{$A}{$historyDataEnd}")
          ->getAlignment()->setVertical(Alignment::VERTICAL_CENTER);
    $sheet->getStyle("{$B}{$historyDataStart}:{$B}{$historyDataEnd}")
          ->getAlignment()->setVertical(Alignment::VERTICAL_CENTER);
    $sheet->getStyle("{$C}{$historyDataStart}:{$C}{$historyDataEnd}")
          ->getAlignment()->setVertical(Alignment::VERTICAL_TOP)
          ->setWrapText(true);

    // Bảo vệ toàn bộ sheet để không thể chỉnh sửa
    $sheet->getProtection()->setPassword('2003@Goonam'); // Đặt mật khẩu ở đây
    $sheet->getProtection()->setSheet(true); // Bảo vệ toàn bộ sheet
    $sheet->getProtection()->setSort(false); // Cấm sắp xếp
    $sheet->getProtection()->setInsertRows(false); // Cấm thêm hàng
    $sheet->getProtection()->setDeleteRows(false); // Cấm xóa hàng
    $sheet->getProtection()->setFormatCells(false); // Cấm thay đổi định dạng ô

    // Kích thước cột hợp lý hơn
    $sheet->getColumnDimension("A")->setWidth(20);
    $sheet->getColumnDimension("B")->setWidth(40);
    $sheet->getColumnDimension("C")->setWidth(20);

    // Auto fit chiều cao
    foreach (range($historyTitleRow, $historyDataEnd) as $row) {
        $sheet->getRowDimension($row)->setRowHeight(-1);
    }

    /* ====== TỔNG ====== */
    $lastRow = max($stageDataEnd, $historyDataEnd);
    $sheet->getStyle("{$A}1:{$F}{$lastRow}")
          ->getAlignment()->setVertical(Alignment::VERTICAL_CENTER);

    $sheet->getPageSetup()->setOrientation(
        \PhpOffice\PhpSpreadsheet\Worksheet\PageSetup::ORIENTATION_LANDSCAPE
    );

    return [];
}


    public function columnWidths(): array
    {
        return [
            'A' => 8,
            'B' => 25,
            'C' => 22,
            'D' => 22,
            'E' => 22,
            'F' => 18,
        ];
    }
}

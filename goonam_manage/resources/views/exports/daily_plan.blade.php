<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <title>Kế hoạch ngày {{ $date }}</title>
    <style>
        body {
            font-family: 'DejaVu Sans', sans-serif;
            font-size: 11px;
            margin: 10px;
        }
        h2 {
            text-align: center;
            margin-bottom: 5px;
            text-transform: uppercase;
            font-size: 16px;
        }
        .summary {
            text-align: center;
            font-weight: bold;
            margin-bottom: 15px;
            font-size: 12px;
        }
        h3 {
            margin-top: 15px;
            margin-bottom: 5px;
            text-decoration: underline;
            font-size: 13px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 15px;
        }
        th, td {
            border: 1px solid #000;
            padding: 4px;
            text-align: left;
        }
        th {
            background: #e0e0e0;
            text-align: center;
            font-size: 10px;
        }
        td {
            vertical-align: middle;
            font-size: 10px;
        }

        .late-heavy { color: #b30000; font-weight: bold; }
        .late-medium { color: #ff6600; font-weight: bold; }
        .late-light { color: #cc0000; font-weight: bold; }
        .ontime { color: green; font-weight: bold; }
        .soon { color: #007bff; font-weight: bold; }

        .report-info {
            text-align: right;
            font-size: 10px;
            margin-bottom: 5px;
            color: #666;
        }

        .col-desc {
            max-width: 120px;
            word-wrap: break-word;
        }

        .text-center { text-align: center; }
        .skipped-row {
            background: #f5f5f5;
            color: #999;
            font-style: italic;
        }
    </style>
</head>
<body>
    <div class="report-info">
        Ngày xuất: {{ \Carbon\Carbon::now()->format('d/m/Y H:i') }}
    </div>

    <h2>KẾ HOẠCH SẢN XUẤT NGÀY {{ $date }}</h2>
    <div class="summary">
        Tổng công đoạn: {{ $totalStages }} | Tổng đơn hàng: {{ $totalOrders }}
    </div>

    @foreach ($stages as $stageName => $orders)
        <h3>{{ $stageName }}</h3>
        <table>
            <thead>
                <tr>
                    <th style="width:4%;">STT</th>
                    <th style="width:10%;">Mã đơn</th>
                    <th style="width:18%;">Tên dự án</th>
                    <th style="width:14%;">Khách hàng</th>
                    <th style="width:16%;">Mô tả</th>
                    <th style="width:12%;">Thời gian</th>
                    <th style="width:10%;">Trạng thái</th>
                    <th style="width:12%;">Tiến độ</th>
                    <th style="width:4%;">✓</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($orders as $i => $o)
                    @php
                        $now = \Carbon\Carbon::now();
                        $plannedEnd = null;
                        $diffDays = 0;

                        try {
                            if (!empty($o->planned_end) && $o->planned_end !== '0') {
                                $plannedEnd = \Carbon\Carbon::parse($o->planned_end);
                                $diffDays = $plannedEnd->diffInDays($now, false);
                            }
                        } catch (\Exception $e) {
                            $plannedEnd = null;
                            $diffDays = 0;
                        }

                        $progressText = '';
                        $progressClass = '';

                        if ($o->status === 'done') {
                            $progressText = 'Hoàn thành';
                            $progressClass = 'ontime';
                        } elseif ($diffDays < 0) {
                            $progressText = 'Còn ' . abs($diffDays) . ' ngày';
                            $progressClass = 'soon';
                        } elseif ($diffDays === 0) {
                            $progressText = 'Hôm nay hết hạn';
                            $progressClass = 'ontime';
                        } else {
                            if ($diffDays > 10) {
                                $progressClass = 'late-heavy';
                            } elseif ($diffDays > 5) {
                                $progressClass = 'late-medium';
                            } else {
                                $progressClass = 'late-light';
                            }
                            $progressText = 'Trễ ' . $diffDays . ' ngày';
                        }

                        $isSkipped = (!empty($o->is_skipped) && $o->is_skipped)
                            || (empty($o->planned_start) && empty($o->planned_end));
                    @endphp

                    @if($isSkipped)
                        <tr class="skipped-row">
                            <td class="text-center">{{ $i + 1 }}</td>
                            <td>{{ $o->order_no ?? '-' }}</td>
                            <td colspan="7" class="text-center">
                                Công đoạn bỏ qua (0 ngày)
                            </td>
                        </tr>
                        @continue
                    @endif

                    <tr>
                        <td class="text-center">{{ $i + 1 }}</td>
                        <td>{{ $o->order_no ?? '-' }}</td>
                        <td>{{ $o->project_name ?? '-' }}</td>
                        <td>{{ $o->company_name ?? '-' }}</td>
                        <td class="col-desc">{{ $o->description ?? '-' }}</td>
                        <td class="text-center">
                            @php
                                $start = null;
                                $end = null;

                                try {
                                    if (!empty($o->planned_start) && $o->planned_start !== '0') {
                                        $start = \Carbon\Carbon::parse($o->planned_start)->format('d/m');
                                    }
                                } catch (\Exception $e) {}

                                try {
                                    if (!empty($o->planned_end) && $o->planned_end !== '0') {
                                        $end = \Carbon\Carbon::parse($o->planned_end)->format('d/m');
                                    }
                                } catch (\Exception $e) {}
                            @endphp

                            @if ($start && $end)
                                {{ $start }} - {{ $end }}
                            @elseif (!$start && $end)
                                - {{ $end }}
                            @elseif ($start && !$end)
                                {{ $start }} -
                            @else
                                Chưa có lịch
                            @endif
                        </td>
                        <td class="text-center">
                            @php
                                $statusText = 'Chưa rõ';
                                switch (strtolower($o->status ?? '')) {
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
                                        $statusText = ucfirst($o->status ?? 'N/A');
                                }
                            @endphp
                            {{ $statusText }}
                        </td>
                        <td class="{{ $progressClass }} text-center">
                            {{ $progressText }}
                        </td>
                        <td class="text-center">
                            @if (strtolower($o->status ?? '') === 'done')
                                [X]
                            @else
                                [ ]
                            @endif
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    @endforeach
</body>
</html>

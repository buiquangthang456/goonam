{{-- ======= BẢNG CÔNG ĐOẠN ======= --}}
<table>
    <thead>
        {{-- 🔹 Title bảng công đoạn --}}
        <tr>
            <th colspan="6">BÁO CÁO TIẾN ĐỘ ĐƠN HÀNG</th>
        </tr>
        {{-- 🔹 Header --}}
        <tr>
            <th>STT</th>
            <th>Công đoạn</th>
            <th>Yêu cầu vật tư</th> {{-- 🟢 thêm dòng này --}}
            <th>Bắt đầu dự kiến</th>
            <th>Kết thúc dự kiến</th>
            <th>Hoàn thành thực tế</th>
            <th>Tình trạng</th>
        </tr>
    </thead>
    <tbody>
        @foreach($order->stages as $stage)
            <tr>
                <td>{{ $loop->iteration }}</td>
                <td>{{ $stage->name }}</td>
                <td>
                    @if($stage->sequence == 1)
                        {{ $stage->material_request_date
                            ? \Carbon\Carbon::parse($stage->material_request_date)->format('d/m/Y')
                            : '' }}
                    @endif
                </td> {{-- 🟢 cột Yêu cầu vật tư --}}
                <td>{{ $stage->planned_start ? \Carbon\Carbon::parse($stage->planned_start)->format('d/m/Y') : '' }}</td>
                <td>{{ $stage->planned_end ? \Carbon\Carbon::parse($stage->planned_end)->format('d/m/Y') : '' }}</td>
                <td>{{ $stage->actual_end ? \Carbon\Carbon::parse($stage->actual_end)->format('d/m/Y H:i') : '' }}</td>
                <td>
                    @if($stage->status === 'done') ✅ Hoàn thành
                    @elseif($stage->status === 'late') ❌ Trễ
                    @else ⏳ {{ ucfirst($stage->status) }}
                    @endif
                </td>
            </tr>
        @endforeach
    </tbody>
</table>

{{-- Tách rõ 2 bảng --}}
<br><br><br>


{{-- ======= BẢNG LỊCH SỬ ======= --}}
<table>
  <thead>
    {{-- ❌ BỎ dòng tiêu đề này đi, vì OrderExport đã setCellValue rồi --}}
    {{-- <tr><th colspan="3">LỊCH SỬ CHỈNH SỬA ĐƠN HÀNG</th></tr> --}}

    <tr>
      <th>Người chỉnh sửa</th>
      <th>Thời gian</th>
      <th>Nội dung thay đổi</th>
    </tr>
  </thead>

  <tbody>
    @php
        $history = $order->history ?? [];
        if (is_string($history)) $history = json_decode($history, true) ?: [];

        // Lọc chỉ những thay đổi liên quan đến ngày/lý do
        $filtered = collect($history)->filter(function($h) {
            return str_contains($h['change'] ?? '', 'ngày')
                || str_contains($h['change'] ?? '', 'gia hạn')
                || str_contains($h['change'] ?? '', 'lý do trễ')
                || str_contains($h['change'] ?? '', 'delivery_date');
        });
    @endphp

    @forelse($filtered as $h)
    <tr>
        <td>{{ $h['editor'] ?? 'Không rõ' }}</td>
        <td>{{ !empty($h['date']) ? \Carbon\Carbon::parse($h['date'])->format('d/m/Y H:i') : '' }}</td>
        <td>{{ $h['change'] ?? '' }}</td>
    </tr>
    @empty
        <tr>
            <td colspan="3" style="text-align:center;">Không có lịch sử chỉnh sửa ngày hoặc lý do</td>
        </tr>
    @endforelse
  </tbody>
</table>

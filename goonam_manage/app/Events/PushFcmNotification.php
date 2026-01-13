<?php

namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PushFcmNotification
{
    use Dispatchable, SerializesModels;

    /**
     * Tiêu đề thông báo
     */
    public string $title;

    /**
     * Nội dung thông báo
     */
    public string $body;

    /**
     * Dữ liệu phụ kèm theo
     */
    public array $data;

    /**
     * ID người gửi (để loại ra khỏi danh sách nhận)
     */
    public ?int $sender_id; // ✅ thêm dòng này để Intelephense hiểu

    /**
     * Tạo event
     */
    public function __construct(string $title, string $body, array $data = [], ?int $sender_id = null)
    {
        $this->title = $title;
        $this->body = $body;
        $this->data = $data;
        $this->sender_id = $sender_id; // ✅ gán giá trị vào thuộc tính
    }
}

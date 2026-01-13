<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class UnreadUpdated implements ShouldBroadcast
{
    use Dispatchable, SerializesModels;

    public int $userId;
    public int $unreadCount;

    public function __construct(int $userId, int $unreadCount)
    {
        $this->userId = $userId;
        $this->unreadCount = $unreadCount;
    }

    public function broadcastOn()
    {
        // Channel riêng cho từng user
        return new Channel('user.' . $this->userId);
    }

    public function broadcastAs()
    {
        return 'unread.updated';
    }
}

<?php

namespace App\Events;

use App\Models\OrderStage;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class StageCompleted
{
    use Dispatchable, InteractsWithSockets, SerializesModels;
    public $stage;
    /**
     * Create a new event instance.
     *
     * @return void
     */
    public function __construct(OrderStage $stage)
    {
         $this->stage = $stage;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return \Illuminate\Broadcasting\Channel|array
     */
    public function broadcastOn()
    {
        return new PrivateChannel('channel-name');
    }
}

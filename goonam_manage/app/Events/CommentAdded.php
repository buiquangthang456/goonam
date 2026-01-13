<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;
use App\Models\Comment;

class CommentAdded implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public Comment $comment;

    public function __construct(Comment $comment)
    {
        $this->comment = $comment;
    }

    public function broadcastOn()
    {
        // kênh private theo đơn
        return new PrivateChannel('order.' . $this->comment->order_id);
    }

    public function broadcastWith()
    {
        return [
            'id'         => $this->comment->id,
            'order_id'   => $this->comment->order_id,
            'user_id'    => $this->comment->user_id,
            'body'       => $this->comment->body,
            'created_at' => $this->comment->created_at->format('Y-m-d H:i:s'),
            'user'       => $this->comment->user()->select('id','name','role')->first(),
        ];
    }

    public function broadcastAs()
    {
        return 'comment.added';
    }
}

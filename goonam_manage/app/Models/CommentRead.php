<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CommentRead extends Model
{
    protected $fillable = ['comment_id', 'user_id', 'read_at'];

    protected $casts = [
        'id' => 'integer',
        'comment_id'=>'integer',
        'order_id' => 'integer',
        'user_id' => 'integer',

    ];

    public function comment()
    {
        return $this->belongsTo(Comment::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}

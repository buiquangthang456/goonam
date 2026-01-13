<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class DeviceToken extends Model
{
    use HasFactory;
    protected $fillable = ['user_id', 'token', 'device_type'];
    // 🟩 Quan hệ ngược: mỗi token thuộc về một user
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}

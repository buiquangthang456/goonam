<?php

namespace App\Providers;

use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;

class EventServiceProvider extends ServiceProvider
{
    protected $listen = [
        // Các event nội bộ của hệ thống gọi tới PushFcmNotification
        \App\Events\CommentAdded::class => [
            \App\Listeners\PushFcmNotification::class,
        ],
        \App\Events\StageCompleted::class => [
            \App\Listeners\PushFcmNotification::class,
        ],
        \App\Events\StageOverdue::class => [
            \App\Listeners\PushFcmNotification::class,
        ],
        \App\Events\OrderCreated::class => [
            \App\Listeners\PushFcmNotification::class,
        ],

        // ⚙️ Event FCM thật sự – chỉ 1 listener duy nhất!
        \App\Events\PushFcmNotification::class => [
            \App\Listeners\SendFcmNotification::class,
         ],
        
    ];

    public function boot()
    {
        //
    }

    public function shouldDiscoverEvents()
    {
        return false;
    }
}

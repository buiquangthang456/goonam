<?php

namespace App\Http\Middleware;

use Illuminate\Auth\Middleware\Authenticate as Middleware;

class Authenticate extends Middleware
{
    /**
     * Get the path the user should be redirected to when they are not authenticated.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return string|null
     */
    protected function redirectTo($request)
    {
        // Với API, Laravel sẽ tự trả JSON nếu dùng Sanctum/Passport
        if ($request->expectsJson()) {
            return null;
        }

        // Nếu không có route 'login', cũng không redirect — chỉ trả null
        return null;
    }
}

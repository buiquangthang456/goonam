<?php
namespace App\Rules;

use Illuminate\Contracts\Validation\Rule;
use Carbon\Carbon;

class SafeDate implements Rule
{
    public function passes($attribute, $value)
    {
        if (in_array($value, [null, '', '0', 0], true)) {
            return true; // chấp nhận bỏ qua
        }

        try {
            Carbon::parse($value);
            return true;
        } catch (\Exception $e) {
            return false;
        }
    }

    public function message()
    {
        return 'Ngày không hợp lệ.';
    }
}

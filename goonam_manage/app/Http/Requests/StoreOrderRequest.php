<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use App\Rules\SafeDate;
class StoreOrderRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     *
     * @return bool
     */
    public function authorize(): bool { return true; } // sẽ chặn bằng Policy/Controller

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, mixed>
     */
    protected function prepareForValidation()
    {
        if (isset($this->stages) && is_array($this->stages)) {
            $this->merge([
                'stages' => collect($this->stages)->map(function ($stage) {
                    foreach (['planned_start', 'planned_end'] as $key) {
                        // Nếu frontend gửi 0, '0', '' hoặc null → chuyển thành null
                        if (isset($stage[$key]) && in_array($stage[$key], [0, '0', '', null], true)) {
                            $stage[$key] = null;
                        }
                    }
                    return $stage;
                })->toArray(),
            ]);
        }
    }
    public function rules()
    {
        return [
            'order_type' => 'required|string',
            'project_name' => 'required|string',
            'company_name' => 'nullable|string',
            'order_no' => 'required|string',
            'description' => 'nullable|string|max:1000',
            'order_date' => 'required|date',
            'delivery_date' => 'required|date',
            'quantity' => 'required|integer',
            'status' => 'required|string',

            // Cho phép người dùng nhập thủ công danh sách công đoạn
            'stages' => 'nullable|array',
            'stages.*.template_id' => 'nullable|integer',
            'stages.*.name' => 'nullable|string',
            'stages.*.sequence' => 'nullable|integer',
            'stages.*.planned_start' => ['nullable', new SafeDate],
            'stages.*.planned_end'   => ['nullable', new SafeDate],
        ];
    }

}

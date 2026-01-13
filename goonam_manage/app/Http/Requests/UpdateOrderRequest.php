<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateOrderRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     *
     * @return bool
     */
   public function authorize(): bool { return true; }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $id = $this->route('order')->id ?? null;
        return [
            'order_type'   => 'sometimes|in:door,metal',
            'project_name' => 'sometimes|string',
            'company_name' => 'sometimes|string',
            'order_no'     => 'sometimes|string|max:100|unique:orders,order_no,' . $id,
            'description'  => 'nullable|string',
            'quantity'     => 'sometimes|integer|min:1',
            'order_date'   => 'sometimes|date',
            'delivery_date'=> 'sometimes|date|after:order_date',
            'status'       => 'sometimes|in:draft,in_progress,completed,cancelled',
        ];
    }
}

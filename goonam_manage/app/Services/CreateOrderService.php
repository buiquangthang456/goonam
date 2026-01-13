<?php

namespace App\Services;

class CreateOrderService {
  public function handle(array $data): Order {
    return DB::transaction(function() use ($data){
      $order = Order::create($data);

      $templates = StageTemplate::where('order_type',$order->order_type)->where('is_active',1)->orderBy('sequence')->get();

      $cursor = $order->order_date->clone();
      foreach($templates as $tpl){
        $durMin = (int)round($tpl->default_duration_days * 1440); // ngày -> phút
        $start = $tpl->sequence === 1 ? $cursor : null; // chỉ set start cho công đoạn đầu
        $end = ($start ?? $cursor)->clone()->addMinutes($durMin);

        OrderStage::create([
          'order_id'=>$order->id,
          'template_id'=>$tpl->id,
          'code'=>$tpl->code,
          'name'=>$tpl->name,
          'sequence'=>$tpl->sequence,
          'planned_start'=>$start,
          'planned_end'=>$end,
          'status'=>'pending',
        ]);

        $cursor = $end->clone();
      }
      event(new \App\Events\OrderCreated($order));
      return $order->load('stages');
    });
  }
}

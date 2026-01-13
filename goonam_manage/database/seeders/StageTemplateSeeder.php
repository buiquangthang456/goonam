<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class StageTemplateSeeder extends Seeder
{
    public function run()
    {
        $now = now();

        $templates = [

            // ===========================
            //        ORDER TYPE: DOOR
            // ===========================

            ['door','MATERIAL_TAKEOFF','Bốc khối lượng - Đặt vật tư',1,0.5,1],
            ['door','MATERIAL_INPUT','Nhập vật tư: Thép, Inox, Kính, Phụ kiện,...',2,0.5,1],
            ['door','STEEL_INOX_GLASS','Thép/Inox/Kính',3,0.5,0], // ẩn

            ['door','CUT_PUNCH','Cắt - Đột',3,0.5,1],
            ['door','PLANISH_BEND','Bào - Chấn',4,0.5,1],
            ['door','WELD','Ghép - Hàn',5,1.0,1],
            ['door','GRIND_FINISH','Mài - Hoàn thiện',6,0.5,1],
            ['door','INSPECTION_1','Nghiệm thu trước sơn',7,0.5,1],
            ['door','PAINT_PLATE','Sơn/ Mạ',8,0.5,1],
            ['door','INSPECTION_2','Nghiệm thu sau sơn',9,0.5,1],
            ['door','PACK','Đóng gói',10,0.5,1],
            ['door','DELIVERY','Giao hàng',11,0.5,1],


            // ===========================
            //        ORDER TYPE: METAL
            // ===========================

            ['metal','MATERIAL_TAKEOFF','Bốc khối lượng - Đặt vật tư',1,0.5,1],
            ['metal','MATERIAL_INPUT','Nhập vật tư...',2,0.5,1],
            ['metal','STEEL_INOX_GLASS','Thép/Inox/Kính',3,0.5,0],

            ['metal','CUT_PUNCH','Cắt - Đột',3,0.5,1],
            ['metal','PLANISH_BEND','Bào - Chấn',4,0.5,1],
            ['metal','WELD','Ghép - Hàn',5,1.0,1],
            ['metal','GRIND_FINISH','Mài - Hoàn thiện',6,0.5,1],
            ['metal','INSPECTION_1','Nghiệm thu',7,0.5,1],
            ['metal','PAINT_PLATE','Sơn/ Mạ',8,0.5,1],
            ['metal','INSPECTION_2','Nghiệm thu (lần nữa)',9,0.5,1],
            ['metal','PACK','Đóng gói',10,0.5,1],
            ['metal','DELIVERY','Giao hàng',11,0.5,1],
        ];

        foreach ($templates as $tpl) {
            DB::table('stage_templates')
                ->updateOrInsert(
                    [
                        'order_type' => $tpl[0],
                        'code'       => $tpl[1],
                    ],
                    [
                        'name'       => $tpl[2],
                        'sequence'   => $tpl[3],
                        'default_duration_days' => $tpl[4],
                        'is_active'  => $tpl[5],
                        'updated_at' => $now,
                        'created_at' => $now,
                    ]
                );
        }
    }
}

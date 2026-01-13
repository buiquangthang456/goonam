<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('orders', function (Blueprint $table) {
            // ✅ Xóa constraint unique cũ (chỉ có order_no)
            $table->dropUnique('orders_order_no_unique');

            // ✅ Thêm constraint unique mới (order_no + order_type)
            $table->unique(['order_no', 'order_type'], 'orders_order_no_type_unique');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('orders', function (Blueprint $table) {
            // ✅ Rollback: xóa constraint mới
            $table->dropUnique('orders_order_no_type_unique');

            // ✅ Khôi phục constraint cũ
            $table->unique('order_no', 'orders_order_no_unique');
        });
    }
};

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
        Schema::create('orders', function (Blueprint $t) {
            $t->id();
            $t->enum('order_type',['door','metal'])->index();
            $t->string('project_name');
            $t->string('order_no')->unique();
            $t->text('description')->nullable();
            $t->unsignedInteger('quantity')->default(1);
            $t->dateTime('order_date');
            $t->dateTime('delivery_date');
            $t->enum('status',['draft','in_progress','completed','cancelled'])->default('in_progress')->index();
            $t->boolean('highlight_flag')->default(false)->index();
            $t->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('orders');
    }
};

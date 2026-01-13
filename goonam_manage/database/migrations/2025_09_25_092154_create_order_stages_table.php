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
       Schema::create('order_stages', function (Blueprint $t) {
            $t->id();
            $t->foreignId('order_id')->constrained()->cascadeOnDelete();
            $t->foreignId('template_id')->nullable()->constrained('stage_templates')->nullOnDelete();
            $t->string('code')->index();
            $t->string('name');
            $t->unsignedTinyInteger('sequence')->index();
            $t->dateTime('planned_start')->nullable();
            $t->dateTime('planned_end')->nullable();
            $t->dateTime('actual_start')->nullable();
            $t->dateTime('actual_end')->nullable();
            $t->enum('status',['pending','in_progress','done','blocked','late'])->default('pending')->index();
            $t->boolean('is_overdue')->default(false)->index();
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
        Schema::dropIfExists('order_stages');
    }
};

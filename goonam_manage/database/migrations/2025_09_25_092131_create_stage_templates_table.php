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
        Schema::create('stage_templates', function (Blueprint $t) {
            $t->id();
            $t->enum('order_type',['door','metal'])->index();
            $t->string('code')->index();
            $t->string('name');
            $t->unsignedTinyInteger('sequence')->index();
            $t->decimal('default_duration_days',5,1)->default(0.5);
            $t->boolean('is_active')->default(true);
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
        Schema::dropIfExists('stage_templates');
    }
};

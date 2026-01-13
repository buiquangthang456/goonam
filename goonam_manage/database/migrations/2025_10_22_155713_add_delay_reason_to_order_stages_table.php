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
        Schema::table('order_stages', function (Blueprint $table) {
        $table->text('delay_reason')->nullable()->after('is_overdue');
    });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('order_stages', function (Blueprint $table) {
        $table->dropColumn('delay_reason');
    });
    }
};

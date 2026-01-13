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
        DB::statement("
            ALTER TABLE orders
            MODIFY COLUMN status ENUM(
                'draft',
                'in_progress',
                'completed',
                'cancelled',
                'done',
                'late',
                'completed_early',
                'completed_late'
            ) DEFAULT 'in_progress'
        ");
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        DB::statement("
            ALTER TABLE orders
            MODIFY COLUMN status ENUM(
                'draft',
                'in_progress',
                'completed',
                'cancelled'
            ) DEFAULT 'in_progress'
        ");
    }
};

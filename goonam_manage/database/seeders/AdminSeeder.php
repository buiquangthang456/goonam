<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use App\Models\User;
class AdminSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
       User::updateOrCreate(
            ['email'=>'admin@example.com'],
            ['name'=>'Admin','password'=>bcrypt('Goonam@2003'),'role'=>'admin','is_active'=>true]
        );
    }
}

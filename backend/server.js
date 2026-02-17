const express = require('express');
const cors = require('cors');
const axios = require('axios');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({
    origin: '*', // อนุญาตทุกแหล่งที่มา
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Application-Key']
})); // อนุญาตให้ Flutter เรียก API ได้
app.use(express.json()); // อ่านข้อมูล JSON ที่ส่งมาได้

// เชื่อมต่อ Supabase
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_KEY
);

// ตรวจสอบสิทธิ์ (Login / Verify)

app.post('/api/auth/verify', async (req, res) => {
    const { username, password } = req.body;

    try {
        // A. ยิงไปถาม TU API ว่ารหัสถูกไหม?
        const tuResponse = await axios.post(
            'https://restapi.tu.ac.th/api/v1/auth/Ad/verify',
            {
                "UserName": username,
                "PassWord": password
            },
            {
                headers: {
                    'Content-Type': 'application/json',
                    'Application-Key': process.env.TU_API_KEY
                }
            }
        );

        const tuData = tuResponse.data;

        // B. ถ้า TU API บอกว่า "ไม่ผ่าน" หรือ "รหัสผิด"
        if (tuData.status === false) {
            return res.status(401).json({
                success: false,
                message: 'รหัสผ่านไม่ถูกต้อง หรือบัญชีมีปัญหา (จาก TU API)'
            });
        }

        // C. ถ้า TU API บอกว่า "ผ่าน" (เป็นคนธรรมศาสตร์จริง)
        // เช็คต่อว่า... เคยสมัคร UniMart หรือยัง? โดยดูใน Supabase
        const { data: existingUser, error } = await supabase
            .from('users')
            .select('*')
            .eq('username', tuData.username)
            .single();

        if (existingUser) {
            // CASE 1: เคยสมัครแล้ว -> LOGIN สำเร็จ
            return res.json({
                success: true,
                action: 'LOGIN_SUCCESS',
                user: existingUser // ส่งข้อมูล User กลับไปให้แอป
            });
        } else {
            // CASE 2: ยังไม่เคยสมัคร -> ส่งข้อมูลไปหน้า REGISTER
            return res.json({
                success: true,
                action: 'GO_TO_REGISTER',
                tuProfile: {
                    username: tuData.username,
                    display_name_th: tuData.displayname_th,
                    display_name_en: tuData.displayname_en,
                    email: tuData.email,
                    department: tuData.department,
                    faculty: tuData.faculty,
                    type: tuData.type // student หรือ employee
                }
            });
        }

    } catch (err) {
        console.error("Error:", err.message);
        res.status(500).json({ success: false, message: 'Server Error', error: err.message });
    }
});

// ----------------------------------------------------
// API 2: ลงทะเบียนสมาชิกใหม่ (Register)
// หน้าที่: รับข้อมูลจากหน้า Register -> บันทึกลง Supabase
// ----------------------------------------------------
app.post('/api/auth/register', async (req, res) => {
    const { 
        username, 
        phone_number, 
        personal_email,
        // ข้อมูลจาก TU API ที่ส่งมาด้วย
        tu_email, display_name_th, display_name_en, faculty, department, user_type 
    } = req.body;

    try {
        // บันทึกลงฐานข้อมูล Supabase
        const { data, error } = await supabase
            .from('users')
            .insert([
                {
                    username,
                    phone_number,
                    personal_email,
                    tu_email,
                    display_name_th,
                    display_name_en,
                    faculty,
                    department,
                    user_type
                }
            ])
            .select();

        if (error) {
            throw error;
        }

        res.json({ success: true, message: 'ลงทะเบียนสำเร็จ!', user: data[0] });

    } catch (err) {
        console.error("Register Error:", err.message);
        res.status(500).json({ success: false, message: 'บันทึกข้อมูลไม่สำเร็จ', error: err.message });
    }
});

// Start Server
app.listen(PORT, () => {
    console.log(`✅ Server is running on port ${PORT}`);
});
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const { createClient } = require('@supabase/supabase-js');
const { PrismaClient } = require('@prisma/client');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// ==========================================
// 1. ตั้งค่าการเชื่อมต่อ Database ทั้ง 2 แบบ
// ==========================================
// A. Prisma (ของเพื่อน - ใช้จัดการ สินค้า/หมวดหมู่)
const prisma = new PrismaClient();

// B. Supabase Client (ของคุณ - ใช้จัดการ Login/Register)
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_KEY
);

// ==========================================
// 2. Middleware
// ==========================================
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Application-Key']
}));
app.use(express.json());
app.use('/uploads', express.static('uploads'));

// ตรวจสอบว่ามีโฟลเดอร์ uploads ไหม ถ้าไม่มีให้สร้าง (ของเพื่อน)
if (!fs.existsSync('./uploads')) {
  fs.mkdirSync('./uploads');
}

// Config Multer สำหรับอัปโหลดรูป (ของเพื่อน)
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => cb(null, Date.now() + '-' + Math.round(Math.random() * 1E9) + path.extname(file.originalname))
});
const upload = multer({ storage: storage });

// ==========================================
// 3. API ROUTES (ของคุณ: AUTHENTICATION)
// ==========================================

// 3.1 ตรวจสอบสิทธิ์ (Login / Verify)
app.post('/api/auth/verify', async (req, res) => {
    const { username, password } = req.body;

    try {
        const tuResponse = await axios.post(
            'https://restapi.tu.ac.th/api/v1/auth/Ad/verify',
            { "UserName": username, "PassWord": password },
            {
                headers: {
                    'Content-Type': 'application/json',
                    'Application-Key': process.env.TU_API_KEY
                }
            }
        );

        const tuData = tuResponse.data;

        if (tuData.status === false) {
            return res.status(401).json({
                success: false,
                message: 'รหัสผ่านไม่ถูกต้อง หรือบัญชีมีปัญหา (จาก TU API)'
            });
        }

        const { data: existingUser, error } = await supabase
            .from('users')
            .select('*')
            .eq('username', tuData.username)
            .single();

        if (existingUser) {
            return res.json({ success: true, action: 'LOGIN_SUCCESS', user: existingUser });
        } else {
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
                    type: tuData.type
                }
            });
        }
    } catch (err) {
        console.error("Error:", err.message);
        res.status(500).json({ success: false, message: 'Server Error', error: err.message });
    }
});

// 3.2 ลงทะเบียนสมาชิกใหม่ (Register)
app.post('/api/auth/register', async (req, res) => {
    const { 
        username, phone_number, personal_email,
        tu_email, display_name_th, display_name_en, faculty, department, user_type 
    } = req.body;

    try {
        const { data, error } = await supabase
            .from('users')
            .insert([{
                username, phone_number, personal_email, tu_email,
                display_name_th, display_name_en, faculty, department, user_type
            }])
            .select();

        if (error) throw error;
        res.json({ success: true, message: 'ลงทะเบียนสำเร็จ!', user: data[0] });
    } catch (err) {
        console.error("Register Error:", err.message);
        res.status(500).json({ success: false, message: 'บันทึกข้อมูลไม่สำเร็จ', error: err.message });
    }
});

// ==========================================
// 4. API ROUTES (ของเพื่อน: PRODUCTS & CATEGORIES)
// ==========================================

// 4.1 ดึงรายการหมวดหมู่
app.get('/categories', async (req, res) => {
  try {
    const categories = await prisma.category.findMany();
    res.json(categories);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 4.2 โพสต์ขายของ
app.post('/products', upload.array('images', 5), async (req, res) => {
  try {
    const { title, description, price, categoryId, condition, ownerId, location, type, rentPrice } = req.body;
    const imageFilenames = req.files ? req.files.map(file => file.filename) : [];

    const newProduct = await prisma.product.create({
      data: {
        title, description, price: parseFloat(price), condition,
        location: location || 'ไม่ระบุ',
        categoryId: parseInt(categoryId),
        ownerId: parseInt(ownerId),
        images: imageFilenames,
        status: 'AVAILABLE',
        type: type || 'SALE',
        rentPrice: rentPrice ? parseFloat(rentPrice) : null,
      },
    });
    res.json(newProduct);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
});

// 4.3 ดึงสินค้าของฉัน (หน้าร้านค้า)
app.get('/my-products/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const products = await prisma.product.findMany({
      where: { ownerId: parseInt(userId) },
      orderBy: { createdAt: 'desc' },
      include: {
        category: true,
        owner: { select: { name: true } }
      }
    });
    res.json(products);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
});

// 4.4 ดึงรายละเอียดสินค้า 1 ชิ้น
app.get('/products/:id', async (req, res) => {
  try {
    const product = await prisma.product.findUnique({
      where: { id: parseInt(req.params.id) },
      include: {
        category: true,
        owner: { select: { name: true } }
      },
    });
    if (!product) return res.status(404).json({ error: "Product not found" });
    res.json(product);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 4.5 ลบสินค้า
app.delete('/products/:id', async (req, res) => {
  try {
    await prisma.product.delete({
      where: { id: parseInt(req.params.id) },
    });
    res.json({ message: "Deleted successfully" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 4.6 แก้ไขข้อมูลสินค้า
app.patch('/products/:id', upload.array('images', 5), async (req, res) => {
  const { id } = req.params;
  const { title, description, price, condition, categoryId, status, location } = req.body;

  try {
    const updateData = {};
    if (title) updateData.title = title;
    if (description) updateData.description = description;
    if (price) updateData.price = parseFloat(price);
    if (condition) updateData.condition = condition;
    if (categoryId) updateData.categoryId = parseInt(categoryId);
    if (status) updateData.status = status;
    if (location) updateData.location = location;

    const updatedProduct = await prisma.product.update({
      where: { id: parseInt(id) },
      data: updateData,
    });
    res.json(updatedProduct);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 4.7 ดึงสินค้าทั้งหมด (สำหรับหน้า Home)
app.get('/products', async (req, res) => {
  try {
    const products = await prisma.product.findMany({
      where: { status: 'AVAILABLE' },
      orderBy: { createdAt: 'desc' },
      include: {
        category: true,
        owner: { select: { name: true, profileImage: true } }
      }
    });
    res.json(products);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ==========================================
// 5. START SERVER
// ==========================================
app.listen(PORT, () => {
    console.log(`✅ Server is running on port ${PORT}`);
});
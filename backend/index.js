const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
const prisma = new PrismaClient();

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static('uploads'));

// ตรวจสอบว่ามีโฟลเดอร์ uploads ไหม ถ้าไม่มีให้สร้าง
if (!fs.existsSync('./uploads')) {
    fs.mkdirSync('./uploads');
}

// Config Multer
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => cb(null, Date.now() + '-' + Math.round(Math.random() * 1E9) + path.extname(file.originalname))
});
const upload = multer({ storage: storage });

// --- API ---

// 1. ดึงรายการหมวดหมู่ (ให้ App เอาไปทำ Dropdown)
app.get('/categories', async (req, res) => {
  try {
    const categories = await prisma.category.findMany();
    res.json(categories);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 2. โพสต์ขายของ (รองรับหลายรูป)
// upload.array('images', 5) แปลว่ารับรูปชื่อ field 'images' ได้สูงสุด 5 รูป
app.post('/products', upload.array('images', 5), async (req, res) => {
  try {
    // ข้อมูลจาก Form จะมาเป็น String ทั้งหมด ต้องแปลง type ก่อน
    const { title, description, price, categoryId, condition, ownerId } = req.body;
    
    // ดึงชื่อไฟล์ทั้งหมดที่อัปโหลดมา
    const imageFilenames = req.files ? req.files.map(file => file.filename) : [];

    const newProduct = await prisma.product.create({
      data: {
        title,
        description,
        price: parseFloat(price),
        condition,
        categoryId: parseInt(categoryId),
        ownerId: parseInt(ownerId),
        images: imageFilenames, // Prisma schema ใหม่รับเป็น String[] (Array) ได้เลย
        status: 'AVAILABLE'
      },
    });
    res.json(newProduct);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
});

// 3. ดึงสินค้าของฉัน (แก้ให้รองรับ images array)
app.get('/my-products/:userId', async (req, res) => {
  try {
    const products = await prisma.product.findMany({
      where: { ownerId: parseInt(req.params.userId) },
      include: { category: true }, // ดึงชื่อหมวดหมู่มาด้วย
      orderBy: { createdAt: 'desc' }
    });
    res.json(products);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 4. ดึงรายละเอียดสินค้า 1 ชิ้น (Get Single Product)
app.get('/products/:id', async (req, res) => {
  try {
    const product = await prisma.product.findUnique({
      where: { id: parseInt(req.params.id) },
      include: { category: true, owner: true }, // ดึงข้อมูลหมวดหมู่และคนขายมาด้วย
    });
    if (!product) return res.status(404).json({ error: "Product not found" });
    res.json(product);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 5. ลบสินค้า (Delete Product)
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

// 6. แก้ไขข้อมูลสินค้า (Update Product)
// รองรับทั้งแก้ไขเนื้อหา และเปลี่ยน Status
app.patch('/products/:id', upload.array('images', 5), async (req, res) => {
  const { id } = req.params;
  const { title, description, price, condition, categoryId, status } = req.body;

  try {
    // เตรียมข้อมูลที่จะอัปเดต (เช็คว่าส่งอะไรมาบ้าง)
    const updateData = {};
    if (title) updateData.title = title;
    if (description) updateData.description = description;
    if (price) updateData.price = parseFloat(price);
    if (condition) updateData.condition = condition;
    if (categoryId) updateData.categoryId = parseInt(categoryId);
    if (status) updateData.status = status; // ค่าที่เป็นไปได้: AVAILABLE, RESERVED, SOLD

    // หมายเหตุ: ในตัวอย่างนี้ยังไม่ทำระบบแก้รูปภาพ (เพราะซับซ้อน) ให้แก้ข้อความก่อน

    const updatedProduct = await prisma.product.update({
      where: { id: parseInt(id) },
      data: updateData,
    });
    res.json(updatedProduct);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
app.listen(3000, () => console.log('Server running on port 3000'));
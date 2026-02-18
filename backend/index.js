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

// 1. ดึงรายการหมวดหมู่
app.get('/categories', async (req, res) => {
  try {
    const categories = await prisma.category.findMany();
    res.json(categories);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 2. โพสต์ขายของ
app.post('/products', upload.array('images', 5), async (req, res) => {
  try {
    const { title, description, price, categoryId, condition, ownerId, location } = req.body;
    const imageFilenames = req.files ? req.files.map(file => file.filename) : [];

    const newProduct = await prisma.product.create({
      data: {
        title,
        description,
        price: parseFloat(price),
        condition,
        location: location || 'ไม่ระบุ',
        categoryId: parseInt(categoryId),
        ownerId: parseInt(ownerId),
        images: imageFilenames,
        status: 'AVAILABLE'
      },
    });
    res.json(newProduct);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
});

// 3. ดึงสินค้าของฉัน (หน้าร้านค้า) ⭐ แก้ไขแล้ว ⭐
app.get('/my-products/:userId', async (req, res) => {
  try {
    const { userId } = req.params; 

    const products = await prisma.product.findMany({
      where: {
        ownerId: parseInt(userId)
      },
      orderBy: {
        createdAt: 'desc'
      },
      include: {
        category: true,
        owner: {
          select: {
            name: true, // ✅ ใช้ name ตาม Schema
          }
        }
      }
    });
    res.json(products);
  } catch (error) {
    console.error(error); // เพิ่ม log ให้เห็น error ชัดๆ
    res.status(500).json({ error: error.message });
  }
});

// 4. ดึงรายละเอียดสินค้า 1 ชิ้น
app.get('/products/:id', async (req, res) => {
  try {
    const product = await prisma.product.findUnique({
      where: { id: parseInt(req.params.id) },
      include: {
        category: true,
        owner: {
          select: {
            name: true // ✅ แก้จาก username เป็น name ให้ถูกต้อง
          }
        }
      },
    });
    if (!product) return res.status(404).json({ error: "Product not found" });
    res.json(product);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 5. ลบสินค้า
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

// 6. แก้ไขข้อมูลสินค้า
app.patch('/products/:id', upload.array('images', 5), async (req, res) => {
  const { id } = req.params;
  // ✅ เพิ่ม location ในการรับค่า
  const { title, description, price, condition, categoryId, status, location } = req.body;

  try {
    const updateData = {};
    if (title) updateData.title = title;
    if (description) updateData.description = description;
    if (price) updateData.price = parseFloat(price);
    if (condition) updateData.condition = condition;
    if (categoryId) updateData.categoryId = parseInt(categoryId);
    if (status) updateData.status = status;
    if (location) updateData.location = location; // ✅ แก้ไขให้ถูกต้อง

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
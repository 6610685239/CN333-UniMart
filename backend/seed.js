// seed.js
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  // 1. สร้าง User (ถ้ายังไม่มี)
  const user = await prisma.user.upsert({
    where: { email: 'studentA@univ.edu' },
    update: {},
    create: {
      email: 'studentA@univ.edu',
      name: 'Student A',
      password: 'hashed_password_placeholder', // ใส่ไว้ก่อน
    },
  });

  // 2. สร้างหมวดหมู่ (Categories)
  const categories = ['หนังสือเรียน', 'เสื้อผ้า/เครื่องแบบ', 'ของใช้หอพัก', 'อุปกรณ์ IT', 'อื่นๆ'];
  
  for (const catName of categories) {
    await prisma.category.upsert({
      where: { name: catName },
      update: {},
      create: { name: catName },
    });
  }

  console.log('Seeding completed! User ID:', user.id);
}

main()
  .catch((e) => console.error(e))
  .finally(async () => await prisma.$disconnect());
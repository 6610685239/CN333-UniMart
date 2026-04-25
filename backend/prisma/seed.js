const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

const categories = [
  { name: 'Electronics' },
  { name: 'Books' },
  { name: 'Clothing' },
  { name: 'Dorm Supplies' },
  { name: 'Others' },
  { name: 'Textbooks' },
  { name: 'Uniforms' },
  { name: 'Gadgets' },
  { name: 'Accessories' },
  { name: 'Stationery' },
  { name: 'Dorm Essentials' },
  { name: 'Sports' },
];

const meetingPoints = [
  { id: 1, name: 'โรงอาหารกรีน', zone: 'ในมหาวิทยาลัย' },
  { id: 2, name: 'SC Hall', zone: 'ในมหาวิทยาลัย' },
  { id: 3, name: 'ป้ายรถตู้', zone: 'ในมหาวิทยาลัย' },
  { id: 4, name: 'หอพักเชียงราก', zone: 'เชียงราก' },
  { id: 5, name: 'หอพักอินเตอร์โซน', zone: 'อินเตอร์โซน' },
];

async function main() {
  for (const cat of categories) {
    await prisma.category.upsert({
      where: { name: cat.name },
      update: {},
      create: { name: cat.name },
    });
  }

  for (const mp of meetingPoints) {
    await prisma.meetingPoint.upsert({
      where: { name: mp.name },
      update: {},
      create: { name: mp.name, zone: mp.zone },
    });
  }

  console.log(`Seed completed: ${categories.length} categories, ${meetingPoints.length} meeting points`);
}

main()
  .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

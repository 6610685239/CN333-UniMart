const { prisma } = require('../models');

async function getCategories() {
  console.log("HIT /api/categories");
  return prisma.category.findMany();
}

async function createProduct(body, files) {
  const { title, description, price, categoryId, condition, ownerId, location, type, rentPrice, meetingPointId } = body;
  const imageFilenames = files ? files.map(file => file.filename) : [];
  console.log("ownerId:", ownerId);

  const productData = {
    title, description, price: parseFloat(price), condition,
    location: location || 'ไม่ระบุ',
    categoryId: parseInt(categoryId),
    ownerId: ownerId,
    images: imageFilenames,
    status: 'AVAILABLE',
    type: type || 'SALE',
    rentPrice: rentPrice ? parseFloat(rentPrice) : null,
  };

  if (meetingPointId) {
    productData.meetingPointId = parseInt(meetingPointId);
  }

  return prisma.product.create({ data: productData });
}

async function getMyProducts(userId) {
  return prisma.product.findMany({
    where: { ownerId: userId },
    orderBy: { createdAt: 'desc' },
    include: {
      category: true,
      owner: true
    }
  });
}

async function getProductById(id) {
  return prisma.product.findUnique({
    where: { id: parseInt(id) },
    include: {
      category: true,
      owner: true
    },
  });
}

async function deleteProduct(id) {
  return prisma.product.delete({
    where: { id: parseInt(id) },
  });
}

async function updateProduct(id, body) {
  const { title, description, price, condition, categoryId, status, location } = body;

  const updateData = {};
  if (title) updateData.title = title;
  if (description) updateData.description = description;
  if (price) updateData.price = parseFloat(price);
  if (condition) updateData.condition = condition;
  if (categoryId) updateData.categoryId = parseInt(categoryId);
  if (status) updateData.status = status;
  if (location) updateData.location = location;

  return prisma.product.update({
    where: { id: parseInt(id) },
    data: updateData,
  });
}

async function getAllProducts(ownerId) {
  console.log("ownerId from query:", ownerId);

  return prisma.product.findMany({
    where: ownerId ? { ownerId: ownerId } : undefined,
    include: { owner: true, category: true },
    orderBy: { createdAt: 'desc' }
  });
}

module.exports = {
  getCategories,
  createProduct,
  getMyProducts,
  getProductById,
  deleteProduct,
  updateProduct,
  getAllProducts
};

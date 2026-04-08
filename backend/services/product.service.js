const { prisma } = require('../models');

async function attachFavouriteCounts(products) {
  if (!products || products.length === 0) return [];

  const favouriteGroups = await prisma.product_favourites.groupBy({
    by: ['product_id'],
    where: {
      product_id: {
        in: products.map((product) => product.id.toString()),
      },
    },
    _count: {
      product_id: true,
    },
  });

  const favouriteCountMap = new Map(
    favouriteGroups.map((group) => [group.product_id, group._count.product_id])
  );

  return products.map((product) => ({
    ...product,
    favouritesCount: favouriteCountMap.get(product.id.toString()) ?? 0,
  }));
}

async function getCategories() {
  console.log("HIT /api/categories");
  return prisma.category.findMany();
}

async function createProduct(body, files) {
  const { title, description, price, categoryId, condition, ownerId, location, type, rentPrice, meetingPointId, quantity } = body;
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
    quantity: quantity ? parseInt(quantity) : 1,
  };

  if (meetingPointId) {
    productData.meetingPointId = parseInt(meetingPointId);
  }

  return prisma.product.create({ data: productData });
}

async function getMyProducts(userId) {
  const products = await prisma.product.findMany({
    where: { ownerId: userId },
    orderBy: { createdAt: 'desc' },
    include: {
      category: true,
      owner: true
    }
  });

  return attachFavouriteCounts(products);
}

async function getProductById(id) {
  const product = await prisma.product.findUnique({
    where: { id: parseInt(id) },
    include: {
      category: true,
      owner: true
    },
  });

  if (!product) return null;

  const [withCounts] = await attachFavouriteCounts([product]);
  return withCounts;
}

async function deleteProduct(id) {
  return prisma.product.delete({
    where: { id: parseInt(id) },
  });
}

async function updateProduct(id, body) {
  const { title, description, price, condition, categoryId, status, location, quantity } = body;

  const updateData = {};
  if (title) updateData.title = title;
  if (description) updateData.description = description;
  if (price) updateData.price = parseFloat(price);
  if (condition) updateData.condition = condition;
  if (categoryId) updateData.categoryId = parseInt(categoryId);
  if (status) updateData.status = status;
  if (location) updateData.location = location;
  if (quantity !== undefined && quantity !== null) updateData.quantity = parseInt(quantity);

  return prisma.product.update({
    where: { id: parseInt(id) },
    data: updateData,
  });
}

async function getAllProducts(ownerId) {
  console.log("ownerId from query:", ownerId);

  const products = await prisma.product.findMany({
    where: ownerId ? { ownerId: ownerId } : undefined,
    include: { owner: true, category: true },
    orderBy: { createdAt: 'desc' }
  });

  return attachFavouriteCounts(products);
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

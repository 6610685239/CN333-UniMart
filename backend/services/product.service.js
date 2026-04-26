const { prisma, supabase } = require('../models');
const path = require('path');

const BUCKET = 'product-images';

/**
 * Upload an array of multer memory files to Supabase Storage.
 * Returns an array of public URLs.
 */
async function uploadImagesToSupabase(files) {
  if (!files || files.length === 0) return [];

  const urls = [];
  for (const file of files) {
    const origName = file.originalname || file.originalName || 'image.jpg';
    const ext = path.extname(origName) || '.jpg';
    const fileName = `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
    const filePath = `products/${fileName}`;

    const { error } = await supabase.storage
      .from(BUCKET)
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: false,
      });

    if (error) throw new Error(`Image upload failed: ${error.message}`);

    const { data: urlData } = supabase.storage
      .from(BUCKET)
      .getPublicUrl(filePath);

    urls.push(urlData.publicUrl);
  }
  return urls;
}

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
  const imageUrls = await uploadImagesToSupabase(files);
  console.log("ownerId:", ownerId);

  const productData = {
    title, description, price: parseFloat(price), condition,
    location: location || 'ไม่ระบุ',
    categoryId: parseInt(categoryId),
    ownerId: ownerId,
    images: imageUrls,
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

const safeOwnerSelect = {
  select: {
    id: true,
    display_name_th: true,
    display_name_en: true,
    username: true,
    faculty: true,
    department: true,
    tu_status: true,
    avatar: true,
    dormitory_zone: true,
  }
};

async function getMyProducts(userId) {
  const products = await prisma.product.findMany({
    where: { ownerId: userId },
    orderBy: { createdAt: 'desc' },
    include: {
      category: true,
      owner: safeOwnerSelect
    }
  });

  return attachFavouriteCounts(products);
}

async function getProductById(id) {
  const product = await prisma.product.findUnique({
    where: { id: parseInt(id) },
    include: {
      category: true,
      owner: safeOwnerSelect
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

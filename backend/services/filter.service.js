const { prisma } = require('../models');

async function filterProducts({ faculty, dormitoryZone, meetingPoint, minCredit, categoryId }) {
  // Build Prisma where clause dynamically (AND logic)
  const where = { status: 'Available' };
  const ownerWhere = {};

  if (faculty) {
    ownerWhere.faculty = faculty;
  }

  if (dormitoryZone) {
    ownerWhere.dormitory_zone = dormitoryZone;
  }

  if (Object.keys(ownerWhere).length > 0) {
    where.owner = ownerWhere;
  }

  if (meetingPoint) {
    where.meetingPoint = { name: meetingPoint };
  }

  if (categoryId) {
    where.categoryId = parseInt(categoryId);
  }

  // Fetch products with owner and meetingPoint info
  const products = await prisma.product.findMany({
    where,
    include: {
      owner: { select: { id: true, display_name_th: true, username: true, faculty: true, dormitory_zone: true } },
      category: true,
      meetingPoint: true
    },
    orderBy: { createdAt: 'desc' }
  });

  // If minCredit is provided, filter in application code
  let filteredProducts = products;
  if (minCredit) {
    const minCreditValue = parseFloat(minCredit);
    const ownerIds = [...new Set(products.map(p => p.ownerId))];

    // Fetch credit scores for all relevant sellers
    const creditScores = {};
    for (const ownerId of ownerIds) {
      const aggregate = await prisma.review.aggregate({
        where: { revieweeId: ownerId },
        _avg: { rating: true },
        _count: { rating: true }
      });
      creditScores[ownerId] = {
        averageRating: aggregate._avg.rating || 0,
        totalReviews: aggregate._count.rating
      };
    }

    filteredProducts = products.filter(p => {
      const score = creditScores[p.ownerId];
      return score && score.totalReviews > 0 && score.averageRating >= minCreditValue;
    });
  }

  return {
    products: filteredProducts,
    totalCount: filteredProducts.length
  };
}

async function getMeetingPoints() {
  return prisma.meetingPoint.findMany();
}

function getDormitoryZones() {
  return ['เชียงราก', 'อินเตอร์โซน', 'ในมหาวิทยาลัย'];
}

module.exports = {
  filterProducts,
  getMeetingPoints,
  getDormitoryZones
};

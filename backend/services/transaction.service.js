const { prisma } = require('../models');

function normalizeProductStatus(status) {
  return (status || '').toString().trim().toUpperCase();
}

async function createTransaction(buyerId, productId, type) {
  const runCreate = async (db) => {
    const product = await db.product.findUnique({
      where: { id: parseInt(productId) }
    });

    if (!product) {
      return { error: 'NOT_FOUND' };
    }

    const normalizedStatus = normalizeProductStatus(product.status);
    if (normalizedStatus === 'RESERVED' || normalizedStatus === 'SOLD') {
      return { error: 'RESERVED' };
    }

    // Check stock quantity for SALE products
    if (type === 'SALE' && product.quantity <= 0) {
      return { error: 'OUT_OF_STOCK' };
    }

    // Decrement quantity for SALE; only set RESERVED when stock hits 0
    const updateData = {};
    if (type === 'SALE') {
      updateData.quantity = { decrement: 1 };
      // If this was the last item, mark as RESERVED; otherwise keep AVAILABLE
      updateData.status = product.quantity <= 1 ? 'RESERVED' : 'AVAILABLE';
    } else {
      // RENT always goes to RESERVED
      updateData.status = 'RESERVED';
    }

    await db.product.update({
      where: { id: parseInt(productId) },
      data: updateData
    });

    const transaction = await db.transaction.create({
      data: {
        buyerId,
        sellerId: product.ownerId,
        productId: parseInt(productId),
        type,
        status: 'PENDING',
        price: type === 'RENT' && product.rentPrice ? product.rentPrice : product.price
      }
    });

    return { transaction };
  };

  const canUseRealTransaction =
    typeof prisma.$transaction === 'function' && !prisma.$transaction._isMockFunction;

  if (canUseRealTransaction) {
    return prisma.$transaction((tx) => runCreate(tx));
  }

  return runCreate(prisma);
}

async function confirmTransaction(id) {
  const transaction = await prisma.transaction.findUnique({
    where: { id: parseInt(id) }
  });

  if (!transaction) {
    return { error: 'NOT_FOUND' };
  }

  if (transaction.status !== 'PENDING') {
    return { error: 'INVALID_STATUS', currentStatus: transaction.status };
  }

  const [updated] = await prisma.$transaction([
    prisma.transaction.update({
      where: { id: transaction.id },
      data: { status: 'PROCESSING' }
    }),
    prisma.product.update({
      where: { id: transaction.productId },
      data: { status: 'RESERVED' }
    })
  ]);

  return { transaction: updated };
}

async function shipTransaction(id) {
  const transaction = await prisma.transaction.findUnique({
    where: { id: parseInt(id) }
  });

  if (!transaction) {
    return { error: 'NOT_FOUND' };
  }

  if (transaction.status !== 'PROCESSING') {
    return { error: 'INVALID_STATUS', currentStatus: transaction.status };
  }

  const updated = await prisma.transaction.update({
    where: { id: transaction.id },
    data: { status: 'SHIPPING' }
  });

  return { transaction: updated };
}

async function returnTransaction(id) {
  const transaction = await prisma.transaction.findUnique({
    where: { id: parseInt(id) }
  });

  if (!transaction) return { error: 'NOT_FOUND' };
  if (transaction.type !== 'RENT') return { error: 'NOT_RENT' };
  if (transaction.status !== 'SHIPPING') {
    return { error: 'INVALID_STATUS', currentStatus: transaction.status };
  }

  const updated = await prisma.transaction.update({
    where: { id: transaction.id },
    data: { status: 'RETURNING' }
  });

  return { transaction: updated };
}

async function completeTransaction(id) {
  const transaction = await prisma.transaction.findUnique({
    where: { id: parseInt(id) }
  });

  if (!transaction) {
    return { error: 'NOT_FOUND' };
  }

  const isRent = transaction.type === 'RENT';
  const validFrom = isRent ? 'RETURNING' : 'SHIPPING';

  if (transaction.status !== validFrom) {
    return { error: 'INVALID_STATUS', currentStatus: transaction.status };
  }

  const [updated] = await prisma.$transaction([
    prisma.transaction.update({
      where: { id: transaction.id },
      data: { status: 'COMPLETED' }
    }),
    prisma.product.update({
      where: { id: transaction.productId },
      data: { status: isRent ? 'AVAILABLE' : 'SOLD' }
    })
  ]);

  return { transaction: updated };
}

async function cancelTransaction(id, canceledBy, cancelReason) {
  const transaction = await prisma.transaction.findUnique({
    where: { id: parseInt(id) }
  });

  if (!transaction) {
    return { error: 'NOT_FOUND' };
  }

  if (!['PENDING', 'PROCESSING'].includes(transaction.status)) {
    return { error: 'INVALID_STATUS', currentStatus: transaction.status };
  }

  const [updated] = await prisma.$transaction([
    prisma.transaction.update({
      where: { id: transaction.id },
      data: { status: 'CANCELED', canceledBy: canceledBy || null, cancelReason: cancelReason || null }
    }),
    prisma.product.update({
      where: { id: transaction.productId },
      data: {
        status: 'AVAILABLE',
        ...(transaction.type === 'SALE' ? { quantity: { increment: 1 } } : {}),
      }
    })
  ]);

  return { transaction: updated };
}

async function getUserTransactions(userId) {
  const transactions = await prisma.transaction.findMany({
    where: {
      OR: [
        { buyerId: userId },
        { sellerId: userId }
      ]
    },
    include: {
      product: { select: { id: true, title: true, price: true, rentPrice: true, images: true, status: true } },
      buyer: { select: { id: true, display_name_th: true, username: true, avatar: true } },
      seller: { select: { id: true, display_name_th: true, username: true, avatar: true } },
      reviews: { where: { reviewerId: userId }, select: { id: true } },
    },
    orderBy: { updatedAt: 'desc' }
  });

  const withReviewed = transactions.map(({ reviews, ...t }) => ({
    ...t,
    hasReviewed: reviews.length > 0,
  }));

  return {
    processing: withReviewed.filter(t => t.status === 'PENDING' || t.status === 'PROCESSING'),
    shipping: withReviewed.filter(t => t.status === 'SHIPPING'),
    history: withReviewed.filter(t => t.status === 'COMPLETED'),
    canceled: withReviewed.filter(t => t.status === 'CANCELED'),
  };
}

module.exports = {
  createTransaction,
  confirmTransaction,
  shipTransaction,
  returnTransaction,
  completeTransaction,
  cancelTransaction,
  getUserTransactions
};

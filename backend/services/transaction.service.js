const { prisma } = require('../models');

async function createTransaction(buyerId, productId, type) {
  // Use a transaction to reliably lock the product status
  return await prisma.$transaction(async (tx) => {
    const product = await tx.product.findUnique({
      where: { id: parseInt(productId) }
    });

    if (!product) {
      return { error: 'NOT_FOUND' };
    }

    if (product.status === 'RESERVED' || product.status === 'SOLD') {
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

    await tx.product.update({
      where: { id: parseInt(productId) },
      data: updateData
    });

    const transaction = await tx.transaction.create({
      data: {
        buyerId,
        sellerId: product.ownerId,
        productId: parseInt(productId),
        type,
        status: 'PENDING',
        price: product.price
      }
    });

    return { transaction };
  });
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
      data: { status: 'Reserved' }
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

async function completeTransaction(id) {
  const transaction = await prisma.transaction.findUnique({
    where: { id: parseInt(id) }
  });

  if (!transaction) {
    return { error: 'NOT_FOUND' };
  }

  if (transaction.status !== 'SHIPPING') {
    return { error: 'INVALID_STATUS', currentStatus: transaction.status };
  }

  const [updated] = await prisma.$transaction([
    prisma.transaction.update({
      where: { id: transaction.id },
      data: { status: 'COMPLETED' }
    }),
    prisma.product.update({
      where: { id: transaction.productId },
      data: { status: 'Sold' }
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
      product: { select: { id: true, title: true, price: true, images: true, status: true } },
      buyer: { select: { id: true, display_name_th: true, username: true } },
      seller: { select: { id: true, display_name_th: true, username: true } }
    },
    orderBy: { updatedAt: 'desc' }
  });

  return {
    processing: transactions.filter(t => t.status === 'PENDING' || t.status === 'PROCESSING'),
    shipping: transactions.filter(t => t.status === 'SHIPPING'),
    history: transactions.filter(t => t.status === 'COMPLETED'),
    canceled: transactions.filter(t => t.status === 'CANCELED')
  };
}

module.exports = {
  createTransaction,
  confirmTransaction,
  shipTransaction,
  completeTransaction,
  cancelTransaction,
  getUserTransactions
};

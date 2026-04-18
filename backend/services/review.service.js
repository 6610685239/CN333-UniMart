const { prisma } = require('../models');

async function createReview(transactionId, reviewerId, revieweeId, rating, comment) {
  const transaction = await prisma.transaction.findUnique({
    where: { id: parseInt(transactionId) }
  });

  if (!transaction) {
    return { error: 'NOT_FOUND' };
  }

  if (transaction.status !== 'COMPLETED') {
    return { error: 'NOT_COMPLETED' };
  }

  // Validate reviewer is actually a party to this transaction
  const isParty = (reviewerId === transaction.buyerId || reviewerId === transaction.sellerId);
  if (!isParty) {
    return { error: 'NOT_PARTY' };
  }

  // Validate reviewee is the other party
  const expectedReviewee = reviewerId === transaction.buyerId ? transaction.sellerId : transaction.buyerId;
  if (revieweeId !== expectedReviewee) {
    return { error: 'INVALID_REVIEWEE' };
  }

  const review = await prisma.review.create({
    data: {
      transactionId: parseInt(transactionId),
      reviewerId,
      revieweeId,
      rating,
      comment: comment || null
    }
  });

  return {
    review: {
      id: review.id,
      rating: review.rating,
      comment: review.comment,
      createdAt: review.createdAt
    }
  };
}

async function getUserReviews(userId) {
  const reviews = await prisma.review.findMany({
    where: { revieweeId: userId },
    include: {
      reviewer: { select: { display_name_th: true } }
    },
    orderBy: { createdAt: 'desc' }
  });

  return reviews.map(r => ({
    id: r.id,
    transactionId: r.transactionId,
    reviewerId: r.reviewerId,
    revieweeId: r.revieweeId,
    rating: r.rating,
    comment: r.comment,
    createdAt: r.createdAt,
    reviewerName: r.reviewer?.display_name_th || null
  }));
}

async function getCreditScore(userId) {
  const aggregate = await prisma.review.aggregate({
    where: { revieweeId: userId },
    _avg: { rating: true },
    _count: { rating: true }
  });

  return {
    averageRating: aggregate._avg.rating || 0,
    totalReviews: aggregate._count.rating
  };
}

async function hasReviewed(transactionId, reviewerId) {
  const review = await prisma.review.findUnique({
    where: {
      transactionId_reviewerId: {
        transactionId: parseInt(transactionId),
        reviewerId
      }
    }
  });
  return { hasReviewed: !!review };
}

module.exports = {
  createReview,
  getUserReviews,
  getCreditScore,
  hasReviewed
};

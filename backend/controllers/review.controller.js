const reviewService = require('../services/review.service');

async function create(req, res) {
  const { transactionId, reviewerId, revieweeId, rating, comment } = req.body;

  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    return res.status(400).json({ success: false, message: 'คะแนนดาวต้องอยู่ระหว่าง 1-5' });
  }

  try {
    const result = await reviewService.createReview(transactionId, reviewerId, revieweeId, rating, comment);

    if (result.error === 'NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'ไม่พบธุรกรรม' });
    }
    if (result.error === 'NOT_COMPLETED') {
      return res.status(403).json({ success: false, message: 'สามารถรีวิวได้เฉพาะธุรกรรมที่เสร็จสิ้นแล้ว' });
    }
    if (result.error === 'NOT_PARTY') {
      return res.status(403).json({ success: false, message: 'คุณไม่ใช่ผู้ซื้อหรือผู้ขายในธุรกรรมนี้' });
    }
    if (result.error === 'INVALID_REVIEWEE') {
      return res.status(400).json({ success: false, message: 'ผู้ถูกรีวิวต้องเป็นอีกฝ่ายในธุรกรรม' });
    }

    res.status(201).json(result.review);
  } catch (err) {
    if (err.code === 'P2002') {
      return res.status(409).json({ success: false, message: 'คุณได้รีวิวธุรกรรมนี้แล้ว' });
    }
    console.error('Create Review Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถสร้างรีวิวได้', error: err.message });
  }
}

async function getUserReviews(req, res) {
  const { userId } = req.params;

  try {
    const result = await reviewService.getUserReviews(userId);
    res.json(result);
  } catch (err) {
    console.error('Get User Reviews Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถดึงรีวิวได้', error: err.message });
  }
}

async function getCreditScore(req, res) {
  const { userId } = req.params;

  try {
    const result = await reviewService.getCreditScore(userId);
    res.json(result);
  } catch (err) {
    console.error('Get Credit Score Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถดึงคะแนนเครดิตได้', error: err.message });
  }
}

async function hasReviewed(req, res) {
  const { transactionId, reviewerId } = req.params;
  try {
    const result = await reviewService.hasReviewed(transactionId, reviewerId);
    res.json(result);
  } catch (err) {
    console.error('Has Reviewed Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถตรวจสอบรีวิวได้' });
  }
}

module.exports = { create, getUserReviews, getCreditScore, hasReviewed };

const express = require('express');
const router = express.Router();
const reviewController = require('../controllers/review.controller');

router.post('/', reviewController.create);
router.get('/user/:userId', reviewController.getUserReviews);
router.get('/credit/:userId', reviewController.getCreditScore);

module.exports = router;

const express = require('express');
const router = express.Router();
const transactionController = require('../controllers/transaction.controller');

router.post('/', transactionController.create);
router.patch('/:id/confirm', transactionController.confirm);
router.patch('/:id/ship', transactionController.ship);
router.patch('/:id/return', transactionController.returnItem);
router.patch('/:id/complete', transactionController.complete);
router.patch('/:id/cancel', transactionController.cancel);
router.get('/user/:userId', transactionController.getUserTransactions);
router.get('/:id', transactionController.getById);

module.exports = router;

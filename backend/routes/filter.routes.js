const express = require('express');
const router = express.Router();
const filterController = require('../controllers/filter.controller');

router.get('/products/filter', filterController.filterProducts);
router.get('/meeting-points', filterController.getMeetingPoints);
router.get('/dormitory-zones', filterController.getDormitoryZones);

module.exports = router;

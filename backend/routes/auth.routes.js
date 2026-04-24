const express = require('express');
const multer = require('multer');
const path = require('path');
const router = express.Router();
const authController = require('../controllers/auth.controller');

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => cb(null, 'avatar-' + Date.now() + path.extname(file.originalname))
});
const upload = multer({ storage });

router.post('/verify', authController.verify);
router.post('/register', authController.register);
router.post('/login', authController.login);
router.post('/change-password', authController.changePassword);
router.post('/:userId/avatar', upload.single('avatar'), authController.uploadAvatar);
router.get('/:userId/profile', authController.getUserProfile);
router.patch('/:userId/profile', authController.updateUserProfile);

module.exports = router;

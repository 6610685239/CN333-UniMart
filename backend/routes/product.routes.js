const express = require('express');
const router = express.Router();
const productController = require('../controllers/product.controller');

// upload middleware is injected from server.js
module.exports = function(upload) {
  router.get('/categories', productController.getCategories);
  router.post('/products', upload.array('images', 5), productController.createProduct);
  router.get('/my-products/:userId', productController.getMyProducts);
  router.get('/products/:id', productController.getProductById);
  router.delete('/products/:id', productController.deleteProduct);
  router.patch('/products/:id', upload.array('images', 5), productController.updateProduct);
  router.get('/products', productController.getAllProducts);

  return router;
};

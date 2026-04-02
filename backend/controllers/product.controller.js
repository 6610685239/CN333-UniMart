const productService = require('../services/product.service');

async function getCategories(req, res) {
  try {
    const categories = await productService.getCategories();
    res.json(categories);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

async function createProduct(req, res) {
  try {
    const newProduct = await productService.createProduct(req.body, req.files);
    res.json(newProduct);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
}

async function getMyProducts(req, res) {
  try {
    const { userId } = req.params;
    const products = await productService.getMyProducts(userId);
    res.json(products);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
}

async function getProductById(req, res) {
  try {
    const product = await productService.getProductById(req.params.id);
    if (!product) return res.status(404).json({ error: "Product not found" });
    res.json(product);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

async function deleteProduct(req, res) {
  try {
    await productService.deleteProduct(req.params.id);
    res.json({ message: "Deleted successfully" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

async function updateProduct(req, res) {
  try {
    const updatedProduct = await productService.updateProduct(req.params.id, req.body);
    res.json(updatedProduct);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

async function getAllProducts(req, res) {
  const { ownerId } = req.query;
  const products = await productService.getAllProducts(ownerId);
  res.json(products);
}

module.exports = { getCategories, createProduct, getMyProducts, getProductById, deleteProduct, updateProduct, getAllProducts };

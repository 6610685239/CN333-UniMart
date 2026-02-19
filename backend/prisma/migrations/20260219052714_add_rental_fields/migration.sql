-- CreateEnum
CREATE TYPE "ProductType" AS ENUM ('SALE', 'RENT');

-- AlterTable
ALTER TABLE "Product" ADD COLUMN     "currentRenterId" INTEGER,
ADD COLUMN     "isRented" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "rentDueDate" TIMESTAMP(3),
ADD COLUMN     "rentPrice" DOUBLE PRECISION,
ADD COLUMN     "type" "ProductType" NOT NULL DEFAULT 'SALE';

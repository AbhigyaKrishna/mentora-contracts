const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EduChain", function () {
  let CourseMarketplace;
  let courseMarketplace;
  let owner;
  let instructor;
  let student;
  let student2;
  let platformFeePercent = 5;

  beforeEach(async function () {
    // Get signers
    [owner, instructor, student, student2] = await ethers.getSigners();

    // Deploy contract
    CourseMarketplace = await ethers.getContractFactory("CourseMarketplace");
    courseMarketplace = await CourseMarketplace.deploy(platformFeePercent);
  });

  describe("Course Creation", function () {
    it("Should allow instructor to create a course", async function () {
      const title = "Blockchain Basics";
      const description = "Learn the fundamentals of blockchain technology";
      const thumbnailIpfsHash = "QmThumbnail123";
      const introVideoIpfsHash = "QmVideo123";
      const price = ethers.parseEther("0.1");

      await courseMarketplace.connect(instructor).createCourse(
        title,
        description,
        thumbnailIpfsHash,
        introVideoIpfsHash,
        price
      );

      const course = await courseMarketplace.courses(1);
      expect(course.creator).to.equal(instructor.address);
      expect(course.price).to.equal(price);
      expect(course.title).to.equal(title);
      expect(course.description).to.equal(description);
      expect(course.isActive).to.be.true;
    });

    it("Should not allow creating a course with empty title", async function () {
      const price = ethers.parseEther("0.1");
      const description = "Learn the fundamentals of blockchain technology";
      const thumbnailIpfsHash = "QmThumbnail123";
      const introVideoIpfsHash = "QmVideo123";

      await expect(
        courseMarketplace.connect(instructor).createCourse(
          "",
          description,
          thumbnailIpfsHash,
          introVideoIpfsHash,
          price
        )
      ).to.be.revertedWith("Title cannot be empty");
    });

    it("Should not allow creating a course with zero price", async function () {
      const title = "Blockchain Basics";
      const description = "Learn the fundamentals of blockchain technology";
      const thumbnailIpfsHash = "QmThumbnail123";
      const introVideoIpfsHash = "QmVideo123";
      const price = 0;

      await expect(
        courseMarketplace.connect(instructor).createCourse(
          title,
          description,
          thumbnailIpfsHash,
          introVideoIpfsHash,
          price
        )
      ).to.be.revertedWith("Price must be greater than zero");
    });
  });

  describe("Course Content Management", function () {
    let courseId;
    let price;

    beforeEach(async function () {
      const title = "Blockchain Basics";
      const description = "Learn the fundamentals of blockchain technology";
      const thumbnailIpfsHash = "QmThumbnail123";
      const introVideoIpfsHash = "QmVideo123";
      price = ethers.parseEther("0.1");

      await courseMarketplace.connect(instructor).createCourse(
        title,
        description,
        thumbnailIpfsHash,
        introVideoIpfsHash,
        price
      );
      courseId = 1;
    });

    it("Should allow instructor to add a module", async function () {
      const moduleTitle = "Introduction to Blockchain";
      const moduleIpfsHash = "QmModule123";

      await courseMarketplace.connect(instructor).addModule(
        courseId,
        moduleTitle,
        moduleIpfsHash
      );

      const course = await courseMarketplace.courses(courseId);
      expect(course.moduleCount).to.equal(1);
    });

    it("Should not allow non-instructor to add a module", async function () {
      const moduleTitle = "Introduction to Blockchain";
      const moduleIpfsHash = "QmModule123";

      await expect(
        courseMarketplace.connect(student).addModule(
          courseId,
          moduleTitle,
          moduleIpfsHash
        )
      ).to.be.revertedWith("Only course creator can modify this course");
    });

    it("Should allow instructor to add material to a module", async function () {
      const moduleTitle = "Introduction to Blockchain";
      const moduleIpfsHash = "QmModule123";
      const materialIpfsHash = "QmMaterial123";

      await courseMarketplace.connect(instructor).addModule(
        courseId,
        moduleTitle,
        moduleIpfsHash
      );

      await courseMarketplace.connect(instructor).addMaterial(
        courseId,
        0,
        materialIpfsHash
      );
    });
  });

  describe("Course Management", function () {
    let courseId;
    let price;

    beforeEach(async function () {
      const title = "Blockchain Basics";
      const description = "Learn the fundamentals of blockchain technology";
      const thumbnailIpfsHash = "QmThumbnail123";
      const introVideoIpfsHash = "QmVideo123";
      price = ethers.parseEther("0.1");

      await courseMarketplace.connect(instructor).createCourse(
        title,
        description,
        thumbnailIpfsHash,
        introVideoIpfsHash,
        price
      );
      courseId = 1;
    });

    it("Should allow instructor to update course", async function () {
      const newTitle = "Advanced Blockchain";
      const newDescription = "Advanced blockchain concepts";
      const newThumbnailIpfsHash = "QmNewThumbnail123";
      const newIntroVideoIpfsHash = "QmNewVideo123";
      const newPrice = ethers.parseEther("0.2");

      await courseMarketplace.connect(instructor).updateCourse(
        courseId,
        newTitle,
        newDescription,
        newThumbnailIpfsHash,
        newIntroVideoIpfsHash,
        newPrice,
        true
      );

      const course = await courseMarketplace.courses(courseId);
      expect(course.title).to.equal(newTitle);
      expect(course.price).to.equal(newPrice);
    });

    it("Should not allow non-instructor to update course", async function () {
      const newTitle = "Advanced Blockchain";
      const newDescription = "Advanced blockchain concepts";
      const newThumbnailIpfsHash = "QmNewThumbnail123";
      const newIntroVideoIpfsHash = "QmNewVideo123";
      const newPrice = ethers.parseEther("0.2");

      await expect(
        courseMarketplace.connect(student).updateCourse(
          courseId,
          newTitle,
          newDescription,
          newThumbnailIpfsHash,
          newIntroVideoIpfsHash,
          newPrice,
          true
        )
      ).to.be.revertedWith("Only course creator can modify this course");
    });
  });
}); 
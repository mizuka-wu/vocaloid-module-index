const path = require("path");
const fs = require("fs");
const modules = require("./divax.json");
const downloadPic = require("./download");
const Jimp = require("jimp");

(async function() {
  modules.forEach(async ({ name, src }, index) => {
    const output = path.resolve("./module", "unknow", name.replace(/\s/g, "_"));
    await downloadPic(src, output, "index.png", "DIVA X英文");
    console.log("download", name);
    const lenna = await Jimp.read(path.resolve(output, "index.png"));
    lenna.write(path.resolve(output, "index.jpg"));
    fs.unlinkSync(path.resolve(output, "index.png"));
    console.log("trans", name);
    console.log("complate", `${index + 1}/${modules.length}`);
  });
})();
